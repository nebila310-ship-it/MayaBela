const functions = require("firebase-functions");
const admin = require("firebase-admin");
const bcrypt = require("bcryptjs");

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

const ROLES = new Set(["admin", "teacher", "parent", "driver", "student"]);
const MIN_PASSWORD_LENGTH = 10;
const BCRYPT_ROUNDS = 12;
const LOGIN_RATE_LIMIT = 8;
const LOGIN_RATE_WINDOW_MS = 15 * 60 * 1000;

async function assertNotRateLimited(bucketKey) {
  const ref = db.collection("auth_rate_limits").doc(bucketKey);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : {};
    const windowStart = data.windowStart || 0;
    let count = data.count || 0;
    if (now - windowStart > LOGIN_RATE_WINDOW_MS) {
      count = 0;
    }
    if (count >= LOGIN_RATE_LIMIT) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Too many attempts. Try again later.",
      );
    }
    tx.set(
      ref,
      {
        windowStart: count === 0 ? now : windowStart || now,
        count: count + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  });
}

function normalizeUsername(value) {
  return String(value || "").trim().toLowerCase();
}

function assertRole(roleKey) {
  if (!ROLES.has(roleKey)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid role.");
  }
}

function assertPassword(password) {
  if (typeof password !== "string" || password.length < MIN_PASSWORD_LENGTH) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
    );
  }
}

function profileFromAccount(username, data) {
  return {
    username: data.username || username,
    roleKey: data.roleKey,
    email: data.email || null,
    phone: data.phone || null,
    schoolId: data.schoolId || null,
    fullName: data.fullName || null,
    linkedStudentIds: data.linkedStudentIds || [],
    linkedTeacherId: data.linkedTeacherId || null,
    linkedAdminId: data.linkedAdminId || null,
    linkedDriverId: data.linkedDriverId || null,
    linkedStudentId: data.linkedStudentId || null,
    mustChangePassword: !!data.mustChangePassword,
  };
}

const ACCESS_CLAIM_CAP = 30;

function uniqueStrings(values, cap = ACCESS_CLAIM_CAP) {
  const out = [];
  const seen = new Set();
  for (const raw of values || []) {
    const value = String(raw || "").trim();
    if (!value) continue;
    const key = value.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(value);
    if (out.length >= cap) break;
  }
  return out;
}

function classNamesFromTeacherData(data) {
  const names = [];
  if (!data) return names;
  if (typeof data.assignedClass === "string") {
    for (const part of data.assignedClass.split(",")) {
      names.push(part.trim());
    }
  }
  if (Array.isArray(data.assignedClassNames)) {
    names.push(...data.assignedClassNames);
  }
  if (Array.isArray(data.classAssignments)) {
    for (const row of data.classAssignments) {
      if (row && row.className) names.push(row.className);
    }
  }
  return uniqueStrings(names);
}

/**
 * Resolve parent linked kids / teacher assigned classes for Auth custom claims.
 * Claims are the security boundary used by Firestore rules.
 */
