import { callerFromAppMetadata, isSchoolStaffOf } from "./caller.ts";

function expect(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

Deno.test("parent invites: only staff of the same school may send", () => {
  const admin = callerFromAppMetadata("u1", { role: "admin", schoolId: "sch1" });
  const registrar = callerFromAppMetadata("u2", {
    role: "teacher",
    schoolId: "SCH1",
    permissions: ["manage_students"],
  });
  const parent = callerFromAppMetadata("u3", { role: "parent", schoolId: "SCH1" });
  const student = callerFromAppMetadata("u4", { role: "student", schoolId: "SCH1" });
  const driver = callerFromAppMetadata("u5", { role: "driver", schoolId: "SCH1" });
  const otherSchool = callerFromAppMetadata("u6", { role: "admin", schoolId: "SCH2" });
  const anonymous = callerFromAppMetadata("u7", {});

  expect(isSchoolStaffOf(admin, "SCH1"), "admin of the school");
  expect(isSchoolStaffOf(registrar, "sch1"), "staff of the school (case-insensitive id)");
  expect(!isSchoolStaffOf(parent, "SCH1"), "parent refused");
  expect(!isSchoolStaffOf(student, "SCH1"), "student refused");
  expect(!isSchoolStaffOf(driver, "SCH1"), "driver refused");
  expect(!isSchoolStaffOf(otherSchool, "SCH1"), "other school's admin refused");
  expect(!isSchoolStaffOf(anonymous, "SCH1"), "anonymous session refused");
  expect(!isSchoolStaffOf(null, "SCH1"), "no JWT refused");
  expect(!isSchoolStaffOf(admin, ""), "missing school id refused");
});
