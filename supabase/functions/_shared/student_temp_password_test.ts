import { studentMayUsePortalTempPassword } from "./school_auth.ts";

function expect(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

Deno.test("template password is allowed only until the student sets their own", () => {
  expect(
    studentMayUsePortalTempPassword(null, false),
    "no account and no secret: template allowed",
  );
  expect(
    studentMayUsePortalTempPassword({ mustChangePassword: true }, true),
    "must still change: template allowed",
  );
  expect(
    !studentMayUsePortalTempPassword({ mustChangePassword: false }, true),
    "own password already set: template blocked",
  );
  expect(
    !studentMayUsePortalTempPassword(
      { mustChangePassword: false, firstLoginCompleted: false },
      true,
    ),
    "stale firstLoginCompleted must not reopen the template",
  );
});