async function enrichAccessProfile(profile) {
  const enriched = {
    ...profile,
    linkedStudentIds: uniqueStrings(profile.linkedStudentIds || []),
    linkedClassNames: uniqueStrings(profile.linkedClassNames || []),
    linkedStudentNames: uniqueStrings(profile.linkedStudentNames || []),
    assignedClassNames: uniqueStrings(profile.assignedClassNames || []),
  };

  const username = normalizeUsername(enriched.username);
  const schoolId = String(enriched.schoolId || "").trim();
  const roleKey = enriched.roleKey;

  if (roleKey === "parent" && username) {
    const ids = new Set(
      (enriched.linkedStudentIds || []).map((id) => String(id).trim().toUpperCase()),
    );
    try {
      const linkSnap = await db
        .collection("parent_link_requests")
        .where("parentUsername", "==", username)
        .where("status", "==", "approved")
        .limit(ACCESS_CLAIM_CAP)
        .get();
      for (const doc of linkSnap.docs) {
        const studentId = String(doc.data()?.studentId || "")
          .trim()
          .toUpperCase();
        if (studentId) ids.add(studentId);
      }
    } catch (_) {
      // Composite index may be missing; fall back to account links only.
    }
    enriched.linkedStudentIds = uniqueStrings([...ids]);

    const classNames = new Set();
    const studentNames = new Set();
    for (const studentId of enriched.linkedStudentIds) {
      try {
        const stu = await db.collection("student_registry").doc(studentId).get();
        if (!stu.exists) continue;
        const data = stu.data() || {};
        if (schoolId && data.schoolId && data.schoolId !== schoolId) continue;
        if (data.className) classNames.add(String(data.className).trim());
        const fullName = String(data.fullName || data.name || "").trim();
        if (fullName) studentNames.add(fullName);
      } catch (_) {
        // ignore missing student docs
      }
    }
    enriched.linkedClassNames = uniqueStrings([...classNames]);
    enriched.linkedStudentNames = uniqueStrings([...studentNames]);
  }

  if (roleKey === "teacher") {
    const teacherId = String(enriched.linkedTeacherId || "")
      .trim()
      .toUpperCase();
    if (teacherId) {
      try {
        const tea = await db.collection("teacher_registry").doc(teacherId).get();
        if (tea.exists) {
          const data = tea.data() || {};
          if (!schoolId || !data.schoolId || data.schoolId === schoolId) {
            enriched.assignedClassNames = classNamesFromTeacherData(data);
          }
        }
      } catch (_) {
        // keep any provided assignedClassNames
      }
    }
  }

  if (roleKey === "student" && enriched.linkedStudentId) {
    enriched.linkedStudentIds = uniqueStrings([enriched.linkedStudentId]);
  }

  return enriched;
}

function claimsFor(profile) {
  return {
    role: profile.roleKey,
    schoolId: profile.schoolId || "",
    username: normalizeUsername(profile.username),
    linkedStudentId: profile.linkedStudentId || "",
    linkedTeacherId: profile.linkedTeacherId || "",
    linkedDriverId: profile.linkedDriverId || "",
    linkedStudentIds: uniqueStrings(profile.linkedStudentIds || []),
    linkedClassNames: uniqueStrings(profile.linkedClassNames || []),
    linkedStudentNames: uniqueStrings(profile.linkedStudentNames || []),
    assignedClassNames: uniqueStrings(profile.assignedClassNames || []),
  };
}

async function verifyLegacySha256(plain, stored) {
  if (!stored || typeof stored !== "string") return false;
  if (!stored.startsWith("sha256:")) return false;
  const body = stored.slice("sha256:".length);
  const parts = body.split(":");
  if (parts.length !== 2) return false;
  const crypto = require("crypto");
  const digest = crypto
    .createHash("sha256")
    .update(`${parts[0]}::${plain}`, "utf8")
    .digest("hex");
  return digest === parts[1];
}

async function verifySecret(plain, secretData, legacyPassword) {
  if (secretData && secretData.passwordHash) {
    return bcrypt.compare(plain, secretData.passwordHash);
  }
  if (legacyPassword == null || legacyPassword === "") return false;
  if (typeof legacyPassword === "string" && legacyPassword.startsWith("sha256:")) {
    return verifyLegacySha256(plain, legacyPassword);
  }
  return plain === legacyPassword;
}

