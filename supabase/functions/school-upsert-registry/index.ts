import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { adminClient } from "../_shared/school_auth.ts";
import {
  callerFromMeta,
  guardRegistryRecord,
  isDisciplineDesk,
  mayWriteAdmissions,
} from "../_shared/registry_write_policy.ts";

const ALLOWED = new Set([
  "student_registry",
  "teacher_registry",
  "employee_registry",
  "driver_registry",
  "student_medical",
  "discipline_cases",
  "leave_requests",
  "admission_applications",
  "exam_questions",
  "exam_papers",
  "exam_attempts",
  "curriculum_feedback",
  "support_requests",
  "club_memberships",
  "scholarships",
  "grievances",
  "qa_survey_responses",
  "mfa_enrollments",
  "privacy_consents",
  "data_rights_requests",
]);

// Collections keyed by their own record id (many rows per student).
const OWN_ID_COLLECTIONS = new Set([
  "discipline_cases",
  "leave_requests",
  "admission_applications",
  "exam_questions",
  "exam_papers",
  "exam_attempts",
  "curriculum_feedback",
  "support_requests",
  "club_memberships",
  "scholarships",
  "grievances",
  "qa_survey_responses",
  "mfa_enrollments",
  "privacy_consents",
  "data_rights_requests",
]);

