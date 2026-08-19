/// Application roles — matches [DbCollections.users].role values.
abstract final class UserRoles {
  static const admin = 'admin';
  static const teacher = 'teacher';
  static const driver = 'driver';
  static const parent = 'parent';

  static const all = [admin, teacher, driver, parent];
}