async function upsertSecret(username, plainPassword) {
  const passwordHash = await bcrypt.hash(plainPassword, BCRYPT_ROUNDS);
  await db.collection("auth_secrets").doc(username).set(
    {
      passwordHash,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function stripLegacyPassword(username) {
  await db.collection("app_auth_accounts").doc(username).set(
    {
      password: admin.firestore.FieldValue.delete(),
      passwordHash: admin.firestore.FieldValue.delete(),
    },
    {merge: true},
  );
}

async function ensureFirebaseUser(username, profile) {
  const uid = `school_${username.replace(/[^a-z0-9_-]/gi, "_")}`;
  const enriched = await enrichAccessProfile(profile);
  try {
    await auth.getUser(uid);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    await auth.createUser({
      uid,
      displayName: enriched.fullName || username,
      disabled: false,
    });
  }
  await auth.setCustomUserClaims(uid, claimsFor(enriched));
  return {uid, profile: enriched};
}

async function findAccountDoc(identifier, roleKey) {
  const key = normalizeUsername(identifier);
  const direct = await db.collection("app_auth_accounts").doc(key).get();
  if (direct.exists) {
    const data = direct.data() || {};
    if (!roleKey || data.roleKey === roleKey) {
      return {id: direct.id, data};
    }
  }

  // Phone / username field match
  const snap = await db
    .collection("app_auth_accounts")
    .where("username", "==", key)
    .limit(5)
    .get();
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (!roleKey || data.roleKey === roleKey) {
      return {id: doc.id, data};
    }
  }

  if (roleKey === "student") {
    const byStudent = await db
      .collection("app_auth_accounts")
      .where("linkedStudentId", "==", String(identifier).trim().toUpperCase())
      .limit(1)
      .get();
    if (!byStudent.empty) {
      const doc = byStudent.docs[0];
      return {id: doc.id, data: doc.data() || {}};
    }
  }

  return null;
}

/**
 * School login — verifies password server-side, migrates legacy plaintext,
 * returns Firebase custom token + profile (never returns password).
 */
exports.schoolLogin = functions.https.onCall(async (data) => {
  const usernameInput = data?.username;
  const password = data?.password;
  const roleKey = data?.roleKey;
  const schoolIdInput = String(data?.schoolId || "").trim();

  if (!usernameInput || !password || !roleKey) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "username, password, and roleKey are required.",
    );
  }
  assertRole(roleKey);

  const rateKey = `login_${normalizeUsername(usernameInput)}_${roleKey}`;
  await assertNotRateLimited(rateKey);

  const found = await findAccountDoc(usernameInput, roleKey);
  if (!found) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Invalid credentials.",
    );
  }

  const username = normalizeUsername(found.data.username || found.id);
  const profile = profileFromAccount(username, found.data);

  if (!profile.schoolId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Account is missing schoolId.",
    );
  }
  if (schoolIdInput && schoolIdInput !== profile.schoolId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "School ID does not match this account.",
    );
  }
  if (profile.roleKey !== roleKey) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Role mismatch.",
    );
  }

  const secretSnap = await db.collection("auth_secrets").doc(username).get();
  const ok = await verifySecret(
    password,
    secretSnap.exists ? secretSnap.data() : null,
    found.data.password,
  );
  if (!ok) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Invalid credentials.",
    );
  }

  // Migrate legacy passwords into auth_secrets and strip client-readable fields.
  if (!secretSnap.exists || !secretSnap.data()?.passwordHash) {
    await upsertSecret(username, password);
  }
  if (found.data.password != null || found.data.passwordHash != null) {
    await stripLegacyPassword(username);
  }

  const {uid, profile: accessProfile} = await ensureFirebaseUser(
    username,
    profile,
  );
  const token = await auth.createCustomToken(uid, claimsFor(accessProfile));

  return {
    token,
    profile: {
      ...profileFromAccount(username, found.data),
      linkedStudentIds: accessProfile.linkedStudentIds,
      linkedClassNames: accessProfile.linkedClassNames,
      linkedStudentNames: accessProfile.linkedStudentNames,
      assignedClassNames: accessProfile.assignedClassNames,
    },
  };
});

/**
 * Create/update account profile + secret. Admin-only (or bootstrap when no admins).
 */
exports.schoolUpsertAccount = functions.https.onCall(async (data, context) => {
  const username = normalizeUsername(data?.username);
  const roleKey = data?.roleKey;
  const schoolId = String(data?.schoolId || "").trim();
  const password = data?.password;

  if (!username || !roleKey || !schoolId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "username, roleKey, and schoolId are required.",
    );
  }
  assertRole(roleKey);

  const caller = context.auth;
  const isAdminCaller =
    caller &&
    caller.token &&
    caller.token.role === "admin" &&
    caller.token.schoolId === schoolId;

  if (!isAdminCaller) {
    // Allow first admin bootstrap for a school when no admin exists yet.
    if (roleKey !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin authentication required.",
      );
    }
    const existingAdmins = await db
      .collection("app_auth_accounts")
      .where("schoolId", "==", schoolId)
      .where("roleKey", "==", "admin")
      .limit(1)
      .get();
    if (!existingAdmins.empty) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin authentication required.",
      );
    }
    if (!password) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "password is required for bootstrap admin.",
      );
    }
  }

  if (password) {
    assertPassword(password);
    await upsertSecret(username, password);
  }

  const profile = {
    username,
    roleKey,
    schoolId,
    email: data.email || null,
    phone: data.phone || null,
    fullName: data.fullName || null,
    linkedStudentIds: data.linkedStudentIds || [],
    linkedTeacherId: data.linkedTeacherId || null,
    linkedAdminId: data.linkedAdminId || null,
    linkedDriverId: data.linkedDriverId || null,
    linkedStudentId: data.linkedStudentId || null,
    mustChangePassword: !!data.mustChangePassword,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection("app_auth_accounts").doc(username).set(
    {
      ...profile,
      password: admin.firestore.FieldValue.delete(),
      passwordHash: admin.firestore.FieldValue.delete(),
    },
    {merge: true},
  );

  const {profile: accessProfile} = await ensureFirebaseUser(username, profile);
  return {
    ok: true,
    profile: {
      ...profileFromAccount(username, profile),
      linkedStudentIds: accessProfile.linkedStudentIds,
      linkedClassNames: accessProfile.linkedClassNames,
      assignedClassNames: accessProfile.assignedClassNames,
    },
  };
});

