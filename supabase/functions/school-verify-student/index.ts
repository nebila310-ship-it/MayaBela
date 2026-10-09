import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  adminClient,
  assertNotRateLimited,
  calendarDateIso,
  clientIp,
  findStudentRegistryRecord,
  getDoc,
  sameCalendarDay,
} from "../_shared/school_auth.ts";

function clip(value: unknown, max: number): string {
  return String(value ?? "").trim().slice(0, max);
}

/**
 * Public parent-link check: school + student id + date of birth.
 * No JWT — parents open the invite on a new phone with an empty roster.
 * Returns display/contact fields only (never passwords or medical notes).
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const body = await req.json().catch(() => ({}));
    const schoolId = clip(body?.schoolId, 24).toUpperCase();
    const studentId = clip(body?.studentId, 24).toUpperCase();
    const dobIso = calendarDateIso(body?.dateOfBirth);
    if (!schoolId || schoolId.length < 3 || !studentId || !dobIso) {
      return errorResponse(
        "School ID, student ID, and date of birth are required.",
        400,
        "invalid",
      );
    }

    const sb = adminClient();
    const ip = clientIp(req);
    await assertNotRateLimited(
      sb,
      `public_verify_student_${ip}`,
      30,
      15 * 60 * 1000,
    );

    const school = await getDoc(sb, "school_registry", schoolId, schoolId) ||
      await getDoc(sb, "school_registry", schoolId);
    if (!school) {
      return errorResponse("Student not found.", 404, "not_found");
    }

    const found = await findStudentRegistryRecord(sb, studentId, schoolId);
    const student = found?.data;
    const active = student?.isActive !== false;
    if (!student || !active || !sameCalendarDay(student.dateOfBirth, dobIso)) {
      return errorResponse("Student not found.", 404, "not_found");
    }

    const resolvedId = String(found?.id || student.studentId || studentId)
      .trim()
      .toUpperCase();
    return jsonResponse({
      ok: true,
      schoolId,
      studentId: resolvedId,
      fullName: clip(student.fullName, 120),
      className: clip(student.className, 80),
      grade: clip(student.grade, 40),
      dateOfBirth: calendarDateIso(student.dateOfBirth),
      fatherName: clip(student.fatherName, 80) || null,
      fatherPhone: clip(student.fatherPhone, 24) || null,
      motherName: clip(student.motherName, 80) || null,
      motherPhone: clip(student.motherPhone, 24) || null,
      guardianName: clip(student.guardianName, 80) || null,
      guardianPhone: clip(student.guardianPhone, 24) || null,
    });
  } catch (e) {
    const msg = String((e as Error)?.message || e);
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
