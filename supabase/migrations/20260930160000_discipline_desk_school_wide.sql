-- Student Affairs must see teacher-filed discipline cases on every device.
-- Classroom teachers stay class-scoped; the desk role is school-wide.

create or replace function public.jwt_can_read_all_school_data()
returns boolean
language sql
stable
as $$
  select public.jwt_role() = 'admin'
      or public.jwt_staff_roles() ? 'full_access'
      or public.jwt_staff_roles() ? 'student_affairs'
      or public.jwt_has_permission('view_all_school_data')
      or public.jwt_has_permission('view_all_departments');
$$;