/**
 * Parent self-registration (no admin session). Creates profile + secret.
 */
exports.schoolRegisterParent = functions.https.onCall(async (data) => {
  const username = normalizeUsername(data?.username || data?.phone);
  const password = data?.password;
  const schoolId = String(data?.schoolId || "").trim();
  const phone = data?.phone || null;
  const fullName = data?.fullName || null;
  const email = data?.email || null;

  if (!username || !schoolId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "username/phone and schoolId are required.",
    );
  }
  await assertNotRateLimited(`register_${username}_${schoolId}`);
  assertPassword(password);

  const school = await db.collection("school_registry").doc(schoolId).get();
  if (!school.exists) {
    throw new functions.https.HttpsError("not-found", "School not found.");
  }

  const existing = await db.collection("app_auth_accounts").doc(username).get();
  if (existing.exists) {
    throw new functions.https.HttpsError(
      "already-exists",
      "Account already exists.",
    );
  }

  await upsertSecret(username, password);
  const profile = {
    username,
    roleKey: "parent",
    schoolId,
    email,
    phone,
    fullName,
    linkedStudentIds: data.linkedStudentIds || [],
    mustChangePassword: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection("app_auth_accounts").doc(username).set({
    ...profile,
    password: admin.firestore.FieldValue.delete(),
    passwordHash: admin.firestore.FieldValue.delete(),
  });
  await ensureFirebaseUser(username, profile);
  return {ok: true, profile: profileFromAccount(username, profile)};
});

/**
 * Refresh access claims (linked kids / assigned classes) for the signed-in user,
 * or for another same-school user when called by an admin (e.g. after link approval).
 */
exports.schoolRefreshAccessClaims = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.token?.username) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Sign in required.",
    );
  }

  const callerUsername = normalizeUsername(context.auth.token.username);
  const callerRole = context.auth.token.role;
  const callerSchoolId = String(context.auth.token.schoolId || "").trim();
  const targetUsername = normalizeUsername(
    data?.username || context.auth.token.username,
  );
  const isSelf = targetUsername === callerUsername;
  const isAdmin = callerRole === "admin" && !!callerSchoolId;

  if (!isSelf && !isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Cannot refresh another user's access claims.",
    );
  }

  const accountSnap = await db
    .collection("app_auth_accounts")
    .doc(targetUsername)
    .get();
  if (!accountSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Account not found.");
  }
  const account = accountSnap.data() || {};
  if (isAdmin && !isSelf && account.schoolId !== callerSchoolId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Cross-school access denied.",
    );
  }

  const profile = profileFromAccount(targetUsername, account);
  const {uid, profile: accessProfile} = await ensureFirebaseUser(
    targetUsername,
    profile,
  );

  let token = null;
  if (isSelf) {
    token = await auth.createCustomToken(uid, claimsFor(accessProfile));
  }

  return {
    ok: true,
    token,
    profile: {
      ...profileFromAccount(targetUsername, account),
      linkedStudentIds: accessProfile.linkedStudentIds,
      linkedClassNames: accessProfile.linkedClassNames,
      linkedStudentNames: accessProfile.linkedStudentNames,
      assignedClassNames: accessProfile.assignedClassNames,
    },
  };
});

