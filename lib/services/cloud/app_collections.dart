/// Firestore collection names for the eduaba app layer.
abstract final class AppCollections {
  // Registry & auth (CloudAppStore)
  static const authAccounts = 'app_auth_accounts';
  static const parentLinkRequests = 'parent_link_requests';
  static const studentMedical = 'student_medical';
  static const studentRegistry = 'student_registry';
  static const teacherRegistry = 'teacher_registry';
  static const driverRegistry = 'driver_registry';
  static const employeeRegistry = 'employee_registry';

  // Teacher / parent features
  static const gradeReports = 'grade_reports';
  static const homework = 'homework';
  static const dailyActivities = 'daily_activities';
  static const conversations = 'conversations';
  static const announcements = 'app_announcements';
  static const attendanceSessions = 'attendance_sessions';
  static const fees = 'fees';
  static const calendarEvents = 'calendar_events';
  static const classTimetables = 'class_timetables';
  static const galleryPosts = 'gallery_posts';
  static const learningMaterials = 'learning_materials';
  static const materialPurchaseRequests = 'material_purchase_requests';
  static const gradeAuditLog = 'grade_audit_log';
  static const qrScans = 'qr_scans';
  static const schoolRegistry = 'school_registry';
  static const platformAudit = 'platform_audit_log';
  static const fcmTokens = 'fcm_tokens';
  static const transportScans = 'transport_scans';
  static const transportPassengerStatus = 'transport_passenger_status';
  static const busLivePositions = 'bus_live_positions';
  static const appNotifications = 'app_notifications';

  // Procurement & store workflows (names match the SQL write-guard gates)
  static const purchaseRequests = 'purchase_requests';
  static const issueRequests = 'issue_requests';
  static const transferRequests = 'transfer_requests';
  static const buses = 'buses';
  static const schoolAuditLog = 'school_audit_log';

  // Student Affairs & welfare (EDUABA)
  static const disciplineCases = 'discipline_cases';
  static const leaveRequests = 'leave_requests';
  static const admissionApplications = 'admission_applications';

  /// LIA Phase C exams: question bank, papers, student attempts.
  static const examQuestions = 'exam_questions';
  static const examPapers = 'exam_papers';
  static const examAttempts = 'exam_attempts';

  /// LIA Phase D lesson plans (planning/content; not a grade store).
  static const lessonPlans = 'lesson_plans';

  /// LIA Phase E curriculum office (maps, feedback, DH reviews, academic evals).
  static const curriculumUnits = 'curriculum_units';
  static const curriculumFeedback = 'curriculum_feedback';
  static const lessonPlanReviews = 'lesson_plan_reviews';
  static const teacherEvaluations = 'teacher_evaluations';
  static const academicMeetings = 'academic_meetings';

  /// LIA Phase G student support (health, counseling, IEP, college, CP).
  static const healthRecords = 'health_records';
  static const counselingRecords = 'counseling_records';
  static const iepPlans = 'iep_plans';
  static const collegeGuidance = 'college_guidance';
  static const supportRequests = 'support_requests';
  static const safeguardingCases = 'safeguarding_cases';

  /// LIA Phase H DoSA programs (clubs/Gojo, scholarships, grievances).
  static const extracurricularClubs = 'extracurricular_clubs';
  static const clubMemberships = 'club_memberships';
  static const scholarships = 'scholarships';
  static const grievances = 'grievances';
  static const internships = 'internships';
  static const dosaMeetings = 'dosa_meetings';

  // Quality Assurance (EDUABA §2)
  static const qaFindings = 'qa_findings';

  /// LIA Phase I QA monitoring (observations, audits, surveys, action research).
  static const teachingObservations = 'teaching_observations';
  static const academicAudits = 'academic_audits';
  static const qaSurveys = 'qa_surveys';
  static const qaSurveyResponses = 'qa_survey_responses';
  static const actionResearch = 'action_research';

  /// LIA Phase J go-live (MFA, privacy rights, school backups).
  static const mfaEnrollments = 'mfa_enrollments';
  static const privacyConsents = 'privacy_consents';
  static const dataRightsRequests = 'data_rights_requests';
  static const schoolBackups = 'school_backups';

  // School inventory
  static const inventoryItems = 'inventory_items';
  static const stockTransactions = 'stock_transactions';
  static const studentIssuedItems = 'student_issued_items';
  static const classroomInventory = 'classroom_inventory';
  static const assets = 'assets';
  static const suppliers = 'suppliers';
  static const maintenanceReports = 'maintenance_reports';
}
