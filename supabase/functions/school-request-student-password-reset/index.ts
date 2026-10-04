import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  adminClient,
  assertNotRateLimited,
  findAccountDoc,
  getDoc,
  upsertDoc,
} from "../_shared/school_auth.ts";

function clip(value: unknown, max: number): string {
  return String(value ?? "").trim().slice(0, max);
}

function requestDocId(schoolId: string, studentId: string): string {
  return `spr-${schoolId}-${studentId}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const schoolId = clip(body?.schoolId, 24).toUpperCase();
    const identifier = clip(
      body?.identifier ?? body?.username ?? body?.studentId,
      80,
    );

    if (!schoolId || !identifier) {
      return errorResponse(
        "School ID and student username or ID are required.",
        400,
        "invalid",
      );
    }

    const sb = adminClient();
    const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
      req.headers.get("cf-connecting-ip") ||
      "unknown";
    await assertNotRateLimited(
      sb,
      `student_reset_${schoolId}_${identifier}_${ip}`,
    );

    const school = await getDoc(sb, "school_registry", schoolId);
    if (!school) return jsonResponse({ ok: true });

    let studentId = clip(body?.studentId, 32).toUpperCase();
    let username = clip(body?.username ?? "", 80).toLowerCase();
    let studentName = clip(body?.studentName ?? "", 120);

    const account = await findAccountDoc(sb, identifier, "student", schoolId);
    if (account) {
      const linked = String(account.data.linkedStudentId || "")
        .trim()
        .toUpperCase();
      if (!studentId && linked) studentId = linked;
      if (!username) {
        username = String(account.data.username || "").trim().toLowerCase();
      }
      if (!studentName) {
        studentName = String(account.data.fullName || "").trim();
      }
    }

    if (!studentId && identifier.toUpperCase().startsWith("STU-")) {
      studentId = identifier.toUpperCase();
    }

    let registry = studentId
      ? await getDoc(sb, "student_registry", studentId, schoolId)
      : null;
    if (!registry) {
      registry = await getDoc(
        sb,
        "student_registry",
        identifier.toUpperCase(),
        schoolId,
      );
      if (registry) {
        studentId = String(registry.studentId || identifier)
          .trim()
          .toUpperCase();
      }
    }

    if (registry) {
      const rid = String(registry.studentId || studentId || "")
        .trim()
        .toUpperCase();
      if (rid) studentId = rid;
      if (!studentName) {
        studentName = String(registry.fullName || registry.name || "").trim();
      }
      if (!username) {
        username = String(registry.loginUsername || "").trim().toLowerCase();
      }
    }

    if (!studentId) return jsonResponse({ ok: true });

    const docId = requestDocId(schoolId, studentId);
    const existing = await getDoc(sb, "student_password_resets", docId, schoolId);
    if (existing && String(existing.status || "") === "pending") {
      return jsonResponse({ ok: true, id: docId, alreadyPending: true });
    }

    const now = new Date().toISOString();
    await upsertDoc(
      sb,
      "student_password_resets",
      docId,
      {
        id: docId,
        studentId,
        schoolId,
        requestedAt: typeof existing?.requestedAt === "string"
          ? existing.requestedAt
          : now,
        username: username || undefined,
        studentName: studentName || undefined,
        status: "pending",
      },
      schoolId,
    );

    return jsonResponse({ ok: true, id: docId });
  } catch (e) {
    const msg = String((e as { message?: string })?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse(
        "Too many attempts. Try again later.",
        429,
        "rate_limited",
      );
    }
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});
