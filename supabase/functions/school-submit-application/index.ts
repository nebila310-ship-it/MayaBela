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

const DOCUMENT_SPECS: Array<{ id: string; label: string; required: boolean }> = [
  { id: "birth-certificate", label: "Birth certificate", required: true },
  {
    id: "previous-school-reports",
    label: "Previous school reports (last 2–3 years)",
    required: true,
  },
  {
    id: "parent-national-id",
    label: "Parent / guardian national ID",
    required: true,
  },
  { id: "passport-photo", label: "Student passport photo", required: false },
  {
    id: "student-id-or-passport",
    label: "Student national ID or passport",
    required: false,
  },
  {
    id: "vaccination-record",
    label: "Vaccination / health record",
    required: false,
  },
];

const EXTRA_PROGRAM_IDS = new Set([
  "film_editing",
  "football",
  "basketball",
  "athletics",
  "swimming",
  "ai_learning",
  "coding_robotics",
  "visual_arts",
  "music",
  "dance",
  "drama",
  "creative_writing",
  "photography",
  "chess",
]);

function stringList(value: unknown, maxItems = 20, maxLen = 40): string[] {
  if (!Array.isArray(value)) return [];
  const out: string[] = [];
  for (const item of value) {
    const id = clip(item, maxLen);
    if (id && EXTRA_PROGRAM_IDS.has(id) && !out.includes(id)) out.push(id);
    if (out.length >= maxItems) break;
  }
  return out;
}

function parseDocuments(raw: unknown) {
  const incoming = new Map<string, { fileName?: string; filePath?: string }>();
  if (Array.isArray(raw)) {
    for (const item of raw) {
      if (!item || typeof item !== "object") continue;
      const id = clip((item as { id?: unknown }).id, 40);
      if (!id) continue;
      incoming.set(id, {
        fileName: clip((item as { fileName?: unknown }).fileName, 160) ||
          undefined,
        filePath: clip((item as { filePath?: unknown }).filePath, 240) ||
          undefined,
      });
    }
  }
  return DOCUMENT_SPECS.map((spec) => {
    const hit = incoming.get(spec.id);
    const submitted = Boolean(hit?.fileName || hit?.filePath);
    return {
      id: spec.id,
      label: spec.label,
      submitted,
      verified: false,
      notes: spec.required ? "Required" : "",
      ...(hit?.filePath ? { filePath: hit.filePath } : {}),
      ...(hit?.fileName && !hit.filePath ? { filePath: hit.fileName } : {}),
    };
  });
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
    const lastGradeCompleted = clip(body?.lastGradeCompleted, 40);
    const dateOfBirth = clip(body?.dateOfBirth, 32);
    const gender = clip(body?.gender, 24);
    const nationality = clip(body?.nationality, 60);
    const homeLanguage = clip(body?.homeLanguage, 60);
    const homeAddress = clip(body?.homeAddress, 200);
    const city = clip(body?.city, 80);
    const studentNationalId = clip(body?.studentNationalId, 40);
    const parentNationalId = clip(body?.parentNationalId, 40);
    const parentRelationship = clip(body?.parentRelationship, 32);
    const secondGuardianName = clip(body?.secondGuardianName, 120);
    const secondGuardianPhone = clip(body?.secondGuardianPhone, 32);
    const specialNeedsNotes = clip(body?.specialNeedsNotes, 400);
    const siblingAtSchool = clip(body?.siblingAtSchool, 120);
    const programNotes = clip(body?.programNotes, 400);
    const extraPrograms = stringList(body?.extraPrograms);
    const vaccinationUpToDate = body?.vaccinationUpToDate === true;
    const previousAverage = Number(body?.previousAverage);
    const documents = parseDocuments(body?.documents);

    if (!schoolId || !fullName || !guardianName) {
      return errorResponse(
        "schoolId, fullName, and guardianName are required.",
        400,
        "invalid",
      );
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateOfBirth)) {
      return errorResponse(
        "dateOfBirth is required (YYYY-MM-DD).",
        400,
        "invalid",
      );
    }
    const missingRequired = DOCUMENT_SPECS.filter((spec) => {
      if (!spec.required) return false;
      const doc = documents.find((d) => d.id === spec.id);
      return !doc?.submitted;
    });
    if (missingRequired.length > 0) {
      return errorResponse(
        `Attach: ${missingRequired.map((d) => d.label).join(", ")}.`,
        400,
        "documents_required",
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
      lastGradeCompleted,
      ...(Number.isFinite(previousAverage) ? { previousAverage } : {}),
      dateOfBirth,
      gender,
      nationality,
      homeLanguage,
      homeAddress,
      city,
      studentNationalId,
      parentNationalId,
      parentRelationship,
      secondGuardianName,
      secondGuardianPhone,
      specialNeedsNotes,
      siblingAtSchool,
      extraPrograms,
      programNotes,
      vaccinationUpToDate,
      notes: extraPrograms.length
        ? `Extra programmes: ${extraPrograms.join(", ")}`
        : "",
      documents,
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
