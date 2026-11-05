// Per-record write rules for school-upsert-registry. That function writes
// with the service role, so the SQL write guard does not run; these rules
// stand in for it. Kept free of I/O so they can be unit tested.

export type RegistryCaller = {
  role: string;
  username: string;
  staffRoles: string[];
  permissions: string[];
  studentIds: string[];
};

// Fields only the Student Affairs desk (or the desk a case is escalated to)
// may change. Reporters file the case; the desk runs it.
export const DISCIPLINE_DESK_FIELDS = [
  "status",
  "outcome",
  "outcomeNotes",
  "hearingAt",
  "calendarEventId",
  "parentInvited",
  "escalatedTo",
  "handledByName",
] as const;

const DISCIPLINE_NEW_CASE_DEFAULTS: Record<string, unknown> = {
  status: "submitted",
  outcome: "none",
  outcomeNotes: "",
  hearingAt: null,
  parentInvited: false,
  escalatedTo: "",
  handledByName: "",
};

const STAFF_ROLE_ALIASES: Record<string, string> = {
  academic_admin: "section_director",
  hr_admin: "human_resource",
  finance: "accountant",
  vice_principal: "vice_president",
  finance_manager: "accountant",
  transport_head: "transport_admin",
};

export function canonicalStaffRole(role: unknown): string {
  const key = String(role ?? "").trim().toLowerCase();
  return STAFF_ROLE_ALIASES[key] ?? key;
}

/** True for the built-in key or a titled copy (`custom_principal_kg`). */
export function holdsStaffRole(roles: string[], want: string): boolean {
  const target = canonicalStaffRole(want);
  if (!target) return false;
  return roles.some((raw) => {
    const key = canonicalStaffRole(raw);
    return key === target || key.startsWith(`custom_${target}_`);
  });
}

function lowerTrim(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

function upperTrim(value: unknown): string {
  return String(value ?? "").trim().toUpperCase();
}

function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.map((v) => String(v ?? "")) : [];
}

export function callerFromMeta(meta: Record<string, unknown>): RegistryCaller {
  const studentIds = [
    upperTrim(meta.linkedStudentId || meta.linked_student_id),
    ...stringList(meta.linkedStudentIds).map(upperTrim),
  ];
  // Same fallback as the SQL read rules: a student without the claim is
  // identified by username.
  if (String(meta.role ?? "") === "student") {
    studentIds.push(upperTrim(meta.username || meta.userName));
  }
  return {
    role: String(meta.role ?? "").trim(),
    username: lowerTrim(meta.username || meta.userName),
    staffRoles: stringList(meta.staffRoles).map(canonicalStaffRole),
    permissions: stringList(meta.permissions),
    studentIds: studentIds.filter((id) => id.length > 0),
  };
}

function isOwner(c: RegistryCaller): boolean {
  return c.role === "admin" || holdsStaffRole(c.staffRoles, "full_access");
}

function hasAny(c: RegistryCaller, ...perms: string[]): boolean {
  return isOwner(c) || perms.some((p) => c.permissions.includes(p));
}

export function isDisciplineDesk(c: RegistryCaller): boolean {
  return hasAny(c, "manage_students") ||
    holdsStaffRole(c.staffRoles, "student_affairs");
}

/** Admissions are a registrar desk ('admissions' manage = manage_students). */
export function mayWriteAdmissions(c: RegistryCaller): boolean {
  return hasAny(c, "manage_students");
}

/**
 * Returns the record to store, or null when this caller may not write it.
 * [prior] is the stored row, when the collection needs it.
 */
export function guardRegistryRecord(
  collection: string,
  record: Record<string, unknown>,
  caller: RegistryCaller,
  prior?: Record<string, unknown> | null,
): Record<string, unknown> | null {
  switch (collection) {
    case "exam_attempts": {
      if (caller.role !== "student") return record;
      const sid = upperTrim(record.studentId);
      // Attempts started before the device knew the student's id arrive
      // without one; they belong to the signed-in student.
      if (!sid) {
        return caller.studentIds.length > 0
          ? { ...record, studentId: caller.studentIds[0] }
          : null;
      }
      return caller.studentIds.includes(sid) ? record : null;
    }
    case "curriculum_feedback": {
      // 'academic' module editors acknowledge and resolve everyone's notes.
      if (
        hasAny(
          caller,
          "manage_classes",
          "manage_subjects",
          "assign_teachers",
          "manage_timetables",
        )
      ) {
        return record;
      }
      return lowerTrim(record.authorUsername) === caller.username
        ? record
        : null;
    }
    case "mfa_enrollments": {
      // The go-live desk enrols and disables authenticators for others.
      if (hasAny(caller, "manage_school_settings", "manage_digital_ops")) {
        return record;
      }
      return lowerTrim(record.username) === caller.username ? record : null;
    }
    case "privacy_consents":
    case "data_rights_requests": {
      const desk = hasAny(caller, "manage_students", "manage_school_settings") ||
        holdsStaffRole(caller.staffRoles, "principal") ||
        holdsStaffRole(caller.staffRoles, "vice_president") ||
        holdsStaffRole(caller.staffRoles, "registrar");
      if (desk) return record;
      return lowerTrim(record.authorUsername) === caller.username
        ? record
        : null;
    }
    case "discipline_cases": {
      if (isDisciplineDesk(caller)) return record;
      const escalatedTo = canonicalStaffRole(prior?.escalatedTo);
      if (prior && escalatedTo && holdsStaffRole(caller.staffRoles, escalatedTo)) {
        return record;
      }
      const out = { ...record };
      for (const field of DISCIPLINE_DESK_FIELDS) {
        if (prior) {
          if (field in prior) {
            out[field] = prior[field];
          } else {
            delete out[field];
          }
        } else if (field in DISCIPLINE_NEW_CASE_DEFAULTS) {
          out[field] = DISCIPLINE_NEW_CASE_DEFAULTS[field];
        } else {
          delete out[field];
        }
      }
      return out;
    }
    default:
      return record;
  }
}