/**
 * Change password for the signed-in user (or admin reset for same school).
 */
exports.schoolChangePassword = functions.https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.token?.username) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Sign in required.",
    );
  }

  const newPassword = data?.newPassword;
  assertPassword(newPassword);

  const targetUsername = normalizeUsername(
    data?.username || context.auth.token.username,
  );
  const isSelf = targetUsername === context.auth.token.username;
  const isAdmin =
    context.auth.token.role === "admin" &&
    context.auth.token.schoolId;

  if (!isSelf && !isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Cannot change another user's password.",
    );
  }

  const accountSnap = await db
    .collection("app_auth_accounts")
    .doc(targetUsername)
    .get();
  if (!accountSnap.exists) {
    throw new functions.https.HttpsError("not-found", "Account not found.");
  }
  const account = accountSnap.data() || {};
  if (isAdmin && !isSelf && account.schoolId !== context.auth.token.schoolId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Cross-school password reset denied.",
    );
  }

  if (isSelf && data?.currentPassword) {
    const secretSnap = await db
      .collection("auth_secrets")
      .doc(targetUsername)
      .get();
    const ok = await verifySecret(
      data.currentPassword,
      secretSnap.exists ? secretSnap.data() : null,
      account.password,
    );
    if (!ok) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Current password is incorrect.",
      );
    }
  }

  await upsertSecret(targetUsername, newPassword);
  await stripLegacyPassword(targetUsername);
  await db.collection("app_auth_accounts").doc(targetUsername).set(
    {
      mustChangePassword: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {ok: true};
});

/**
 * One-time migration: move passwords from app_auth_accounts → auth_secrets.
 * Callable only with Firebase Auth admin custom claim role=admin (any school)
 * OR via shell with admin SDK locally — restricted to authenticated admins.
 */
exports.migrateAuthSecrets = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token?.role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Admin only.",
    );
  }

  const snap = await db.collection("app_auth_accounts").get();
  let migrated = 0;
  let skipped = 0;

  for (const doc of snap.docs) {
    const username = normalizeUsername(doc.id);
    const account = doc.data() || {};
    const secretRef = db.collection("auth_secrets").doc(username);
    const secretSnap = await secretRef.get();
    if (secretSnap.exists && secretSnap.data()?.passwordHash) {
      if (account.password != null) {
        await stripLegacyPassword(username);
      }
      skipped += 1;
      continue;
    }
    const legacy = account.password;
    if (legacy == null || legacy === "") {
      skipped += 1;
      continue;
    }
    // Only migrate plaintext or sha256 — store bcrypt of plaintext when possible.
    if (typeof legacy === "string" && legacy.startsWith("sha256:")) {
      // Cannot reverse hash; leave until user logs in (schoolLogin migrates).
      skipped += 1;
      continue;
    }
    await upsertSecret(username, String(legacy));
    await stripLegacyPassword(username);
    migrated += 1;
  }

  return {migrated, skipped};
});

/**
 * Maya assistant chat — optional Gemini when MAYA_AI_API_KEY / GEMINI_API_KEY
 * is set (functions config or env). Client falls back to local guidance if this
 * fails or no key is configured.
 */
