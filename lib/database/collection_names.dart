/// Firestore / backend collection names — single source of truth.
abstract final class DbCollections {
  static const users = 'users';
  static const classes = 'classes';
  static const students = 'students';
  static const parents = 'parents';
  static const parentStudentLinks = 'parent_student_links';
  static const teachers = 'teachers';
  static const teacherAssignments = 'teacher_assignments';
  static const drivers = 'drivers';
  static const routes = 'routes';
  static const transportAssignments = 'transport_assignments';
  static const attendance = 'attendance';
  static const grades = 'grades';
  static const announcements = 'announcements';
}
