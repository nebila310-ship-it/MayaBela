import {
  callerFromMeta,
  guardRegistryRecord,
  mayWriteAdmissions,
} from "./registry_write_policy.ts";

function expect(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

const teacher = callerFromMeta({
  role: "teacher",
  username: "Teacher1",
  staffRoles: [],
  permissions: ["access_support"],
});
const studentAffairs = callerFromMeta({
  role: "teacher",
  username: "sa1",
  staffRoles: ["student_affairs"],
  permissions: ["view_students", "manage_students"],
});
const principal = callerFromMeta({
  role: "teacher",
  username: "pri1",
  staffRoles: ["principal"],
  permissions: ["view_all_school_data", "manage_digital_ops", "manage_classes"],
});
const registrar = callerFromMeta({
  role: "teacher",
  username: "reg1",
  staffRoles: ["registrar"],
  permissions: ["manage_students"],
});
const parent = callerFromMeta({
  role: "parent",
  username: "par1",
  linkedStudentIds: ["STU1"],
});
const student = callerFromMeta({
  role: "student",
  username: "stu1",
  linkedStudentId: "stu1",
});
const legacyStudent = callerFromMeta({ role: "student", username: "STU7" });
const admin = callerFromMeta({ role: "admin", username: "owner" });

Deno.test("admissions are written by the registrar desk only", () => {
  expect(mayWriteAdmissions(registrar), "registrar must write admissions");
  expect(mayWriteAdmissions(admin), "school admin must write admissions");
  expect(!mayWriteAdmissions(teacher), "classroom teacher must not");
  expect(!mayWriteAdmissions(parent), "parent must not");
});

Deno.test("students write only their own exam attempts", () => {
  const own = { id: "a1", studentId: "STU1" };
  const other = { id: "a2", studentId: "STU2" };
  expect(guardRegistryRecord("exam_attempts", own, student) !== null, "own attempt");
  expect(guardRegistryRecord("exam_attempts", other, student) === null, "other attempt");
  expect(
    guardRegistryRecord("exam_attempts", { id: "a3", studentId: "STU7" }, legacyStudent) !==
      null,
    "student without linkedStudentId falls back to username",
  );
  expect(
    guardRegistryRecord("exam_attempts", other, teacher) !== null,
    "teachers still save attempts they mark",
  );
  const unlabelled = guardRegistryRecord("exam_attempts", { id: "a4" }, student);
  expect(unlabelled?.studentId === "STU1", "attempt without an id is the student's own");
});

Deno.test("curriculum feedback: authors own notes, academic leads review all", () => {
  const mine = { id: "CF1", authorUsername: "teacher1", status: "open" };
  const theirs = { id: "CF2", authorUsername: "someone", status: "resolved" };
  expect(guardRegistryRecord("curriculum_feedback", mine, teacher) !== null, "own note");
  expect(guardRegistryRecord("curriculum_feedback", theirs, teacher) === null, "other note");
  expect(
    guardRegistryRecord("curriculum_feedback", theirs, principal) !== null,
    "academic lead resolves any note",
  );
  expect(
    guardRegistryRecord("curriculum_feedback", theirs, parent) === null,
    "parent cannot edit someone else's note",
  );
});

Deno.test("authenticator enrolments: own row, or the go-live desk", () => {
  const mine = { id: "MFA1", username: "teacher1" };
  const theirs = { id: "MFA2", username: "pri1" };
  expect(guardRegistryRecord("mfa_enrollments", mine, teacher) !== null, "own enrolment");
  expect(guardRegistryRecord("mfa_enrollments", theirs, teacher) === null, "other enrolment");
  expect(
    guardRegistryRecord("mfa_enrollments", mine, principal) !== null,
    "go-live desk manages others",
  );
});

Deno.test("privacy records: authors own requests, privacy desk handles all", () => {
  const mine = { id: "PC1", authorUsername: "par1" };
  const theirs = { id: "PC2", authorUsername: "par2" };
  expect(guardRegistryRecord("privacy_consents", mine, parent) !== null, "own consent");
  expect(guardRegistryRecord("data_rights_requests", theirs, parent) === null, "other request");
  expect(guardRegistryRecord("data_rights_requests", theirs, teacher) === null, "teacher");
  expect(guardRegistryRecord("data_rights_requests", theirs, registrar) !== null, "registrar");
  expect(guardRegistryRecord("privacy_consents", theirs, principal) !== null, "principal");
});

Deno.test("discipline: teachers file cases, only the desk sets the outcome", () => {
  const filed = {
    id: "dc-1",
    title: "Fight at break",
    reporterId: "teacher1",
    status: "resolved",
    outcome: "suspension",
    outcomeNotes: "made up",
    escalatedTo: "principal",
  };
  const newCase = guardRegistryRecord("discipline_cases", filed, teacher, null)!;
  expect(newCase.title === "Fight at break", "teacher report is kept");
  expect(newCase.status === "submitted", "new case starts submitted");
  expect(newCase.outcome === "none", "new case has no outcome");
  expect(newCase.escalatedTo === "", "teacher cannot escalate on filing");

  const stored = {
    id: "dc-1",
    status: "hearingScheduled",
    outcome: "none",
    hearingAt: "2026-11-10T09:00:00Z",
    escalatedTo: "principal",
  };
  const resync = guardRegistryRecord("discipline_cases", filed, teacher, stored)!;
  expect(resync.status === "hearingScheduled", "teacher re-sync keeps desk status");
  expect(resync.hearingAt === "2026-11-10T09:00:00Z", "hearing kept");
  expect(!("outcomeNotes" in resync), "teacher outcome notes dropped");

  const desk = guardRegistryRecord("discipline_cases", filed, studentAffairs, stored)!;
  expect(desk.status === "resolved", "Student Affairs records the outcome");

  const escalated = guardRegistryRecord("discipline_cases", filed, principal, stored)!;
  expect(escalated.outcome === "suspension", "escalated desk records the outcome");

  const notEscalated = guardRegistryRecord(
    "discipline_cases",
    filed,
    principal,
    { ...stored, escalatedTo: "vice_president" },
  )!;
  expect(notEscalated.status === "hearingScheduled", "other desks cannot");
});

Deno.test("staff role aliases are canonical", () => {
  const legacyVp = callerFromMeta({
    role: "teacher",
    username: "vp1",
    staffRoles: ["vice_principal"],
  });
  const result = guardRegistryRecord(
    "discipline_cases",
    { id: "dc-2", status: "dismissed" },
    legacyVp,
    { id: "dc-2", status: "escalated", escalatedTo: "vice_president" },
  )!;
  expect(result.status === "dismissed", "legacy vice_principal holds vice_president");
});