function normalizeRecord(
  raw: Record<string, unknown>,
  schoolId: string,
  fallbackDocId?: string,
  useOwnId = false,
): { docId: string; record: Record<string, unknown> } | null {
  const record = { ...raw };
  delete record._docId;
  delete record.initialPassword;
  record.schoolId = schoolId;
  record.updatedAt = new Date().toISOString();

  if (useOwnId) {
    const ownId = String(record.id || fallbackDocId || "").trim();
    if (!ownId) return null;
    return { docId: ownId, record };
  }

  let docId = String(
    record.studentId ||
      record.teacherId ||
      record.employeeId ||
      record.driverId ||
      fallbackDocId ||
      "",
  )
    .trim()
    .toUpperCase();
  if (!docId) return null;
  if (record.studentId) record.studentId = docId;
  if (record.teacherId) record.teacherId = docId;
  if (record.employeeId) record.employeeId = docId;
  if (record.driverId) record.driverId = docId;
  return { docId, record };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json();
    const collection = String(body?.collection || "").trim();
    const schoolId = String(body?.schoolId || "").trim().toUpperCase();
    const rawList: unknown[] = Array.isArray(body?.records)
      ? body.records
      : body?.record && typeof body.record === "object"
      ? [body.record]
      : [];

    if (!ALLOWED.has(collection) || !schoolId || rawList.length === 0) {
      return errorResponse(
        "collection, schoolId, and record/records are required.",
        400,
        "invalid",
      );
    }

    const authHeader = req.headers.get("Authorization") || "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const authClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      anon || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      {
        global: {
          headers: jwt ? { Authorization: `Bearer ${jwt}` } : {},
        },
      },
    );

    const { data: userData, error: userErr } = jwt
      ? await authClient.auth.getUser(jwt)
      : await authClient.auth.getUser();
    const caller = userData.user;
    if (!caller) {
      return errorResponse(
        `School sign-in required${userErr ? `: ${userErr.message}` : ""}.`,
        401,
        "denied",
      );
    }

    const meta = (caller.app_metadata || {}) as Record<string, unknown>;
    const callerRole = String(meta.role || "").trim();
    const callerSchool = String(meta.schoolId || meta.school_id || "")
      .trim()
      .toUpperCase();
    const callerPerms = Array.isArray(meta.permissions)
      ? (meta.permissions as unknown[]).map((p) => String(p))
      : [];

    if (!callerSchool || callerSchool !== schoolId) {
      return errorResponse(
        `School mismatch (caller=${callerSchool || "none"}, target=${schoolId}).`,
        403,
        "denied",
      );
    }

    const isAdmin = callerRole === "admin";
    // Writes require manage_* — view_* and a bare classroom teacher JWT
    // must not bypass RLS via this service-role upsert.
    const canStudents = isAdmin || callerPerms.includes("manage_students");
    const canStaff = isAdmin || callerPerms.includes("manage_staff_accounts");
    const canDrivers = isAdmin || callerPerms.includes("manage_drivers");
    const writer = callerFromMeta(meta);

    if (collection === "admission_applications" && !mayWriteAdmissions(writer)) {
      return errorResponse(
        "Not allowed to write admission applications.",
        403,
        "denied",
      );
    }

    if (
      (collection === "student_registry" || collection === "student_medical") &&
      !canStudents
    ) {
      return errorResponse("Not allowed to write student registry.", 403, "denied");
    }
    if (collection === "teacher_registry" && !canStaff) {
      return errorResponse("Not allowed to write staff directory.", 403, "denied");
    }
    if (collection === "employee_registry" && !canStaff) {
      return errorResponse("Not allowed to write employee registry.", 403, "denied");
    }
    if (collection === "driver_registry" && !canDrivers) {
      return errorResponse("Not allowed to write driver registry.", 403, "denied");
    }
    // Student Affairs cases: teachers file them; the desk (manage_students)
    // records outcomes. A classroom teacher JWT must be able to upsert a
    // report or it only exists on that laptop.
    if (collection === "discipline_cases") {
      const canDiscipline = isAdmin ||
        canStudents ||
        callerRole === "teacher" ||
        callerRole === "staff";
      if (!canDiscipline) {
        return errorResponse(
          "Not allowed to write discipline cases.",
          403,
          "denied",
        );
      }
    }
    // Leave requests: parents submit for their child; staff review.
    if (
      collection === "leave_requests" &&
      !canStudents &&
      callerRole !== "parent"
    ) {
      return errorResponse(
        "Not allowed to write leave requests.",
        403,
        "denied",
      );
    }
    // Exam bank / papers: staff only. Attempts: staff + the student sitting.
    if (
      (collection === "exam_questions" || collection === "exam_papers") &&
      callerRole !== "admin" &&
      callerRole !== "teacher"
    ) {
      return errorResponse("Not allowed to write the exam bank.", 403, "denied");
    }
    if (
      collection === "exam_attempts" &&
      callerRole !== "admin" &&
      callerRole !== "teacher" &&
      callerRole !== "student"
    ) {
      return errorResponse("Not allowed to write exam attempts.", 403, "denied");
    }
    // Phase G: parents/students file care requests; staff review.
    if (
      collection === "support_requests" &&
      !canStudents &&
      callerRole !== "parent" &&
      callerRole !== "student"
    ) {
      return errorResponse(
        "Not allowed to write student-support requests.",
        403,
        "denied",
      );
    }
    if (
      (collection === "club_memberships" ||
        collection === "scholarships" ||
        collection === "grievances") &&
      !canStudents &&
      callerRole !== "parent" &&
      callerRole !== "student"
    ) {
      return errorResponse(
        "Not allowed to write student-program records.",
        403,
        "denied",
      );
    }
    if (
      collection === "qa_survey_responses" &&
      !canStudents &&
      callerRole !== "parent" &&
      callerRole !== "student" &&
      callerRole !== "teacher" &&
      callerRole !== "admin"
    ) {
      return errorResponse("Not allowed to write survey responses.", 403, "denied");
    }
    if (
      collection === "mfa_enrollments" &&
      callerRole !== "admin" &&
      callerRole !== "teacher" &&
      callerRole !== "parent" &&
      callerRole !== "student"
    ) {
      return errorResponse("Not allowed to write authenticator enrollments.", 403, "denied");
    }
    if (
      (collection === "privacy_consents" ||
        collection === "data_rights_requests") &&
      !canStudents &&
      callerRole !== "parent" &&
      callerRole !== "student" &&
      callerRole !== "teacher" &&
      callerRole !== "admin"
    ) {
      return errorResponse("Not allowed to write privacy records.", 403, "denied");
    }

    const sb = adminClient();

    const priorDisciplineCases = new Map<string, Record<string, unknown>>();
    if (collection === "discipline_cases" && !isDisciplineDesk(writer)) {
      const ids = rawList
        .map((raw) =>
          raw && typeof raw === "object"
            ? String((raw as Record<string, unknown>).id || "").trim()
            : ""
        )
        .filter((id) => id.length > 0);
      if (ids.length > 0) {
        const { data: prior, error: priorErr } = await sb
          .from("app_documents")
          .select("doc_id, data")
          .eq("collection", collection)
          .eq("school_id", schoolId)
          .in("doc_id", ids);
        if (priorErr) {
          return errorResponse(
            `Registry save failed: ${priorErr.message}`,
            500,
            "invalid",
          );
        }
        for (const row of prior ?? []) {
          priorDisciplineCases.set(
            String(row.doc_id),
            (row.data ?? {}) as Record<string, unknown>,
          );
        }
      }
    }

    const rows: Array<{
      collection: string;
      doc_id: string;
      school_id: string;
      data: Record<string, unknown>;
      updated_at: string;
    }> = [];
    let skipped = 0;
    for (const raw of rawList) {
      if (!raw || typeof raw !== "object") continue;
      const normalized = normalizeRecord(
        raw as Record<string, unknown>,
        schoolId,
        typeof body?.docId === "string" ? body.docId : undefined,
        OWN_ID_COLLECTIONS.has(collection),
      );
      if (!normalized) continue;
      // teacher_registry must never be an auth privilege vector.
      if (collection === "teacher_registry") {
        const canAssign =
          isAdmin || callerPerms.includes("assign_roles");
        if (!canAssign) {
          delete normalized.record.staffRoles;
        }
      }
      // Parents may only write leave requests for linked students.
      if (collection === "leave_requests" && callerRole === "parent") {
        const linked = Array.isArray(meta.linkedStudentIds)
          ? (meta.linkedStudentIds as unknown[]).map((x) =>
            String(x || "").trim().toUpperCase()
          )
          : [];
        const sid = String(normalized.record.studentId || "").trim().toUpperCase();
        if (!sid || !linked.includes(sid)) {
          skipped++;
          continue;
        }
      }
      // Parents/students may only file support requests for linked students.
      if (
        (collection === "support_requests" ||
          collection === "club_memberships" ||
          collection === "scholarships" ||
          collection === "grievances") &&
        (callerRole === "parent" || callerRole === "student")
      ) {
        const linked = Array.isArray(meta.linkedStudentIds)
          ? (meta.linkedStudentIds as unknown[]).map((x) =>
            String(x || "").trim().toUpperCase()
          )
          : [];
        const selfId = String(
          meta.linkedStudentId || meta.linked_student_id || "",
        ).trim().toUpperCase();
        const sid = String(normalized.record.studentId || "").trim().toUpperCase();
        const allowed = new Set(
          [...linked, selfId].filter((id) => id.length > 0),
        );
        if (!sid || !allowed.has(sid)) {
          skipped++;
          continue;
        }
      }
      if (
        collection === "qa_survey_responses" &&
        (callerRole === "parent" ||
          callerRole === "student" ||
          callerRole === "teacher")
      ) {
        const author = String(normalized.record.authorUsername || "")
          .trim()
          .toLowerCase();
        const uname = String(meta.username || meta.userName || "")
          .trim()
          .toLowerCase();
        if (!author || !uname || author !== uname) {
          skipped++;
          continue;
        }
      }
      const guarded = guardRegistryRecord(
        collection,
        normalized.record,
        writer,
        priorDisciplineCases.get(normalized.docId),
      );
      if (!guarded) {
        skipped++;
        continue;
      }
      rows.push({
        collection,
        doc_id: normalized.docId,
        school_id: schoolId,
        data: guarded,
        updated_at: new Date().toISOString(),
      });
    }
    if (rows.length === 0) {
      if (skipped > 0) {
        return errorResponse(
          "Not allowed to write these records.",
          403,
          "denied",
        );
      }
      return errorResponse("No valid records to save.", 400, "invalid");
    }

    // Chunk to keep payload reasonable.
    const chunkSize = 80;
    for (let i = 0; i < rows.length; i += chunkSize) {
      const chunk = rows.slice(i, i + chunkSize);
      const { error: upsertErr } = await sb.from("app_documents").upsert(chunk, {
        onConflict: "collection,school_id,doc_id",
      });
      if (upsertErr) {
        return errorResponse(
          `Registry save failed: ${upsertErr.message}`,
          500,
          "invalid",
        );
      }
    }

    return jsonResponse({
      ok: true,
      collection,
      count: rows.length,
      skipped,
      docId: rows.length === 1 ? rows[0].doc_id : undefined,
    });
  } catch (e) {
    console.error(e);
    return errorResponse(String((e as Error)?.message || e), 500, "invalid");
  }
});
