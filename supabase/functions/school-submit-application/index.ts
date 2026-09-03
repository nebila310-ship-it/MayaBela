import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  adminClient,
  assertNotRateLimited,
  getDoc,
  upsertDoc,
} from "../_shared/school_auth.ts";

function clip(value: unknown, max: number): string {
  return String(value ?? "").trim().slice(0, max);
}

function defaultDocuments() {
  const labels = [
    "Birth certificate",
    "Previous school report",
    "Passport photo",
    "Parent / guardian ID",
  ];
  return labels.map((label, i) => ({
    id: `doc-${i}`,
    label,
    submitted: true,
    verified: false,
    notes: "",
  }));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const schoolId = clip(body?.schoolId, 24).toUpperCase();
    const fullName = clip(body?.fullName, 120);
    const guardianName = clip(body?.guardianName, 120);
    const guardianPhone = clip(body?.guardianPhone, 32);
    const guardianEmail = clip(body?.guardianEmail, 120);
    const gradeApplying = clip(body?.gradeApplying, 40);
    const previousSchool = clip(body?.previousSchool, 120);

    if (!schoolId || !fullName || !guardianName) {
      return errorResponse(
        "schoolId, fullName, and guardianName are required.",
        400,
        "invalid",
      );
    }

    const sb = adminClient();
    const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
      req.headers.get("cf-connecting-ip") ||
      "unknown";
    await assertNotRateLimited(sb, `apply_${schoolId}_${ip}`);

    const school = await getDoc(sb, "school_registry", schoolId);
    if (!school) return errorResponse("School not found.", 404, "not_found");

    let id = "";
    for (let i = 0; i < 12; i++) {
      const n = (Math.floor(Math.random() * 9000) + 1).toString().padStart(
        4,
        "0",
      );
      const candidate = `APP-${n}`;
      const existing = await getDoc(
        sb,
        "admission_applications",
        candidate,
        schoolId,
      );
      if (!existing) {
        id = candidate;
        break;
      }
    }
    if (!id) {
      return errorResponse("Could not allocate an application id.", 500);
    }

    const now = new Date().toISOString();
    const record = {
      id,
      schoolId,
      fullName,
      stage: "application",
      source: "online",
      gradeApplying,
      campus: "",
      guardianName,
      guardianPhone,
      guardianEmail,
      previousSchool,
      notes: "",
      documents: defaultDocuments(),
      examMaxScore: 100,
      examNotes: "",
      offerMessage: "",
      decisionReason: "",
      createdById: "",
      createdByName: "Online application",
      createdAt: now,
      updatedAt: now,
    };

    await upsertDoc(sb, "admission_applications", id, record, schoolId);
    return jsonResponse({ ok: true, id });
  } catch (e) {
    const msg = String(e?.message || e);
    if (msg.includes("rate_limited")) {
      return errorResponse("Too many applications. Try later.", 429, "rate_limited");
    }
    console.error(e);
    return errorResponse(msg, 500, "invalid");
  }
});