exports.mayaAssistantChat = functions.https.onCall(async (data, context) => {
  const roleKey = String(data?.roleKey || context.auth?.token?.role || "admin");
  const message = String(data?.message || "").trim();
  if (!message) {
    throw new functions.https.HttpsError("invalid-argument", "message required.");
  }

  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }

  const apiKey =
    process.env.MAYA_AI_API_KEY ||
    process.env.GEMINI_API_KEY ||
    (functions.config().maya && functions.config().maya.api_key) ||
    (functions.config().gemini && functions.config().gemini.api_key) ||
    "";

  if (!apiKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Maya AI key not configured.",
    );
  }

  const titleByRole = {
    admin: "Maya Assistant",
    teacher: "Maya Teacher Assistant",
    student: "Maya Tutor",
    parent: "Maya Family Assistant",
    driver: "Maya Route Assistant",
    platform_owner: "Maya Executive Assistant",
  };
  const title = titleByRole[roleKey] || "Maya Assistant";

  const history = Array.isArray(data?.history) ? data.history.slice(-12) : [];
  const contents = [];
  for (const row of history) {
    const text = String(row?.text || "").trim();
    if (!text) continue;
    const role = row?.role === "user" ? "user" : "model";
    contents.push({role, parts: [{text}]});
  }
  contents.push({role: "user", parts: [{text: message}]});

  const system = [
    `You are ${title} inside MaJo e-School Bridge (Maya school ERP).`,
    "Be concise, practical, and safe. Help with in-app workflows only.",
    "Do not invent grades, fees, medical data, or student PII.",
    `User portal role: ${roleKey}.`,
  ].join(" ");

  const url =
    "https://generativelanguage.googleapis.com/v1beta/models/" +
    "gemini-2.0-flash:generateContent?key=" +
    encodeURIComponent(apiKey);

  const response = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      systemInstruction: {parts: [{text: system}]},
      contents,
      generationConfig: {
        temperature: 0.4,
        maxOutputTokens: 512,
      },
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    console.error("mayaAssistantChat gemini error", response.status, body);
    throw new functions.https.HttpsError(
      "unavailable",
      "Maya AI temporarily unavailable.",
    );
  }

  const json = await response.json();
  const reply =
    json?.candidates?.[0]?.content?.parts?.map((p) => p.text).join("") || "";
  if (!reply.trim()) {
    throw new functions.https.HttpsError(
      "internal",
      "Empty Maya AI response.",
    );
  }

  return {reply: reply.trim(), title, roleKey};
});

// —— FCM (existing) ——

async function tokensForUsernames(usernames) {
  const tokens = [];
  for (const username of usernames) {
    if (!username) continue;
    const doc = await db.collection("fcm_tokens").doc(username).get();
    const token = doc.data()?.token;
    if (token) tokens.push(token);
  }
  return tokens;
}

async function tokensForStaffId(staffId) {
  if (!staffId) return [];
  const snap = await db
    .collection("fcm_tokens")
    .where("staffId", "==", staffId)
    .get();
  return snap.docs.map((doc) => doc.data()?.token).filter(Boolean);
}

function recipientUsernames(conversation, lastMessage) {
  const senderRole = lastMessage.senderRole || "";
  const senderUsername = (lastMessage.senderUsername || "").toLowerCase();

  if (senderRole === "parent") {
    return [];
  }

  const parents = conversation.parentParticipantUsernames || [];
  return parents.filter(
    (name) => name && name.toLowerCase() !== senderUsername,
  );
}

async function recipientTokens(conversation, lastMessage) {
  const senderRole = lastMessage.senderRole || "";

  if (senderRole === "parent") {
    return tokensForStaffId(conversation.staffParticipantId);
  }

  const parentTokens = await tokensForUsernames(
    recipientUsernames(conversation, lastMessage),
  );

  if (conversation.isGroup) {
    const staffTokens = [];
    for (const staffId of conversation.groupStaffIds || []) {
      staffTokens.push(...(await tokensForStaffId(staffId)));
    }
    return [...new Set([...parentTokens, ...staffTokens])];
  }

  const staffTokens = await tokensForStaffId(conversation.staffParticipantId);
  return [...new Set([...parentTokens, ...staffTokens])].filter(Boolean);
}

exports.onConversationMessage = functions.firestore
  .document("conversations/{conversationId}")
  .onWrite(async (change) => {
    const after = change.after.exists ? change.after.data() : null;
    if (!after || !Array.isArray(after.messages) || after.messages.length === 0) {
      return null;
    }

    const lastMessage = after.messages[after.messages.length - 1];
    const tokens = await recipientTokens(after, lastMessage);
    if (tokens.length === 0) return null;

    const senderName =
      lastMessage.senderDisplayName || lastMessage.senderRole || "Someone";
    const body =
      (lastMessage.text && lastMessage.text.trim()) ||
      lastMessage.previewText ||
      "New message";

    const payload = {
      notification: {
        title: after.name || "New message",
        body: `${senderName}: ${body}`,
      },
      data: {
        conversationId: after.id || change.after.id,
        type: "message",
      },
    };

    await Promise.all(
      tokens.map((token) =>
        admin.messaging().send({token, ...payload}).catch(() => null),
      ),
    );

    return null;
  });
