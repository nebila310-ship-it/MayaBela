import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  MIN_PASSWORD_LENGTH,
  accountDocId,
  adminClient,
  assertNotRateLimited,
  ensureAuthUser,
  ethiopianLoginKey,
  getDoc,
  normalizeUsername,
  parentLinkDocId,
  profileFromAccount,
  upsertSecret,
} from "../_shared/school_auth.ts";

function sameDay(a: string | null | undefined, b: string | null | undefined): boolean {
  const da = String(a || "").slice(0, 10);
  const db = String(b || "").slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(da) && da === db;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json();
    const username = ethiopianLoginKey(body?.username || body?.phone) ||
      normalizeUsername(body?.username || body?.phone);
    const password = body?.password;
    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    const phone = body?.phone || null;
    const fullName = body?.fullName || null;
    const email = body?.email || null;
    const children = Array.isArray(body?.children) ? body.children : [];

    if (!username || !schoolId) {
      return errorResponse("username/phone and schoolId are required.", 400);
    }
    if (typeof password !== "string" || password.length < MIN_PASSWORD_LENGTH) {
      return errorResponse(
        `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`,
        400,
      );
    }

    const sb = adminClient();
    await assertNotRateLimited(sb, `register_${username}_${schoolId}`);

    const school = await getDoc(sb, "school_registry", schoolId);
    if (!school) return errorResponse("School not found.", 404, "not_found");

    const existingComposite = await getDoc(
      sb,
      "app_auth_accounts",
      accountDocId(schoolId, username),
    );
    const legacy = await getDoc(sb, "app_auth_accounts", username, schoolId);
    const legacySameSchool = legacy &&
        String(legacy.schoolId || "").trim().toUpperCase() === schoolId
      ? legacy
      : null;
    if (existingComposite || legacySameSchool) {
      return errorResponse("Account already exists.", 409, "exists");
    }

    await upsertSecret(sb, username, password, schoolId);
    // Never trust client-supplied student links at registration time.
    // Links are granted only after an approved parent_link_request / staff action.
    const profile = {
      username,
      roleKey: "parent",
      schoolId,
      email,
      phone,
      fullName,
      linkedStudentIds: [] as string[],
      mustChangePassword: false,
      updatedAt: new Date().toISOString(),
    };
    await sb.from("app_documents").upsert({
      collection: "app_auth_accounts",
      doc_id: accountDocId(schoolId, username),
      school_id: schoolId,
      data: profile,
      updated_at: new Date().toISOString(),
    }, { onConflict: "collection,school_id,doc_id" });
    await ensureAuthUser(sb, username, password, profile);

    // Service-role pending requests so staff can approve from any device.
    for (const child of children) {
      const studentId = String(child?.studentId || "").trim().toUpperCase();
      if (!studentId) continue;
      const student = await getDoc(sb, "student_registry", studentId, schoolId);
      if (!student) continue;
      if (String(student.schoolId || "").trim().toUpperCase() !== schoolId) {
        continue;
      }
      if (!sameDay(String(student.dateOfBirth || ""), child?.dateOfBirth)) {
        continue;
      }
      const relationship = String(child?.relationship || "guardian");
      const docId = parentLinkDocId(schoolId, username, studentId);
      const existingLink = await getDoc(
        sb,
        "parent_link_requests",
        docId,
        schoolId,
      );
      if (existingLink && String(existingLink.status || "") !== "rejected") {
        continue;
      }
      await sb.from("app_documents").upsert({
        collection: "parent_link_requests",
        doc_id: docId,
        school_id: schoolId,
        data: {
          id: docId,
          parentUsername: username,
          parentFullName: String(fullName || "Parent"),
          studentId,
          schoolId,
          relationship,
          requestedAt: new Date().toISOString(),
          status: "pending",
          hasMedicalCondition: !!child?.hasMedicalCondition,
          medicalConditionDetails: child?.medicalConditionDetails || null,
          otherMedicalInfo: child?.otherMedicalInfo || null,
        },
        updated_at: new Date().toISOString(),
      }, { onConflict: "collection,school_id,doc_id" });
    }

    return jsonResponse({
      ok: true,
      profile: profileFromAccount(username, profile),
    });
  } catch (e) {
    const msg = String(e?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse("Too many attempts. Try again later.", 429);
    }
    console.error(e);
    return errorResponse(msg, 500);
  }
});
