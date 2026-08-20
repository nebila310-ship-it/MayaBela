import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/class_timetable.dart';
import 'package:mayabela/l10n/oromo_catalog.dart';
import 'package:mayabela/l10n/parent_guardian_terms.dart';
import 'package:mayabela/services/school_registry_service.dart';

class AppStrings implements AppStringsLike {
  AppStrings(this.languageCode);

  final String languageCode;
  bool get isAmharic => languageCode == 'am';
  bool get isOromo => languageCode == 'om';

  String t(String en, String am, [String? om]) {
    switch (languageCode) {
      case 'am':
        return am;
      case 'om':
        return om ?? OromoCatalog.lookup(en) ?? en;
      default:
        return en;
    }
  }

  String get appTitle =>
      t('MaJo e-School Bridge', 'MaJo e-School Bridge');
  String get tagline => t('Eye can Observe, Maya can Connect Us', 'ዓይን ትመለከታለች፣ ማያ ያገናኘናል');
  String get iAm => t('I am', 'እኔ');
  String get signInAs => t('Sign in as', 'በዚህ ሚና ግባ');
  String get welcomeBack => t('Welcome back', 'እንኳን ደህና መጡ');
  String get schoolId => t('School ID', 'የትምህርት ቤት መለያ');
  String get invalidSchoolId => t('Enter a valid School ID (e.g. TB-001)', 'ትክክለኛ የትምህርት ቤት መለያ ያስገቡ (ለምሳሌ TB-001)');
  String get schoolAccessInactive => t(
        'This school account is inactive. Contact Maya School support to restore access.',
        'የትምህርት ቤቱ መለያ ተሰናክሏል። ድጋፍ ለመጠየቅ Maya School ያግኙ።',
        'Akkaawuntiin mana barumsaa kana hin hojjetu. Gargaarsaaf Maya School qunnamaa.',
      );
  String get schoolAccessSuspended => t(
        'This school account is suspended. Contact Maya School support.',
        'የትምህርት ቤቱ መለያ ታግዷል። Maya School ድጋፍ ያግኙ።',
        'Akkaawuntiin mana barumsaa kana dhaabbateera. Maya School qunnamaa.',
      );
  String get schoolAccessExpired => t(
        'This school subscription has expired. Contact Maya School to renew.',
        'የትምህርት ቤቱ መዋቅር ጊዜው አልፏል። ለማደስ Maya School ያግኙ።',
        'Galmeeffamni mana barumsaa kana yeroon isaa darbeera. Haaromsuuf Maya School qunnamaa.',
      );
  String get needSchoolAccess => t(
        'School access is provided by Maya School. Contact us to get your School ID.',
        'የትምህርት ቤት መዳረሻ በ Maya School ይሰጣል። School ID ለማግኘት ያግኙን።',
        'Dhaqqabummaan mana barumsaa Maya School irraa kenname. ID argachuuf nu qunnamaa.',
      );

  String schoolAccessMessage(String? code) {
    return switch (code) {
      'school_inactive' => schoolAccessInactive,
      'school_suspended' => schoolAccessSuspended,
      'school_expired' => schoolAccessExpired,
      'school_not_found' => invalidSchoolId,
      _ => invalidSchoolId,
    };
  }
  String get emailPhone => t('Email / Phone', 'ኢሜይል / ስልክ');
  String get phoneNumber => t('Phone number', 'ስልክ ቁጥር');
  String get phoneOrUsername =>
      t('Phone or username', 'ስልክ / ተጠቃሚ ስም');
  String get phoneLoginHint =>
      t('0911234567', '0911234567');
  String get phoneLoginHelp => t('Use this number to log in and receive OTP codes.', 'ይህን ቁጥር ለመግቢያ እና OTP ይጠቀሙበታል።');
  String get emailOptional =>
      t('Email (optional)', 'ኢሜይል (አማራጭ)');
  String get emailRequired => t(
        'Enter a valid email address',
        'ትክክለኛ ኢሜይል ያስገቡ',
        'Imeelii sirrii galchi',
      );
  String get invalidPhone => t('Enter a valid phone number (e.g. 0911234567)', 'ትክክለኛ Ethiopian ስልክ ቁጥር ያስገቡ (ለምሳሌ 0911234567)');
  String get phoneAlreadyRegistered => t('This phone number is already registered', 'ይህ ስልክ ቁጥር ቀድሞ ተመዝግቧል');
  String get phoneUsedByStaff => t(
        'This phone number is already used by a staff account. Use the parent contact number from the student record, or contact the school.',
        'ይህ ስልክ ቁጥር በሰራተኛ መለያ ጥቅም ላይ ውሏል። ከተማሪ መዝገብ የወላጅ ቁጥር ይጠቀሙ ወይም ትምህርት ቤቱን ያግኙ።',
        'Lakkoofsi bilbilaa kun akkaawuntii hojjettootaa irratti fayyadama. Lakkoofsa quunnamtii warraa barataa irraa fayyadamaa yookiin mana barumsaa qunnamaa.',
      );
  String loginIdentifierLabel(String roleKey) {
    if (roleKey == 'parent' || roleKey == 'driver') return phoneNumber;
    if (roleKey == 'student') {
      return t('Username or Student ID', 'የተጠቃሚ ስም ወይም የተማሪ መለያ');
    }
    // teacher, staff, admin — phone login
    return phoneOrUsername;
  }
  String get password => t('Password', 'የይለፍ ቃል');
  String get rememberMe => t('Remember me', 'አስታውሰኝ');
  String get login => t('Login', 'ግባ');
  String get signUp => t('Sign up', 'ተመዝገብ');
  String get forgotPassword => t('Forgot password?', 'የይለፍ ቃል ረሳሽ?');
  String get loginCopyright => t(
        '© ${DateTime.now().year} MaJo e-School Bridge. All rights reserved.',
        '© ${DateTime.now().year} MaJo e-School Bridge. መብቶች በሙሉ የተጠበቁ ናቸው።',
        '© ${DateTime.now().year} MaJo e-School Bridge. Mirgi hundi eegame.',
      );
  String get loginPoweredBy => t(
        'Powered by MaJo Bridge Technologies Inc',
        'በ MaJo Bridge Technologies Inc የተጎላ',
        'MaJo Bridge Technologies Inc tiin kan hojjetame',
      );
  String get language => t('Language', 'ቋንቋ');
  String get english => 'English';
  String get amharic => 'አማርኛ';
  String get oromo => 'Afaan Oromoo';
  String get help => t('Help', 'እገዛ');
  String get callSupport => t('Call +251911646444', 'ደውል +251911646444');
  String get reportIssue => t('Report Issue', 'ጉዳይ ሪፖርት');
  String get reportTitle => t('Report an Issue', 'ጉዳይ ሪፖርት አቀርብ');
  String get reportIssueSubtitle => t(
        'Describe the issue and we will send it directly to our support team.',
        'ጉዳዩን ይግለጹ — በቀጥታ ለድጋፍ ቡድናችን እንልክለዎታለን።',
      );
  String get reportIssueCategory => t('Issue type', 'የጉዳይ አይነት');
  String get reportCategoryBug => t('Bug', 'ስህተት');
  String get reportCategoryLogin => t('Login / access', 'መግቢያ / መዳረሻ');
  String get reportCategoryData => t('Data / grades', 'መረጃ / ደረጃ');
  String get reportCategoryOther => t('Other', 'ሌላ');
  String get reportTransportTitle =>
      t('Report a Transport Issue', 'የመጓዝ ጉዳይ ሪፖርት አቀርብ');
  String get reportTransportSubtitle => t(
        'Report a car problem, traffic delay, or accident on your route.',
        'በመንገድዎ ላይ የመኪና ችግር፣ የትራፊክ መዘግየት ወይም አደጋ ሪፖርት ያድርጉ።',
      );
  String get reportCategoryCarIssue => t('Car issue', 'የመኪና ችግር');
  String get reportCategoryTrafficIssue =>
      t('Traffic issue', 'የትራፊክ ችግር');
  String get reportCategoryAccident => t('Accident', 'አደጋ');
  String get reportTransportDetailsHint => t(
        'Describe what happened — location, time, and how it affects the route.',
        'ምን ተከሰተ ይግለጹ — ቦታ፣ ጊዜ እና በመንገድ ላይ ያለው ተጽዕኖ።',
      );
  String get reportIssueDetailsHint => t(
        'What happened? Steps to reproduce help us fix it faster.',
        'ምን ተከሰተ? እንዴት እንደሚደገም ካሳዩ በፍጥነት እንድንፈታል ይረዳנል።',
      );
  String get reportIssueEmailNote => t(
        'Your report will be sent directly to our support team at',
        'ሪፖርትዎ በቀጥታ ለድጋፍ ቡድናችን ይላካል',
      );
  String get yourName => t('Your Name', 'ስምዎ');
  String get issueDescription => t('Describe the issue', 'ጉዳይ መግለጫ');
  String get send => t('Send', 'ላክ');
  String get reportSent => t('Report sent!', 'ሪፖርት ተልኳል!');
  String get callFailed => t('Could not open dialer', 'ጥሪ መክፈት አልተቻለም');
  String get emailFailed => t('Could not open email', 'ኢሜይል መክፈት አልተቻለም');

  String roleLabel(String roleKey) {
    switch (roleKey) {
      case 'teacher':
        return t('Teacher 👩‍🏫', 'መምህር 👩‍🏫', 'Barsiisaa 👩‍🏫');
      case 'staff':
        return t(
          'Administration Staff',
          'የአስተዳደር ሰራተኛ',
          'Hojjettaa Bulchiinsaa',
        );
      case 'parent':
        return t('Parent/Guardian 👨‍👩‍👧', 'ወላጅ 👨‍👩‍👧');
      case 'admin':
        return t('Admin 🏫', 'አስተዳዳሪ 🏫');
      case 'driver':
        return t('Transport 🚌', 'ትራንስፖርት 🚌');
      case 'student':
        return t('Student 🎓', 'ተማሪ 🎓');
      default:
        return roleKey;
    }
  }

  String get createAccount => t('Create Account', 'መለያ ፍጠር');
  String get fullName => t('Full Name', 'ሙሉ ስም');
  String get email => t('Email', 'ኢሜይል');
  String get phone => t('Phone', 'ስልክ');
  String get confirmPassword => t('Confirm Password', 'የይለፍ ቃል አረጋግጥ');
  String get studentId => t('Student ID', 'የተማሪ መለያ');
  String get lookupStudent => t('Look up Student', 'ተማሪ ፈልግ');
  String get addStudentLink => t('+ Add Student', '+ ተማሪ ጨምር');
  String get myChildren => t('My Children', 'ልጆቼ');
  String get studentFound => t('Student found', 'ተማሪ ተገኝቷል');
  String get studentNotFound => t('Student not found', 'ተማሪ አልተገኘም');
  String get grade => t('Grade', 'ክፍል');
  String get className => t('Class', 'ክፍል ስም');
  String get accountCreated => t('Account Created', 'መለያ ተፈጥሯል');
  String get goToLogin => t('Go to Login', 'ወደ መግቢያ ሂድ');

  String get forgotPasswordTitle => t('Reset Password', 'የይለፍ ቃል ዳግም አስጀምር');
  String get enterEmailOrPhone =>
      t('Registered phone number', 'የተመዘገበ ስልክ ቁጥር');
  String get sendOtp => t('Send OTP', 'OTP ላክ');
  String get chooseOtpChannel => t('How should we send your OTP?', 'OTP እንዴት እንልክልዎ?');
  String get sendViaSms => t('SMS', 'SMS');
  String get sendViaWhatsApp => t('WhatsApp', 'WhatsApp');
  String get sendViaTelegram => t('Telegram', 'Telegram');
  String otpDeliveredVia(String channel) => t('OTP sent via $channel', 'OTP በ$channel ተልኳል');
  String get otpDeliveryFailed => t('Could not open SMS, WhatsApp, or Telegram', 'SMS / WhatsApp / Telegram መክፈት አልተሳካም');
  String get reEnterPassword =>
      t('Re-enter password', 'የይለፍ ቃል እንደገና አስገባ');
  String get savedSchoolIdsHint => t('Saved School IDs — tap to pick', 'የተቀመጡ School ID — ለመምረጥ መታ ያድርጉ');
  String get enterOtp => t('Enter OTP code', 'OTP ኮድ አስገባ');
  String get newPassword => t('New Password', 'አዲስ የይለፍ ቃል');
  String get resetPassword => t('Reset Password', 'የይለፍ ቃል ቀይር');
  String get otpSent => t('OTP sent!', 'OTP ተልኳል!');
  String get userNotFound =>
      t('No registered account found', 'ተጠቃሚ አልተገኘም');
  String get invalidOtp => t('Invalid OTP', 'OTP ስህተት ነው');
  String get passwordResetSuccess =>
      t('Password reset successful!', 'የይለፍ ቃል ተቀይሯል!');
  String get demoOtpNote => t('(Demo: OTP shown in app for testing)', '(ማሳያ OTP በመተግበሪያው ላይ ይታያል)');

  String get enterName => t('Please enter your name', 'ስምዎን ያስገቡ');
  String get enterSchoolId =>
      t('Please enter School ID', 'የትምህርት ቤት መለያ ያስገቡ');
  String get enterEmailOrPhoneSignup =>
      t('Enter email or phone number', 'ኢሜይል ወይም ስልክ ያስገቡ');
  String get passwordTooShort => t(
        'Password must be at least 10 characters',
        'የይለፍ ቃል ቢያንስ 10 ፊደላት',
      );
  String get passwordsNoMatch =>
      t('Passwords do not match', 'የይለፍ ቃሎች አይዛመዱም');
  String get addAtLeastOneChild => t('Add at least one student with valid ID', 'ቢያንስ አንድ ተማሪ መለያ ጨምሩ');
  String get teacherId =>
      t('Administration Staff ID', 'የአስተዳደር ሰራተኛ መለያ', 'ID Hojjettaa Bulchiinsaa');
  String get lookupTeacher => t(
        'Look up Administration Staff',
        'የአስተዳደር ሰራተኛ ፈልግ',
        'Hojjettaa Bulchiinsaa Barbaadi',
      );
  String get teacherProfile => t(
        'Administration Staff Profile',
        'የአስተዳደር ሰራተኛ መረጃ',
        'Ibsa Hojjettaa Bulchiinsaa',
      );
  String get teacherFound => t(
        'Administration staff found',
        'የአስተዳደር ሰራተኛ ተገኝቷል',
        'Hojjettaan bulchiinsaa argameera',
      );
  String get teacherNotFound => t(
        'Administration staff not found',
        'የአስተዳደር ሰራተኛ አልተገኘም',
        'Hojjettaan bulchiinsaa hin argamne',
      );
  String get subject => t('Subject', 'ትምህርት');
  String get assignedClass => t('Assigned Class', 'የተመደበ ክፍል');
  String get enterTeacherId => t(
        'Enter a valid Administration Staff ID from admin records',
        'ከአስተዳዳሪ መዝገብ ትክክለኛ የአስተዳደር ሰራተኛ መለያ ያስገቡ',
        'ID Hojjettaa Bulchiinsaa sirrii galmee bulchaa irraa galchi',
      );
  String get adminId => t('Admin ID', 'የአስተዳዳሪ መለያ');
  String get lookupAdmin => t('Look up Admin', 'አስተዳዳሪ ፈልግ');
  String get adminProfile => t('Admin Profile', 'የአስተዳዳሪ መረጃ');
  String get adminFound => t('Admin found', 'አስተዳዳሪ ተገኝቷል');
  String get adminNotFound => t('Admin not found', 'አስተዳዳሪ አልተገኘም');
  String get enterAdminId => t('Enter a valid Admin ID from admin records', 'ትክክለኛ የአስተዳዳሪ መለያ ያስገቡ');
  String get position => t('Position', 'የስራ መደብ');
  String get department => t('Department', 'መምሪያ');
  String get driverId => t('Transport ID', 'የትራንስፖርት መለያ');
  String get lookupDriver => t('Look up Transport Staff', 'ትራንስፖርት ፈልግ');
  String get driverProfile => t('Transport Profile', 'የትራንስፖርት መረጃ');
  String get driverFound => t('Transport staff found', 'ትራንስፖርት ተገኝቷል');
  String get driverNotFound => t('Transport staff not found', 'ትራንስፖርት አልተገኘም');
  String get enterDriverId => t('Enter a valid Transport ID from admin records', 'ትክክለኛ የትራንስፖርት መለያ ያስገቡ');
  String get busNumber => t('Bus', 'አውቶቡስ');
  String get routeName => t('Route', 'መስመር');
  String get plateNumber => t('Plate Number', 'ታርጋ');
  String get termsTitle => t('Terms & Agreement', 'ውሎች እና ግዴታ');
  String get iAgree => t('I Agree', 'እስማማለሁ');
  String get cancel => t('Cancel', 'ሰርዝ');
  String get termsCheckbox => t('I have read and agree to the terms and privacy policy', 'ውሎቹን እና የግል መረጃ ፖሊሲውን አንብቤ እስማማለሁ');
  String get parentTermsCheckbox => t(
        'I have read and agree to the Parent/Guardian Rules and Regulations',
        'የወላጅ/አሳዳጊ ደንቦች እና መመሪያዎችን አንብቤ እስማማለሁ',
      );
  String get mustAgreeTerms => t('Please agree to the terms to continue', 'ለመቀጠል ይስማሩ');
  String get parentGuardianAgreementTitle => t(
        'Parent/Guardian Rules and Regulations',
        'የወላጅ/አሳዳጊ ደንቦች እና መመሪያዎች',
      );
  String get parentGuardianRulesAndRegulations =>
      ParentGuardianTerms.bodyFor(languageCode);

  String termsForRole(String roleKey) {
    if (isAmharic) {
      switch (roleKey) {
        case 'parent':
          return parentGuardianRulesAndRegulations;
        case 'teacher':
          return '''የተምህርት ቤቱን ግዴታዎች፣ ግል መረጃ ፖሊሲ እና የትምህርት ቤት ደንቦች እስማማለሁ።

• ተማሪዎችን በአክብሮት፣ በፍትሃዊነት እና በሙያዊ መስፈርት አስገራለሁ።
• መገኘት፣ ደረጃዎች እና የክፍል መረጃዎችን በትክክል እመዘገባለሁ።
• የተማሪ መረጃን ሚስጥራዊ አድርጄ አያጋራም።
• የትምህርት ቤቱን ደንቦች፣ ጊዜ ሰሌዳ እና የመምህር ግዴታዎችን እከተላለሁ።''';
        case 'admin':
          return '''የተምህርት ቤቱን ግዴታዎች፣ ግል መረጃ ፖሊሲ እና የትምህርት ቤት ደንቦች እስማማለሁ።

• የትምህርት ቤቱን ደንቦች፣ ፖሊሲዎች እና መመሪያዎች በኃላፊነት እመራለሁ።
• የተማሪ፣ የመምህር እና የሰራተኛ መረጃን በደህንነት እጠብቃለሁ።
• ፍትሃዊነት፣ ግልፅነት እና ተገቢ አገልግሎት እሰጣለሁ።
• የትምህርት ቤቱን መልካም ስም እና ደንብ እጠብቃለሁ።''';
        case 'driver':
          return '''የተምህርት ቤቱን ግዴታዎች፣ ግል መረጃ ፖሊሲ እና የትምህርት ቤት ደንቦች እስማማለሁ።

• ተማሪዎችን በደህንነት ወደ ትምህርት ቤት እና ተመልሰው አጓጓዝ እሰራለሁ።
• የመኪና ደህንነት፣ ጊዜ ሰሌዳ እና መንገድ ደንቦችን እከተላለሁ።
• QR መዝገብ እና pick-up/drop-off ሂደቶችን በትክክል እከናወናለሁ።
• ተማሪዎችን በአክብሮት እና በጥንቃቄ አገልግላለሁ።''';
        default:
          return '';
      }
    }
    if (isOromo) {
      switch (roleKey) {
        case 'parent':
          return '''Haala tajaajilaa, imaammata dhuunfaa fi seera mana barumsaa Maya nan fudhadha.

• Barnoota, argama fi nageenya ijoollee koo irratti itti gaafatama nan fudhadha.
• Odeeffannoo sirrii fi haarawa nan kenna.
• Beeksisa, kaffaltii fi qunnamtii maatii-barsiisaa hordofa.
• Odeeffannoon ijoollee koo nageenyaan akka tajaajilu nan eeyyama.''';
        case 'teacher':
          return '''Haala tajaajilaa, imaammata dhuunfaa fi seera mana barumsaa Maya nan fudhadha.

• Barattoota kabaja, haqaa fi sadarkaa ogummaa qabuun nan barsiisa.
• Argama, qabxii fi odeeffannoo kutaa sirriitti nan galchaa.
• Odeeffannoo barataa iccitii ta'ee nan eega, hin qoodu.
• Seera, sagantaa fi koodii barsiisaa mana barumsaa nan hordofa.''';
        case 'admin':
          return '''Haala tajaajilaa, imaammata dhuunfaa fi seera mana barumsaa Maya nan fudhadha.

• Seera, galmeewwan fi hojii mana barumsaa itti gaafatamummaadhaan nan bulcha.
• Odeeffannoo barataa, hojjettootaa fi maatii nageenyaan nan eega.
• Haqaa, iftoomina fi tajaajila sirrii nan kenna.
• Maqaa fi seera mana barumsaa nan eega.''';
        case 'driver':
          return '''Haala tajaajilaa, imaammata dhuunfaa fi seera mana barumsaa Maya nan fudhadha.

• Barattoota karaa koo irratti nagaan geejjibaa nan hojjeta.
• Seera daandii, nageenya konkolaataa fi sagantaa nan hordofa.
• QR fi fudhachuu/gadi buusuu sirriitti nan galchaa.
• Barattoota kabaja fi eeggannoodhaan nan tajaajila.''';
        default:
          return '';
      }
    }

    switch (roleKey) {
      case 'parent':
        return parentGuardianRulesAndRegulations;
      case 'teacher':
        return '''I agree to Maya School's Terms of Service, Privacy Policy, and School Discipline rules.

• I will teach students with respect, fairness, and professional standards.
• I will record attendance, grades, and class information accurately.
• I will keep student information confidential and never misuse it.
• I will follow the school schedule, policies, and teacher code of conduct.''';
      case 'admin':
        return '''I agree to Maya School's Terms of Service, Privacy Policy, and School Discipline rules.

• I will manage school policies, records, and operations responsibly.
• I will protect student, staff, and parent data with strict confidentiality.
• I will act with fairness, transparency, and proper authority.
• I will uphold the school's discipline standards and good reputation.''';
      case 'driver':
        return '''I agree to Maya School's Terms of Service, Privacy Policy, and School Discipline rules.

• I will transport students safely to and from school on my assigned route.
• I will follow traffic laws, bus safety rules, and the school schedule.
• I will record pick-up/drop-off and QR scans accurately.
• I will treat every student with care, respect, and responsibility.''';
      default:
        return '';
    }
  }

  String get fillReport => t('Please fill all fields', 'ሁሉንም መስኮች ይሙሉ');
  String get invalidCredentials =>
      t('Invalid credentials ❌', 'መለያ ስህተት ❌');
  String get enterUsernamePassword => t('Please enter username and password', 'ስም እና የይለፍ ቃል ያስገቡ');
  String get useUsernameForRole => t('Use the correct username for this role', 'ለዚህ ሚና ትክክለኛውን ተጠቃሚ ስም ይጠቀሙ');

  // —— Dashboard & navigation ——
  String get profile => t('Profile', 'መገለጫ');
  String get settings => t('Settings', 'ቅንብሮች');
  String get logout => t('Logout', 'ውጣ');
  String get signInManually => t('Sign in manually', 'በእጅ ግባ (መለያ/ይለፍ ቃል)');
  String get notifications => t('Notifications', 'ማሳወቂያዎች');
  String get markAllRead => t('Mark all read', 'ሁሉንም እንደተነበበ ምልክት');
  String get noNotificationsYet =>
      t('No notifications yet', 'እስካሁን ማሳወቂያ የለም');
  String get welcome => t('Welcome', 'እንኳን ደህና መጡ');

  String schoolName(String? schoolId) {
    final id = schoolId?.trim().toUpperCase();
    if (isAmharic) {
      if (id == 'MAYA') return 'ማያ ትምህርት ቤት አስተዳደር';
      if (id == 'TB-001' || id == 'MS-001') return 'ማያ ትምህርት ቤት';
      return 'ማያ ትምህርት ቤት አስተዳደር';
    }
    if (isOromo) {
      if (id == 'MAYA') return 'Bulchiinsa Mana Barumsaa Maya';
      if (id == 'TB-001' || id == 'MS-001') return 'Mana Barumsaa Maya';
      return 'Bulchiinsa Mana Barumsaa Maya';
    }
    return SchoolRegistryService.instance.displayName(schoolId);
  }

  String teacherPortalTitle(String school) =>
      t('$school Classroom', '$school ክፍል');
  String staffPortalTitle(String school) => t(
        '$school Staff Portal',
        '$school · ሰራተኛ',
        '$school · Hojjettaa',
      );
  String parentPortalTitle(String school) =>
      t('$school Parent Portal', '$school · ወላጅ');
  String adminPortalTitle(String school) =>
      t('$school Admin Panel', '$school · አስተዳደር');
  String driverPortalTitle(String school) =>
      t('$school Transport Portal', '$school · ትራንስፖርት');
  String studentPortalTitle(String school) =>
      t('$school Student Portal', '$school · ተማሪ');

  String dashboardTitle(String id, {String? roleKey}) {
    if (roleKey == 'student' && id == 'homework') {
      return studentHomeworkAssignmentsTitle;
    }
    if (isAmharic) {
      if (roleKey == 'admin' && id == 'classes') return 'ክፍሎች';
      if (roleKey == 'admin' && id == 'attendance') return 'የመገኘት ሪፖርት';
      return switch (id) {
        'classes' => 'ክፍሎቼ',
        'attendance' => 'መገኘት',
        'messages' => 'መልዕክቶች',
        'announcements' => 'ማስታወቂያዎች',
        'homework' => 'የቤት ስራ',
        'learning_materials' => 'መጽሐፍትና መማሪያ መረጃ',
        'gallery' => 'ጋለሪ',
        'grades' => 'የደረጃ ሪፖርት',
        'qr' => 'QR መግቢያ/መውጫ',
        'calendar' => 'ቀን መቁጠሪያ',
        'timetable' => 'የጊዜ ሰሌዳ',
        'settings' => 'ቅንብሮች',
        'children' => 'ልጆቼ',
        'fees' => 'ክፍያዎች',
        'bus' => 'አውቶቡስ መከታተል',
        'students' => 'ተማሪዎች',
        'staff' => 'የአስተዳደር ሰራተኞች',
        'finance' => 'ፋይናንስ',
        'transport' => 'ትራንስፖርት',
        'route' => 'መስመሬ',
        'passengers' => 'ተሳፋሪዎች',
        'scan' => 'QR ስካን',
        'pickup' => 'መውሰድ / መተው',
        'issue' => 'ጉዳይ ሪፖርት',
        'map' => 'ቀጥታ ካርታ',
        'add_teacher' => 'የአስተዳደር ሰራተኛ ጨምር',
        'add_student' => 'ተማሪ ጨምር',
        'parent_approvals' => 'የወላጅ ጥያቄዎች',
        'transfer' => 'አዛወር',
        'campus' => 'ካምፐስ',
        'inventory' => 'እቃ መጋዘን',
        'library' => 'ቤተ መጻሕፍት',
        'learning_materials_admin' => 'የመማሪያ ቁሳቁስ አስተዳደር',
        'buses' => 'አውቶቡሶች',
        'reports' => 'ሪፖርቶች',
        'audit_log' => 'የኦዲት መዝገብ',
        'system_health' => 'የስርዓት ጤንነት',
        'student_affairs' =>
          roleKey == 'parent' ? 'ጠባይ እና ፈቃድ' : 'የተማሪ ጉዳዮች',
        'quality_assurance' => 'ጥራት ማረጋገጫ',
        'maya_assistant' => 'ማያ ረዳት',
        _ => id,
      };
    }
    if (isOromo) {
      if (roleKey == 'admin' && id == 'classes') return 'Kutaalee';
      if (roleKey == 'admin' && id == 'attendance') return 'Gabaasa Argamaa';
      return switch (id) {
        'classes' => 'Kutaalee Koo',
        'attendance' => 'Argama',
        'messages' => 'Ergaawwan',
        'announcements' => 'Beeksisa',
        'homework' => 'Hojii Manaa',
        'learning_materials' => 'Kitaabota fi Meeshaalee Barnootaa',
        'gallery' => 'Galarii',
        'grades' => 'Gabaasa Qabxii',
        'qr' => 'Seensa/Ba\'i QR',
        'calendar' => 'Kaaleendarii',
        'timetable' => 'Sagantaa Yeroo',
        'settings' => 'Qindaa\'inoota',
        'children' => 'Ijoollee Koo',
        'fees' => 'Kaffaltii',
        'bus' => 'Hordoffii Konkolaataa',
        'students' => 'Barattoota',
        'staff' => 'Hojjettoota Bulchiinsaa',
        'finance' => 'Faayinaansii',
        'transport' => 'Geejjiba',
        'route' => 'Karaa Koo',
        'passengers' => 'Fayyadamtoota',
        'scan' => 'QR Iskaanii',
        'pickup' => 'Fudhachuu / Gadi Buusuu',
        'issue' => 'Gabaasa Rakkoo',
        'map' => 'Kaartaa Kallattii',
        'add_teacher' => 'Hojjettaa Bulchiinsaa Dabaluu',
        'add_student' => 'Barataa Dabaluu',
        'parent_approvals' => 'Mirkaneessa Maatii',
        'transfer' => 'Dabarsuu',
        'campus' => 'Kaampasii',
        'inventory' => 'Kuusaa Meeshaa',
        'library' => 'Mana Kitaabaa',
        'learning_materials_admin' => 'Bulchiinsa Meeshaalee Barnootaa',
        'buses' => 'Autobusoota',
        'reports' => 'Gabaasawwan',
        'audit_log' => 'Galmee To\'annoo',
        'system_health' => 'Fayyaa Sirnaa',
        'student_affairs' =>
          roleKey == 'parent' ? 'Amala fi Hayyama' : 'Dhimma Barattootaa',
        'quality_assurance' => 'Mirkaneessa Qulqullina',
        'maya_assistant' => 'Gargaaraa Maya',
        _ => id,
      };
    }
    if (roleKey == 'admin' && id == 'classes') return 'Classes';
    if (roleKey == 'admin' && id == 'attendance') return 'Attendance Reports';
    return switch (id) {
      'classes' => 'My Classes',
      'attendance' => 'Attendance',
      'messages' => 'Messages',
      'announcements' => 'Announcements',
      'homework' => 'Homework',
      'learning_materials' => 'e-Book and Material',
      'gallery' => 'Gallery',
      'grades' => 'Grade Reports',
      'qr' => 'QR Entry/Exit',
      'calendar' => 'Calendar',
      'timetable' => 'Timetable',
      'settings' => 'Settings',
      'children' => 'My Children',
      'fees' => 'Fees & Payments',
      'bus' => 'Bus Tracking',
      'students' => 'Students',
      'staff' => 'Administration Staff',
      'finance' => 'Finance',
      'transport' => 'Transport',
      'route' => 'My Route',
      'passengers' => 'Passenger List',
      'scan' => 'Scan QR',
      'pickup' => 'Pick-up / Drop-off',
      'issue' => 'Report Issue',
      'map' => 'Live Map',
      'add_teacher' => 'Add Administration Staff',
      'add_student' => 'Add Student',
      'parent_approvals' => 'Parent Approvals',
      'transfer' => 'Transfer',
      'campus' => 'Campus',
      'inventory' => 'Inventory',
      'library' => 'Library',
      'learning_materials_admin' => 'e-Book and Material',
      'buses' => 'Buses',
      'reports' => 'Reports',
      'audit_log' => 'Audit Log',
      'system_health' => 'System Health',
      'student_affairs' =>
        roleKey == 'parent' ? 'Behaviour & Leave' : 'Student Affairs',
      'quality_assurance' => 'Quality Assurance',
      'grade_approvals' => 'Grade approvals',
      'grade_workflow_settings' => 'Grade workflow',
      'profile' => 'My Profile',
      'student_portal_settings' => 'Student Portal',
      'student_password_resets' => 'Password Requests',
      'maya_assistant' => 'Maya Assistant',
      _ => id,
    };
  }

  String get mayaAssistantHint => t(
        'Ask Maya anything…',
        'ማያን ማንኛውንም ጠይቁ…',
        'Maya gaafadhu…',
      );
  String get mayaAssistantThinking => t(
        'Maya is thinking…',
        'ማያ እያሰበች ነው…',
        'Maya yaadaa jirti…',
      );
  String get mayaAssistantClear => t(
        'Clear chat',
        'ውይይት አጽዳ',
        'Haasaa qulqulleessi',
      );

  String get dashboardLayoutSaved => t('Dashboard layout saved', 'የዳሽቦርድ አቀማመጥ ተቀምጧል');
  String get dashboardLayout => t('Dashboard Layout', 'የዳሽቦርድ አቀማመጥ');
  String get dragToReorder => t('Drag to rearrange buttons on your home screen.', 'በመነሻ ስክሪን ላይ ቁልፎችን ለማደራጀት ይጎትቱ።');
  String get resetLayout => t('Reset Layout', 'አቀማመጥ ዳግም አስጀምር');
  String get saveLayout => t('Save Layout', 'አቀማመጥ አስቀምጥ');
  String get preferences => t('Preferences', 'ምርጫዎች');
  String get appSecurity => t('App security', 'የመተግበሪያ ጥበቃ');
  String get biometricSectionTitle =>
      t('Face ID / fingerprint', 'Face ID / ጣት አሻራ');
  String get biometricOnOpenTitle => t('Ask when opening the app', 'መተግበሪያ ሲከፈት ጠይቅ');
  String get biometricOnOpenHint => t('Every time you return to Maya School, use Face ID or fingerprint for quick entry.', 'ከሌላ መተግበሪያ ተመለስ ሲያደርጉ በየጊዜው Face ID ወይም ጣት አሻራ ይጠይቃል (ቀላል መግቢያ)።');
  String get backgroundLockSectionTitle =>
      t('Lock in background', 'በበስተጀርባ ሲሄድ ይከለሳል');
  String get backgroundLockSectionHint => t(
        'Leaving the app (e.g. home button) signs you out after the selected time if you do not return.',
        'መተግበሪያውን ከተው (ለምሳሌ home) እና በተመረጠው ጊዜ ውስጥ ካልተመለሱ ይወጡ ወደ መግቢያ ገጽ።',
      );
  String get biometricsUnavailable => t('Face ID or fingerprint is not available on this device', 'በዚህ መሣሪያ ላይ Face ID ወይም ጣት አሻራ አልተገኘም');
  String get enableBiometricLock =>
      t('Face ID / fingerprint lock', 'Face ID / ጣት አሻራ ጠብቅ');
  String get enableBiometricLockHint => t('Require biometrics to open the app after idle time', 'መተግበሪያውን ለመክፈት ባዮሜትሪክ ይጠይቁ');
  String get autoLockAfter =>
      t('Background lock after', 'በበስተጀርባ ሲሄድ 잠금 ከ');
  String get autoLockNever => t('Never', 'በፈፅሞ አይዝጋ');
  String autoLockMinutes(int minutes) => t('$minutes min', '$minutes ደቂቃ');
  String get autoLockAfterHint => t(
        'Logs out when the app is in the background or unused for this long.',
        'መተግበሪያው በበስተጀርባ ሲሄድ ወይም ካልተጠቀሙ በኋላ ይውጣል።',
        'Yeroo appiin duuba deemuu ykn kan hin fayyadamne booda ba\'u danda\'a.',
      );
  String get appLocked =>
      t('Maya School is locked', 'Maya School ተጠብቋል');
  String get appLockedHint => t('Sign in again with your School ID and password', 'School ID እና የይለፍ ቃልዎን እንደገና ያስገቡ');
  String get unlockWithFaceId =>
      t('Unlock with Face ID', 'Face ID በመጠቀም ክፈት');
  String get unlockWithFingerprint =>
      t('Unlock with fingerprint', 'ጣት አሻራ በመጠቀም ክፈት');
  String get unlockWithBiometrics =>
      t('Unlock with biometrics', 'ባዮሜትሪክ በመጠቀም ክፈት');
  String get biometricUnlockReason => t('Unlock Maya School', 'Maya School መክፈት');
  String get biometricEnableFailed => t('Could not enable biometrics', 'ባዮሜትሪክ ማንቃት አልተሳካም');
  String get compactDashboard => t('Compact dashboard', 'ኮምፓክት ዳሽቦርድ');
  String get compactDashboardHint =>
      t('Show more buttons per row', 'በصف ላይ ተጨማሪ ቁልፎች');
  String get ethiopianHolidays =>
      t('Ethiopian holidays on calendar', 'የኢትዮጵያ በዓላት በቀን መቁጠሪያ');
  String get ethiopianHolidaysHint => t('Show national holidays in school calendar', 'ብሔራዊ በዓላትን በትምህርት ቤት ቀን መቁጠሪያ ላይ አሳይ');
  String get notificationSounds =>
      t('Notification sounds', 'የማሳወቂያ ድምፆች');
  String get notificationSoundsHint =>
      t('Play a sound for new alerts', 'ለአዲስ ማሳወቂያዎች ድምፅ አጫውት');
  String get highlightNotifications =>
      t('Highlight new notifications', 'አዲስ ማሳወቂያዎችን አጉል');
  String get highlightNotificationsHint => t('Show badge counts on Messages and bell icon', 'በመልዕክቶች እና በደንደን ላይ ቁጥር አሳይ');
  String get settingsLanguageHint => t(
        'Choose your preferred language — selection animates smoothly',
        'የሚፈልጉትን ቋንቋ ይምረጡ',
      );
  String get settingsPreferencesHint => t(
        'Personalize how the app looks and behaves',
        'መተግበሪያው እንዴት እንደሚታይ እና እንደሚሰራ ያስተካክሉ',
      );
  String get settingsHapticFeedback => t('Haptic feedback', 'የንዝረት ግብረ መልስ');
  String get settingsHapticFeedbackHint => t(
        'Light vibration when toggling switches',
        'መቀያየሪያዎችን ሲቀይሩ ቀላል ንዝረት',
      );
  String get settingsAboutApp => t('About the app', 'ስለ መተግበሪያው');
  String get settingsAboutAppHint => t(
        'Version, updates, and app information',
        'ስሪት፣ ማዘመኛዎች እና መረጃ',
      );
  String get settingsAboutDescription => t(
        'Maya Edu connects parents, teachers, and school staff with attendance, grades, homework, messaging, and transport — all in one place.',
        'Maya Edu ወላጆችን፣ መምህራንን እና የትምህርት ቤት ሰራተኞችን በአንድ ቦታ ያገናኛል።',
      );
  String get settingsAppVersion => t('Version', 'ስሪት');
  String get settingsBuild => t('Build', 'Build');
  String get settingsSupportEmail => t('Support email', 'የድጋፍ ኢሜይል');
  String get settingsEmailCopied => t('Support email copied', 'የድጋፍ ኢሜይል ተገልብጧል');
  String settingsAppVersionLabel(String version) =>
      t('Version $version', 'ስሪት $version');
  String get settingsHelpSupport => t('Help & support', 'እገዛ እና ድጋፍ');
  String get settingsHelpSupportHint => t(
        'FAQs, contact, and legal information',
        'ተደጋጋሚ ጥያቄዎች፣ አግኙን እና ህጋዊ መረጃ',
      );
  String get settingsAppearance => t('Appearance', 'መልክ');
  String get settingsAppearanceHint => t(
        'Day and night display options',
        'የቀን እና የሌሊት ማሳያ አማራጮች',
      );
  String get settingsDarkMode => t('Night mode', 'የሌሊት ሁነታ');
  String get settingsDarkModeHint => t(
        'Use a darker theme across the app. Turn off for day mode.',
        'በመላው መተግበሪያ ውስጥ ጨለማ ገጽታ ይጠቀሙ። ለቀን ሁነታ ያጥፉ።',
      );
  String get settingsLightModeHint => t(
        'Day mode — bright light theme',
        'የቀን ሁነታ — ብሩህ ገጽታ',
      );
  String get settingsFaqs => t('FAQs', 'ተደጋጋሚ ጥያቄዎች');
  String get settingsFaqsHint => t(
        'Quick answers to common questions',
        'ለተለመዱ ጥያቄዎች ፈጣን መልሶች',
      );
  String get settingsContactSupport => t('Contact support', 'ድጋፍ ያግኙ');
  String get settingsContactSchoolAdmin => t(
        'Contact school admin',
        'የትምህርት ቤት አስተዳዳሪ ያግኙ',
      );
  String get settingsContactSchoolAdminHint => t(
        'Call or email your school administrator for help with the app, students, or account issues.',
        'ለመተግበሪያ፣ ተማሪ ወይም መለያ ጥያቄዎች የትምህርት ቤት አስተዳዳሪዎን ያግኙ።',
      );
  String get settingsSchoolAdminPhone => t(
        'School admin phone',
        'የአስተዳዳሪ ስልክ',
      );
  String get settingsSchoolAdminEmail => t(
        'School admin email',
        'የአስተዳዳሪ ኢሜይል',
      );
  String get settingsSchoolAdminUnavailable => t(
        'School admin contact is not on file yet. Ask your school office to update admin details.',
        'የአስተዳዳሪ ግንኙነት ገና አልተመዘገበም። ቢሮዎን ያግኙ።',
      );
  String get settingsPlatformSupportHint => t(
        'For Maya platform or billing issues',
        'ለMaya መድረክ ወይም የክፍያ ጥያቄዎች',
      );
  String get settingsPhoneCopied => t(
        'Admin phone copied',
        'የአስተዳዳሪ ስልክ ተገልብጧል',
      );
  String get settingsPrivacyPolicy => t('Privacy policy', 'የግላዊነት ፖሊሲ');
  String get settingsPrivacyPolicyHint => t(
        'How we handle your data',
        'መረጃዎን እንዴት እንደምንጠብም',
      );
  String get settingsTermsOfUse => t('Terms of use', 'የአጠቃቀም ውሎች');
  String get settingsTermsHint => t(
        'Rules for using Maya Edu',
        'Maya Edu የአጠቃቀም правила',
      );
  String get settingsOpeningSoon => t(
        'Opening in a future update',
        'በሚቀጥለው ማዘመን ውስጥ ይከፈታል',
      );
  String get settingsCheckUpdates => t('Check for updates', 'ማዘመን ይፈልጉ');
  String get settingsCheckUpdatesHint => t(
        'See if a newer version is available',
        'አዲስ ስሪት መኖሩን ይመልከቱ',
      );
  String get settingsUpToDate => t(
        'You are on the latest version',
        'በቅርቡ ስሪት ላይ ነዎት',
      );
  String get settingsClearCache => t('Clear cache', 'Cache አጽዳ');
  String get settingsClearCacheHint => t(
        'Free up temporary stored files',
        'ጊዜያዊ ፋይሎችን አስወግድ',
      );
  String get settingsCacheCleared => t('Cache cleared', 'Cache ተጸድቷል');
  String get settingsFaqLogin => t('How do I log in?', 'እንዴት እ-login ይላል?');
  String get settingsFaqLoginAnswer => t(
        'Use your School ID and password from your school admin. Parents and teachers receive credentials during enrollment.',
        'School ID እና የይለፍ ቃልዎን ይጠቀሙ።',
      );
  String get settingsFaqNotifications => t(
        'Why am I not getting notifications?',
        'ማሳወቂያዎች ለምን አልመጡም?',
      );
  String get settingsFaqNotificationsAnswer => t(
        'Check that push notifications are enabled in Settings, and that your phone allows alerts for Maya Edu in system settings.',
        'በSettings ውስጥ push notifications እንደተከፈቱ ያረጋግጡ።',
      );
  String get settingsFaqLanguage => t(
        'Can I change the language later?',
        'ቋንቋን በኋላ ልቀይረው እችላለሁ?',
      );
  String get settingsFaqLanguageAnswer => t(
        'Yes. Open Settings anytime and pick English, Amharic, or Afaan Oromo. Your choice is saved automatically.',
        'አዎ። Settings ከፍተው English፣ Amharic ወይም Afaan Oromo ይምረጡ።',
      );
  String get settingsFaqDashboard => t(
        'Can I rearrange my dashboard?',
        'ዳሽቦርድ ማደራጀት እችላለሁ?',
      );
  String get settingsFaqDashboardAnswer => t(
        'Yes. In Settings → Dashboard Layout, drag tiles to reorder them. Tap Save Layout when done.',
        'አዎ። Settings → Dashboard Layout ውስጥ መሳሪያዎችን ይጎትቱ።',
      );
  String get settingsFaqSupport => t(
        'Who do I contact for help?',
        'እገዛ ለማግኘት ማንን እያግኝ?',
      );
  String get settingsFaqSupportAnswer => t(
        'Contact your school administrator by phone or email from Settings → Help & support. Homeroom teachers can also help with student-specific questions.',
        'Settings → Help & support ውስጥ የትምህርት ቤት አስተዳዳሪዎን በስልክ ወይም ኢሜይል ያግኙ።',
      );
  String get pushNotificationsSection =>
      t('Push notifications', 'የግፅ ግፅ ማሳወቂያዎች');
  String get pushNotificationsSectionHint => t('Alerts reach you when the app is closed, the phone is locked, or you are using another app.', 'መተግበሪያው ተዘግቷል ወይም በበስተጀርባ ሲሄድም ማሳወቂያ ይደርስዎታል።');
  String get pushNotificationsMaster =>
      t('All push notifications', 'ሁሉም ግፅ ማሳወቂያዎች');
  String get pushNotificationsMasterHint => t('Master switch for every alert below', 'ሁሉንም የግፅ ማሳወቂያዎች በአንድ ጊዜ ያብሩ/ይዘጉ');
  String get notifyHomework => t('Homework', 'የቤት ሥራ');
  String get notifyHomeworkHint => t('When new homework is posted for your class or child', 'አዲስ የቤት ሥራ ሲቀርብ');
  String get notifyMessages => t('Messages', 'መልዕክቶች');
  String get notifyMessagesHint => t('From school, teachers, parents, or transport staff', 'ከትምህርት ቤት፣ መምህር፣ ወላጅ ወይም ትራንስፖርት');
  String get notifyTransport => t('Transport arrival', 'ትራንስፖርት');
  String get notifyTransportHint => t('When your child reaches school on the bus', 'ልጅዎ ትምህርት ቤት ሲደርስ');
  String get notifyAnnouncements => t('Announcements', 'ማስታወቂያዎች');
  String get notifyAnnouncementsHint => t('Important updates from the school', 'ከትምህርት ቤቱ አስፈላጊ ማስታወቂያዎች');
  String get notifyGrades => t('Grades & reports', 'ደረጃዎች');
  String get notifyGradesHint => t('New grades or report cards', 'አዲስ ደረጃ ወይም የሪፖርት ካርድ');
  String get notifyAttendance => t('Attendance', 'መገኘት');
  String get notifyAttendanceHint => t('When attendance is recorded', 'የተማሪ መገኘት ተመዝግቧል');
  String get notifyGallery => t('Gallery', 'ጋለሪ');
  String get notifyGalleryHint => t('New class photos are shared', 'አዲስ ፎቶዎች ተጋራ');
  String get notifyDailyActivity =>
      t('Daily activities', 'የቀን እንቅስቃሴ');
  String get notifyDailyActivityHint => t('Daily class or child activity reports', 'የቀን የክፍል/ልጅ ሪፖርት');
  String get notifyFees => t('Fees', 'ክፍያዎች');
  String get notifyFeesHint => t('Fee reminders and payment confirmations', 'ክፍያ መጠየቂያ ወይም የክፍያ ማረጋገጫ');
  String get notifyCalendar => t('Calendar', 'ቀን መቁጠሪያ');
  String get notifyCalendarHint => t(
        'School events, holidays, and schedule reminders',
        'የትምህርት ቤት ክስተቶች፣ በዓላት እና የጊዜ ሰንጠረዥ ማስታወሻዎች',
      );
  String get changeLanguage => t('Change Language', 'ቋንቋ ቀይር');

  // —— Screen titles ——
  String get myClasses => t('My Classes', 'ክፍሎቼ');
  String get noClassesAssigned =>
      t('No classes assigned', 'ምንም ክፍል አልተመደበም');
  String get gradesBtn => t('Grades', 'ደረጃዎች');
  String get dailyActivities => t('Daily Activities', 'ዕለታዊ እንቅስቃሴ');
  String get messageParent => t('Message Parent', 'ወላጅ መልእክት');
  String messageTo(String name) =>
      t('Message $name', 'ለ$name መልእክት');
  String get parentLabel => t('Parent', 'ወላጅ');
  String get schoolCalendar => t('School Calendar', 'የትምህርት ቤት ቀን መቁጠሪያ');
  String get scheduleEvent => t('Schedule Event', 'ክስተት ያስቀምጡ');
  String get editEvent => t('Edit Event', 'ክስተት አርትዕ', 'Taatee gulaali');
  String get pickDate => t('Pick', 'ቀን ይምረጡ');
  String get eventScheduled => t('Event scheduled — parents will be notified on the day', 'ክስተት ተያዘ — በዚያ ቀን ወላጆች ይነገራሉ');
  String get eventUpdated => t('Event updated', 'ክስተት ተዘምኗል', 'Taateen haaromfameera');
  String get eventDeleted => t('Event deleted', 'ክስተት ተሰርዟል', 'Taateen haqameera');
  String get allDayEvent => t('All day (tap to set time)', 'ሙሉ ቀን (ሰዓት ለማስቀመጥ ነካ)', 'Guyyaa guutuu (yeroo filadhu)');
  String get clearEventTime => t('Clear time (all day)', 'ሰዓት አጽዳ (ሙሉ ቀን)', 'Yeroo haqi (guyyaa guutuu)');
  String get addToDeviceCalendar =>
      t('Add to phone calendar', 'ወደ ስልክ ቀን መቁጠሪያ ጨምር', 'Kaaleendarii bilbilaa irratti dabali');
  String get addToDeviceCalendarHint => t(
        'Opens Google/Apple Calendar so you can save this school event',
        'ይህን የትምህርት ቤት ክስተት ለማስቀመጥ የGoogle/Apple ቀን መቁጠሪያ ይከፍታል',
        'Taatee mana barumsaa kuusuuuf kaaleendarrii Google/Apple bana',
      );
  String get syncDeviceCalendar =>
      t('Sync new events to phone calendar', 'አዲስ ክስተቶችን ወደ ስልክ ቀን መቁጠሪያ አስምር');
  String get syncDeviceCalendarHint => t(
        'When you schedule a school event, offer to add it to Google or Apple Calendar',
        'የትምህርት ቤት ክስተት ሲያስቀምጡ ወደ Google ወይም Apple ቀን መቁጠሪያ ለመጨመር ይጠይቃል',
      );
  String get deleteEventConfirm =>
      t('Delete this event?', 'ይህ ክስተት ይሰረዝ?', 'Taatee kana haqi?');
  String calendarEventTypeLabel(String type) {
    return switch (type) {
      'exam' => t('Exam', 'ፈተና', 'Qormaata'),
      'holiday' => holiday,
      'meeting' => t('Meeting', 'ስብሰባ', 'Walgahii'),
      'sports' => t('Sports', 'ስፖርት', 'Ispoortii'),
      'classEvent' => t('Class event', 'የክፍል ክስተት', 'Taatee kutaa'),
      _ => t('Other', 'ሌላ', 'Kan biroo'),
    };
  }
  String get audience => t('Audience', 'ታዳሚ');
  String get timeLabel => t('Time', 'ሰዓት');
  String get addToGallery => t('Add to Gallery', 'ወደ ጋለሪ ጨምር');
  String get photo => t('Photo', 'ፎቶ');
  String get video => t('Video', 'ቪዲዮ');
  String get note => t('Note', 'ማስታወሻ');
  String get upload => t('Upload', 'ስቀል');
  String get addPost => t('Add Post', 'ልጥፍ ጨምር');
  String get noGalleryPosts =>
      t('No gallery posts yet', 'ጋለሪ ልጥፎች የሉም');
  String get galleryPosted => t('Posted — parents in this class can view it', 'ተለጠፈ — ወላጆች ሊያዩት ይችላሉ');
  String get share => t('Share', 'አጋራ');
  String get download => t('Download', 'አውርድ');
  String attachmentDownloaded(String file) =>
      t('Saved $file to Downloads', '$file ወደ Downloads ተቀምጧል');
  String get attachmentDownloadFailed => t(
        'Could not download this attachment',
        'attachments መውረድ አልተቻለም',
      );
  String get attachmentNotFound => t(
        'Attachment file not found on this device',
        'attachment በዚህ መሣሪያ ላይ አልተገኘም',
      );
  String get attachmentTapImageHint => t(
        'Tap a photo to open, then use Share or Download',
        'ፎቶ ለመክፈት ይንኩ — ከዚያ Share ወይም Download ይጠቀሙ',
      );
  String get open => t('Open', 'ክፈት');
  String get galleryDownloadFailed => t(
        'Could not download this photo or video',
        'ፎቶ ወይም ቪዲዮ መውረድ አልተቻለም',
      );
  String get gradeReports => t('Grade Reports', 'የደረጃ ሪፖርት');
  String get addSubject => t('Add Subject', 'ትምህርት ጨምር');
  String get noGradeReports =>
      t('No grade reports available', 'የደረጃ ሪፖርት የለም');
  String get noPublishedGradeReports => t(
        'No published grade reports yet. Teachers will post scores for your child here.',
        'እስካሁን የተለጠፈ የደረጃ ሪፖርት የለም። መምህሮች ውጤቶችን እዚህ ይለጥፋሉ።',
      );
  String get parentGradeReportsHint => t(
        'Showing grade reports your teachers published for your linked child only.',
        'ለተገናኘው ልጅዎ መምህሮች የለጥፉትን የደረጃ ሪፖርት ብቻ እያሳየ ነው።',
      );
  String get postGradeReport =>
      t('Post grade report', 'የደረጃ ሪፖርት ለጥፍ');
  String get gradeReportDraft => t('Draft', 'ረቂቅ');
  String get gradeReportPublished => t('Published', 'ተለጥፏል');
  String get publishToParents =>
      t('Publish to parents', 'ለወላጆች ለጥፍ');
  String get gradePublishedSuccess => t(
        'Grade report published — parents can now view it',
        'የደረጃ ሪፖርት ተለጥፏል — ወላጆች ሊያዩት ይችላሉ',
      );
  String get gradePublishFailed => t(
        'Could not publish grade report',
        'የደረጃ ሪፖርት ማተም አልተሳካም',
      );
  String get gradeApprovalsTitle =>
      t('Grade approvals', 'የደረጃ ማጽደቅ');
  String get noGradeApprovalsPending => t(
        'No grade submissions awaiting your review.',
        'ለመገምገም የሚጠብቁ የደረጃ ማስረከቢያዎች የሉም።',
      );
  String get approveGrades => t('Approve', 'አጽድቅ');
  String get rejectGrades => t('Reject', 'አትቀበል');
  String get requestGradeAdjustment =>
      t('Ask for adjustment', 'ማስተካከል ጠይቅ');
  String get approvalCommentOptional =>
      t('Comment (optional)', 'አስተያየት (አማራጭ)');
  String get rejectionReasonRequired =>
      t('Reason for rejection (required)', 'የመከልከያ ምክንያት (አስፈላጊ)');
  String get adjustmentReasonRequired =>
      t('Reason for adjustment (required)', 'የማስተካከያ ምክንያት (አስፈላጊ)');
  String gradeApprovalScoreLine(int score, int max, String letter) => t(
        'Score: $score/$max ($letter)',
        'ውጤት: $score/$max ($letter)',
      );
  String submittedByTeacher(String name) =>
      t('Submitted by $name', 'በ$name ቀርቧል');
  String gradeTeacherNoteLine(String comment) =>
      t('Teacher note: $comment', 'የመምህር ማስታወሻ: $comment');
  String gradeApprovalActionSuccess(String action) => switch (action) {
        'approve' => t('Grades approved and published', 'ደረጃዎች ጸድቀው ተለጥፈዋል'),
        'reject' => t('Grades rejected and returned to teacher', 'ደረጃዎች ተቀባይነት አላገኙም — ወደ መምህር ተመለሱ'),
        _ => t('Adjustment request sent to teacher', 'የማስተካከያ ጥያቄ ወደ መምህር ተላከ'),
      };
  String get gradeApprovalActionFailed => t(
        'Could not complete this action',
        'ድርጊቱ አልተሳካም',
      );
  String get gradeResubmitForApproval =>
      t('Resubmit for approval', 'እንደገና ለማጽደቅ አስረክብ');
  String get submitGradesForApproval =>
      t('Submit for approval', 'ለማጽደቅ አስረክብ');
  String get gradeReturnedForCorrection => t(
        'Returned for correction',
        'ለማስተካከል ተመልሷል',
      );
  String get gradeRejectedByAdmin => t(
        'Rejected by admin',
        'በአስተዳዳሪ ተቀባይነት አላገኘም',
      );
  String get gradePendingApprovalLabel =>
      t('Pending approval', 'ማጽደቅ በመጠባበቅ ላይ');
  String get gradeApprovedLockedLabel =>
      t('Approved and published', 'ጸድቆ ተለጥፏል');
  String get gradeResubmitHint => t(
        'Review the admin feedback, update the grade, then submit again.',
        'የአስተዳዳሪ ግብረመልስ ይመልከቱ፣ ደረጃውን ያስተካክሉ፣ ከዚያ እንደገና ያስረክቡ።',
      );
  String adminFeedbackLabel(String feedback) =>
      t('Admin feedback: $feedback', 'የአስተዳዳሪ ግብረመልስ: $feedback');
  String gradePublishedNotificationTitle(String subject, String studentName) =>
      t(
        'Grade posted — $subject ($studentName)',
        'ደረጃ ተለጥፏል — $subject ($studentName)',
      );
  String gradeUpdatedNotificationTitle(String subject, String studentName) =>
      t(
        'Grade updated — $subject ($studentName)',
        'ደረጃ ተዘምኗል — $subject ($studentName)',
      );
  String gradePublishedNotificationBody(
    String teacherName,
    String studentName,
    String subject,
    int score,
    String letter,
  ) =>
      t(
        '$teacherName posted $studentName\'s $subject score: $score ($letter). Tap to view.',
        '$teacherName የ$studentName $subject ውጤት $score ($letter) ለጥፏል። ለመመልከት ይጫኑ።',
      );
  String gradeUpdatedNotificationBody(
    String teacherName,
    String studentName,
    String subject,
    int score,
    String letter,
  ) =>
      t(
        '$teacherName updated $studentName\'s $subject score to $score ($letter).',
        '$teacherName የ$studentName $subject ውጤት ወደ $score ($letter) አዘምኗል።',
      );
  String get teacherGradeReportHint => t(
        'Create a grade report for your subject, then publish so parents can see it.',
        'ለትምህርትዎ የደረጃ ሪፖርት ይสรጡ፣ ወላጆች እንዲያዩት ከዚያ ይለጥፉት።',
      );
  String get editSubject => t('Edit', 'ትምህርት አርትዕ');
  String get addBtn => t('Add', 'ጨምር');
  String get save => t('Save', 'አስቀምጥ');
  String get noConversations =>
      t('No conversations yet', 'ውይይት የለም');
  String get myChildrenScreen => t('My Children', 'ልጆቼ');
  String get chooseChildSubtitle => t(
        'Tap a child to open their school hub',
        'የትምህርት ማዕከላቸውን ለመክፈት ልጅዎን ይምረጡ',
      );
  String get noLinkedChildren => t(
        'No linked children found',
        'ምንም የተያያዙ ልጆች አልተገኙም',
      );
  String childSummaryLine(String grade, String section, String teacher) => t(
        '$grade · Section $section · Homeroom $teacher',
        '$grade · ሴክሽን $section · የክፍል መምህር $teacher',
      );
  String sectionLabel(String section) =>
      t('Section $section', 'ሴክሽን $section');
  String homeroomTeacherOf(String teacher) =>
      t('Homeroom teacher · $teacher', 'የክፍል መምህር · $teacher');
  String get homeroomTeacherShort =>
      t('Homeroom', 'የክፍል መምህር');
  String get classRankLabel => t('Class rank', 'የክፍል ደረጃ');
  String rankNumber(int rank) => t('Rank #$rank', 'ደረጃ #$rank');
  String get childHubTools =>
      t('School tools', 'የትምህርት መሳሪያዎች');
  String get parentComposeTitle => t(
        'Message school staff',
        'የትምህርት ቤት ሰራተኞችን መልእክት',
      );
  String get parentComposeMessageHint => t(
        'Reach homeroom, subject teachers, or admin',
        'የክፍል መምህር፣ የትምህርት መምህራን ወይም አስተዳዳሪን ያግኙ',
      );
  String get parentMessagesSubtitle => t(
        'Chat with teachers and school staff',
        'ከመምህራን እና ከትምህርት ቤት ሰራተኞች ጋር ይወያዩ',
      );
  String get parentMessageRecipientLabel =>
      t('Send to', 'ላክ ወደ');
  String get parentMessageNoRecipient => t(
        'No recipient available for this selection',
        'ለዚህ ምርጫ ተቀባይ አልተገኘም',
      );
  String get chooseChildLabel => t('Child', 'ልጅ');
  String get noSubjectTeachersForClass => t(
        'No subject teachers listed for this class',
        'ለዚህ ክፍል የትምህርት መምህራን አልተመዘገቡም',
      );
  String get adminLabel => t('Admin', 'አስተዳዳሪ');
  String get schoolAdministration =>
      t('School administration', 'የትምህርት ቤት አስተዳደር');
  String get messageSendFailed => t(
        'Could not send message. Try again.',
        'መልዕክት መላክ አልተቻለም። እንደገና ይሞክሩ።',
      );
  String get parentFeesComingSoonSubtitle => t(
        'Online fee payments for parents',
        'ለወላጆች የኦንላይን ክፍያ',
      );
  String get parentFeesComingSoonDescription => t(
        'Pay school fees, view invoices, and track payment history — all from your phone.',
        'የትምህርት ክፍያዎችን ይክፈሉ፣ መጠየቂያዎችን ይመልከቱ እና የክፍያ ታሪክዎን ይከታተሉ።',
      );
  String get parentFeesComingSoonNote => t(
        'We are connecting secure payment providers. You will be notified when fees go live.',
        'ደህንነቱ የተጠበቀ የክፍያ አገልግሎት እያገናኘን ነው። ክፍያ ሲጀመር ይነገርዎታል።',
      );
  String homeworkForChild(String name) =>
      t('Homework for $name', 'የቤት ስራ ለ$name');
  String get homeworkTitle => t('Homework', 'የቤት ስራ');
  String get studentHomeworkAssignmentsTitle => t(
        'Homeworks and Assignments',
        'የቤት ስራዎች እና ተግባራት',
      );
  String get studentHomeworkScreenTitle => studentHomeworkAssignmentsTitle;
  String get teacherWorksheetLabel =>
      t('Teacher worksheets', 'የመምህር ወርክሺቶች');
  String get myWorksheetUploads =>
      t('My uploaded worksheets', 'የኔ የተላኩ ወርክሺቶች');
  String get uploadWorksheet => t('Upload worksheet', 'ወርክሺት ስቀል');
  String get worksheetUploadDisabled => t(
        'Worksheet uploads are disabled for your school.',
        'የወርክሺት ስቀል ለትምህርት ቤትዎ ተሰናክሏል።',
      );
  String get worksheetUploadedSuccess => t(
        'Worksheet uploaded successfully',
        'ወርክሺት በተሳካ ሁኔታ ተሰቅሏል',
      );
  String get booksAndLearningMaterialTitle => t(
        'Books and Learning Material',
        'መጽሐፍትና መማሪያ መረጃ',
      );
  String get addLearningMaterial =>
      t('Add material', 'መረጃ ጨምር', 'Meeshaa barnootaa dabaluu');
  String get editLearningMaterial =>
      t('Edit material', 'መረጃ አርትዕ', 'Meeshaa barnootaa gulaali');
  String get deleteLearningMaterial =>
      t('Delete material', 'መረጃ ሰርዝ', 'Meeshaa barnootaa haqi');
  String deleteLearningMaterialConfirm(String bookName) => t(
        'Remove "$bookName" from learning materials?',
        '"$bookName" ከመማሪያ መረጃ ይወገድ?',
        '"$bookName" meeshaalee barnootaa irraa haquu?',
      );
  String get bookNameLabel => t('Book name', 'የመጽሐፍ ስም', 'Maqaa kitaaba');
  String get materialNameLabel =>
      t('Material name', 'የመረጃ ስም', 'Maqaa meeshaa');
  String get pickLearningMaterialFile => t(
        'Pick a file to upload',
        'ለመስቀል ፋይል ይምረጡ',
        'Faayilii olkaa\'uuf fili',
      );
  String get replaceFile => t('Replace file', 'ፋይል ቀይር', 'Faayilii jijjiiri');
  String get learningMaterialFile =>
      t('File', 'ፋይል', 'Faayilii');
  String get learningMaterialUploaded => t(
        'Learning material uploaded',
        'መማሪያ መረጃ ተሰቅሏል',
        'Meeshaan barnootaa olkaa\'ame',
      );
  String get learningMaterialUpdated => t(
        'Learning material updated',
        'መማሪያ መረጃ ተዘምኗል',
        'Meeshaan barnootaa haaromfame',
      );
  String get learningMaterialDeleted => t(
        'Learning material removed',
        'መማሪያ መረጃ ተወግዷል',
        'Meeshaan barnootaa haqame',
      );
  String get noLearningMaterials => t(
        'No books or learning materials yet',
        'እስካሁን መጽሐፍት ወይም መማሪያ መረጃ የለም',
        'Ammaaf kitaabota ykn meeshaalee barnootaa hin jiran',
      );
  String get freeBadge => t('Free', 'ነፃ', 'Bilisa');
  String get paidBadge => t('Paid', 'ክፍያ ያለው', 'Kaffaltii qabu');
  String get paidMaterialToggle => t(
        'Paid material (locked until unlocked per student)',
        'ክፍያ ያለው መረጃ (ለእያንዳንዱ ተማሪ እስኪከፈት ድረስ ተቆልፏል)',
      );
  String get priceEtbLabel => t('Price (ETB)', 'ዋጋ (ብር)', 'Gatii (ETB)');
  String get lockedMaterialTitle =>
      t('Locked material', 'የተቆለፈ መረጃ', 'Meeshaa cufame');
  String get lockedMaterialHint => t(
        'This is a paid material. Ask your parent to approve and pay, or ask the school to unlock it.',
        'ይህ ክፍያ ያለው መረጃ ነው። ወላጅዎ እንዲያጸድቁና እንዲከፍሉ ይጠይቁ፣ ወይም ትምህርት ቤቱ እንዲከፍት ይጠይቁ።',
      );
  String get requestBookUnlock =>
      t('Request unlock', 'መክፈት ጠይቅ', 'Banamuu gaafadhu');
  String get buyBookUnlock =>
      t('Buy / Unlock', 'ግዛ / ክፈት', 'Bitadhu / Bani');
  String get bookRequestSentToast => t(
        'Request sent to your parent for approval',
        'ጥያቄው ለወላጅዎ ለማጽደቅ ተልኳል',
        'Gaaffiin haala mirkaneessuuuf maatiikeetti ergameera',
      );
  String get bookUnlockRequestsTitle => t(
        'Book unlock requests',
        'የመጽሐፍ መክፈቻ ጥያቄዎች',
        'Gaaffii banamuu kitaabaa',
      );
  String get bookPaymentsPendingTitle => t(
        'Book payments — pending school approval',
        'የመጽሐፍ ክፍያዎች — ከትምህርት ቤት ማጽደቅ በመጠባበቅ ላይ',
        'Kaffaltii kitaabaa — mirkaneessa mana barumsaa eegaa jira',
      );
  String get bookPaymentConfirmTitle => t(
        'Confirm book payments',
        'የመጽሐፍ ክፍያዎችን አረጋግጥ',
        'Kaffaltii kitaabaa mirkaneessi',
      );
  String get bookPaymentTitle =>
      t('Pay for book unlock', 'ለመጽሐፍ መክፈቻ ይክፈሉ', 'Banamuu kitaabaaf kaffali');
  String get bookPaymentAccountsHint => t(
        'Pay to one of these test accounts, then send the receipt',
        'ወደ ከእነዚህ የሙከራ ሂሳቦች ይክፈሉ፣ ከዚያ ደረሰኙን ይላኩ',
        'Akkaawuntii yaalii kana keessaa tokkotti kaffalaa, ergaa ragaa ergaa',
      );
  String get bookPaymentSendReceiptHint => t(
        'Send payment receipt via Telegram (@nabilmaya) or WhatsApp, then tap below.',
        'የክፍያ ደረሰኝ በቴሌግራም (@nabilmaya) ወይም በዋትስአፕ ይላኩ፣ ከዚያ ከታች ይጫኑ።',
        'Ragaa kaffaltii Telegram (@nabilmaya) ykn WhatsApp tiin ergaa, sana booda gadi tuqi.',
      );
  String get iSentReceipt => t(
        'I’ve sent the receipt',
        'ደረሰኙን ልኬአለሁ',
        'Ragaa ergeera',
      );
  String get bookPaymentSubmittedToast => t(
        'Receipt sent — pending approval from school',
        'ደረሰኝ ተልኳል — ከትምህርት ቤት ማጽደቅ በመጠባበቅ ላይ',
        'Ragaan ergameera — mirkaneessa mana barumsaa eegaa jira',
      );
  String get bookRequestRejectedToast =>
      t('Request rejected', 'ጥያቄው ተቀባይነት አላገኘም', 'Gaaffiin didame');
  String get bookUnlockedToast => t(
        'Unlocked — book released',
        'ተከፍቷል — መጽሐፉ ተለቋል',
        'Banameera — kitaabni hiikkameera',
      );
  String get approveAndPay =>
      t('Approve & pay', 'አጽድቅ እና ክፈል', 'Mirkaneessi fi kaffali');
  String get confirmPaymentUnlock => t(
        'Confirm & unlock',
        'አረጋግጥ እና ክፈት',
        'Mirkaneessi fi bani',
      );
  String get awaitingParentApproval => t(
        'Waiting for parent approval',
        'የወላጅ ማጽደቅ በመጠባበቅ ላይ',
        'Mirkaneessa maatii eegaa jira',
      );
  String get awaitingPayment =>
      t('Waiting for payment', 'ክፍያ በመጠባበቅ ላይ', 'Kaffaltii eegaa jira');
  String get paymentSubmittedStatus => t(
        'Pending approval from school',
        'ከትምህርት ቤት ማጽደቅ በመጠባበቅ ላይ',
        'Mirkaneessa mana barumsaa eegaa jira',
      );
  String get bookRequestPendingStatus =>
      t('Request pending', 'ጥያቄ በመጠባበቅ ላይ', 'Gaaffiin eegamaa jira');
  String get bookUnlockedTitle =>
      t('Unlocked', 'ተከፍቷል', 'Banameera');
  String get bookReleasedHint => t(
        'Book released',
        'መጽሐፉ ተለቋል',
        'Kitaabni hiikkameera',
      );
  String get manageAccess =>
      t('Manage access', 'መዳረሻ አስተዳድር', 'Seensa bulchi');
  String get unlockedForCount => t('unlocked', 'ተከፍቷል', 'banameera');
  String get studentAccessTitle =>
      t('Student access', 'የተማሪ መዳረሻ', 'Seensa barataa');
  String get noStudentsForClass => t(
        'No students found for this class',
        'ለዚህ ክፍል ተማሪዎች አልተገኙም',
        'Kutaa kanaaf barattoonni hin argamne',
      );
  String get materialAccessUpdated => t(
        'Access updated',
        'መዳረሻ ተዘምኗል',
        'Seensi haaromfame',
      );
  String get staffRolesTitle =>
      t('Staff Roles', 'የሰራተኛ ሚናዎች', 'Gahee Hojjettootaa');
  String get staffRolesSubtitle => t(
        'A staff member can hold several roles; their permissions combine. '
        'Changes take effect at their next sign-in.',
        'አንድ ሰራተኛ በርካታ ሚናዎችን መያዝ ይችላል፤ ፈቃዶቻቸው ይጣመራሉ። '
        'ለውጦች በሚቀጥለው መግቢያ ላይ ተግባራዊ ይሆናሉ።',
        'Hojjetaan tokko gahee hedduu qabaachuu danda\'a; hayyamni walitti '
        'makama. Jijjiiramni seensa itti aanutti hojiirra oola.',
      );
  String get staffRolesUpdated =>
      t('Roles updated', 'ሚናዎች ተዘምነዋል', 'Gaheewwan haaromfamaniiru');
  String get staffRolesOwnerOnly => t(
        'Only the school owner can grant Full Access',
        'ሙሉ መዳረሻ መስጠት የሚችለው የትምህርት ቤቱ ባለቤት ብቻ ነው',
        'Seensa Guutuu kennuu kan danda\'u abbaa mana barumsaa qofa',
      );
  String get staffRolesNoAccount => t(
        'This staff member has no login account yet',
        'ይህ ሰራተኛ እስካሁን የመግቢያ መለያ የለውም',
        'Hojjetaan kun ammatti akkaawuntii seensaa hin qabu',
      );
  String get staffRolesOwnAccount => t(
        'You cannot change your own roles',
        'የራስዎን ሚናዎች መቀየር አይችሉም',
        'Gahee ofii keessanii jijjiiruu hin dandeessan',
      );
  String get staffRolesSaveFailed => t(
        'Roles saved on this device, but cloud sync failed. Stay signed in as Admin (Ready), then open Roles and save again.',
        'ሚናዎች በዚህ መሣሪያ ተቀምጠዋል፣ ወደ ክላውድ ግን አልተላኩም። እንደ Admin (Ready) ገብተው Rolesን እንደገና ያስቀምጡ።',
        'Gaheen meeshaa kana irratti olkaa\'ame, garuu sync cloud hin milkoofne. Akka Admin (Ready) seenuun Roles irra deebi\'ii olkaa\'i.',
      );
  String get moduleReadOnlyBanner => t(
        'Read-only view — your role can review this module but not make changes.',
        'ለንባብ ብቻ — ሚናዎ ይህን ክፍል ማየት ይችላል፣ ለውጥ ማድረግ ግን አይችልም።',
        'Ilaalcha dubbisuu qofa — gaheen keessan kutaa kana ilaaluu danda\'a, '
        'garuu jijjiirraa gochuu hin danda\'u.',
      );
  String get moduleAccessDeniedTitle =>
      t('No access', 'መዳረሻ የለም', 'Seensi hin jiru');
  String get moduleAccessDeniedBody => t(
        'Your roles do not include access to this module. '
        'Contact your school administrator if you need it.',
        'ሚናዎችዎ ይህን ክፍል ማግኘት አያካትቱም። ካስፈለገዎት የትምህርት ቤትዎን አስተዳዳሪ ያነጋግሩ።',
        'Gaheewwan keessan kutaa kana argachuu hin dabalatan. '
        'Yoo isin barbaachise bulchaa mana barumsaa keessanii qunnamaa.',
      );
  String get staffDutiesSection => t(
        'Administration duties',
        'የአስተዳደር ተግባራት',
        'Hojiiwwan Bulchiinsaa',
      );
  String get postHomework => t('Post Homework', 'የቤት ስራ ለጥፍ');
  String get chooseSubjectYouTeach => t(
        'Subject you teach',
        'የምሰራው ትምህርት',
        'Barumsa barsiisitan',
      );
  String get homeworkVisibleToParentsHint => t(
        'Posted homework is visible to all parents in this class section.',
        'የተለጠፈው የቤት ሥራ ለዚህ ክፍል/ሴክሽን ያሉት ሁሉ ወላጆች ይመለከታሉ።',
        'Hojii manaa kutaalee/sagantaa kanaa hunda warraaf mul\'ata.',
      );
  String get enterClassGrades => t(
        'Enter class grades',
        'የክፍል ውጤቶች ያስገቡ',
        'Qabxii kutaa galchi',
      );
  String get saveGrades => t('Save grades', 'ውጤቶች አስቀምጥ', 'Qabxiiwwan kuusii');
  String get publishGradesToParents => t(
        'Publish to parents',
        'ለወላጆች አሳይ',
        'Warraaf maxxansi',
      );
  String get publishGradesToParentsHint => t(
        'When on, parents in this class section can see these grades immediately.',
        'ሲበራ ሁሉም ወላጆች በዚህ ክፍል/ሴክሽን ውጤቶቹን ይመለከታሉ።',
        'Yoo baname warri kutaa kanaa qabxiiwwan battalatti ilaala.',
      );
  String get gradesVisibleToParentsHint => t(
        'Choose your subject and enter scores for every student in this class section.',
        'ትምህርትዎን ይምረጡ እና ለክፍሉ/ሴክሽኑ ሁሉም ተማሪዎች ውጤት ያስገቡ።',
        'Barumsa keessan filadhaa fi barattoota kutaa/sagantaa kanaa hundaaf qabxii galchaa.',
      );
  String get enterAtLeastOneGrade => t(
        'Enter at least one student score',
        'ቢያንስ ለአንድ ተማሪ ውጤት ያስገቡ',
        'Yoo xiqqaate qabxii barataa tokko galchi',
      );
  String invalidScoreFor(String studentName) => t(
        'Invalid score for $studentName',
        'ለ$studentName ትክክል ያልሆነ ውጤት',
        'Qabxiin $studentName sirrii miti',
      );
  String gradesSavedForClass(int count, String className) => t(
        'Saved $count grade(s) for $className',
        '$count ውጤት(ዎች) ለ$className ተቀምጧል',
        'Qabxii $count $className tiif kuufame',
      );
  String get scoreLabel => t('Score', 'ውጤት', 'Qabxii');
  String get noHomework => t('No homework yet', 'የቤት ስራ የለም');
  String get announcementsTitle => t('Announcements', 'ማስታወቂያዎች');
  String get createAnnouncement =>
      t('Create Announcement', 'ማስታወቂያ ፍጠር');
  String get announcementPublished => t('Announcement published', 'ማስታወቂያ ተለጠፈ');
  String get noAnnouncements =>
      t('No announcements yet', 'ማስታወቂያ የለም');
  String get titleLabel => t('Title', 'ርዕስ');
  String get bodyLabel => t('Body', 'ይዘት');
  String get publish => t('Publish', 'ለጥፍ');
  String get attendanceTitle => t('Attendance', 'መገኘት');
  String get attendanceHistory => t('History', 'ታሪክ');
  String get todayTab => t('Today', 'ዛሬ');
  String get present => t('Present', 'ተገኝቷል');
  String get absent => t('Absent', 'ጠፍቷል');
  String get late => t('Late', 'ዘግይቷል');
  String get saveAttendance => t('Save Attendance', 'መገኘት አስቀምጥ');
  String get conductedBy => t('Conducted by', 'የተመዘገበ በ');
  String get feesTitle => t('Fees & Payments', 'ክፍያዎች');
  String get busTracking => t('Bus Tracking', 'አውቶቡስ መከታተል');
  String get qrEntryExit => t('QR Entry/Exit', 'QR መግቢያ/መውጫ');
  String qrScopedToClass(String className) =>
      t('Class: $className only', 'ክፍል: $className ብቻ');
  String qrWrongClassError(String className) => t(
        'This student is not in $className',
        'ይህ ተማሪ በ$className ውስጥ አይደለም',
      );
  String noStudentsInClassNamed(String className) => t(
        'No students with QR codes in $className',
        'በ$className ውስጥ QR ያላቸው ተማሪዎች የሉም',
      );
  String get noStudentsInClass =>
      t('No students with QR codes', 'QR ያላቸው ተማሪዎች የሉም');
  String get scanQr => t('Scan QR', 'QR ስካን');
  String get entry => t('Entry', 'መግቢያ');
  String get exit => t('Exit', 'መውጫ');
  String get qrLeave => t('Leave', 'ወጣ', 'Ba\'i');
  String get qrPresentCheckIn =>
      t('Present · Check in', 'ተገኝ · መግቢያ', 'Argama · Seensa');
  String get qrLeaveCheckOut =>
      t('Leave · Check out', 'ወጣ · መውጫ', 'Ba\'i · Ba\'i');
  String qrAttendanceMarked(String name, String status) => t(
        '$name marked $status in attendance',
        '$name $status ተመዝግቧል',
        '$name attendance keessatti $status ta\'e',
      );
  String transportStudentAction(String name, String action) => t(
        '$name — $action',
        '$name — $action',
        '$name — $action',
      );
  String get seenReport => t('I Have Seen This Report', 'ይህን ሪፖርት አይቻለሁ');
  String get noActivities =>
      t('No daily activities yet', 'ዕለታዊ እንቅስቃሴ የለም');
  String get comments => t('Comments', 'አስተያየቶች');
  String get termLabel => t('Term', 'ወቅት');
  String get startConversation =>
      t('Start the conversation', 'ውይይቱን ይጀምሩ');
  String get typeMessage =>
      t('Type a message...', 'መልዕክት ይፃፉ...');
  String get replyToMessage =>
      t('Reply', 'መልስ', 'Deebii');
  String get replyingTo =>
      t('Replying to', 'መልስ ለ', 'Deebii gara');
  String get cancelReply =>
      t('Cancel reply', 'መልስ ሰርዝ', 'Deebii haqi');
  String get messageSeen => t('Seen', 'ተይቷል');
  String get composeMessage =>
      t('Compose message', 'መልዕክት ጻፍ', 'Ergaa barreessi');
  String get composeMessageHint => t(
        'Choose a parent and optionally include teachers',
        'ወላጅ ይምረጡ እና በፍላጎት መምህራንን ያክሉ',
        'Maatii fili; barsiisota filannoo dabaluu dandeessa',
      );
  String get messagesAdminSubtitle => t(
        'School-wide messaging',
        'የትምህርት ቤት መልዕክት',
        'Ergaa mana barumsaa',
      );
  String get messageBroadcasts =>
      t('Broadcasts', 'የጅምላ መልዕክቶች', 'Beeksisa gurguddaa');
  String get messageDirectChats =>
      t('Direct chats', 'ቀጥታ ውይይቶች', 'Haasawa kallatti');
  String get messageGroupChats =>
      t('Communities', 'ማህበረሶች', 'Hawwiiwwan');
  String get createGroup =>
      t('Create community', 'ማህበረሰብ ፍጠር', 'Hawwii uumi');
  String get createGroupHint => t(
        'Pick parents and staff for a shared community. Everyone selected can read and reply.',
        'ለጋራ ማህበረሰብ ወላጆችን እና ሰራተኞችን ይምረጡ። የተመረጡት ሁሉ ሊያንብቡ እና ሊመልሱ ይችላሉ።',
        'Hawwii waliigalaaaf maatii fi hojjettoota fili.',
      );
  String get directChat =>
      t('Direct chat', 'ቀጥታ ውይይት', 'Haasawa kallatti');
  String get directChatHint => t(
        'Send a private message to one parent or one staff member.',
        'ለአንድ ወላጅ ወይም ለአንድ ሰራተኛ ግል መልዕክት ይላኩ።',
        'Ergaa dhuunfaa gara maatii ykn hojjetaa tokkoo ergi.',
      );
  String get messageParentsOptional => t(
        'Parents (optional)',
        'ወላጆች (አማራጭ)',
        'Maatii (filannoo)',
      );
  String get messageStaffOptional => t(
        'Staff (optional)',
        'ሰራተኞች (አማራጭ)',
        'Hojjettoota (filannoo)',
      );
  String get messageSelectStaff => t(
        'Choose staff…',
        'ሰራተኞችን ይምረጡ…',
        'Hojjettoota fili…',
      );
  String messageStaffSelected(int count) => t(
        count == 1 ? '1 staff selected' : '$count staff selected',
        count == 1 ? '1 ሰራተኛ ተመርጧል' : '$count ሰራተኞች ተመርጠዋል',
        count == 1 ? 'Hojjetaa 1 filatame' : 'Hojjettoota $count filataman',
      );
  String messageParentsSelected(int count) => t(
        count == 1 ? '1 parent selected' : '$count parents selected',
        count == 1 ? '1 ወላጅ ተመርጧል' : '$count ወላጆች ተመርጠዋል',
        count == 1 ? 'Maatii 1 filatame' : 'Maatii $count filataman',
      );
  String get messageSearchStaffHint => t(
        'Search teachers, drivers, and admin staff by name or ID.',
        'መምህራን፣ አሽከርካሪዎች እና አስተዳደር ሰራተኞችን በስም ወይም መታወቂያ ይፈልጉ።',
        'Barsiisota, konkolaachisota fi bulchitoota maqaa ykn ID tiin barbaadi.',
      );
  String get messageRecipientsRequired => t(
        'Select at least one parent or staff member',
        'ቢያንስ አንድ ወላጅ ወይም ሰራተኛ ይምረጡ',
        'Yoo xiqqaate maatii ykn hojjetaa tokko fili',
      );
  String get messageDirectRecipientRequired => t(
        'Choose either one parent or one staff member',
        'አንድ ወላጅ ወይም አንድ ሰራተኛ ይምረጡ',
        'Maatii tokko ykn hojjetaa tokko fili',
      );
  String get noStaffRegistered => t(
        'No staff registered for this school',
        'ለዚህ ትምህርት ቤት ሰራተኛ አልተመዘገበም',
        'Hojjettoonni mana barumsaa kanaaf hin galmoofne',
      );
  String get selectAll => t('Select all', 'ሁሉንም ይምረጡ', 'Hunda fili');
  String get selectAllHint => t(
        'Select everyone in the current search results',
        'በአሁኑ ፍለጋ ውስጥ ያሉትን ሁሉንም ይምረጡ',
        'Bu\'aa barbaacha ammaa keessaa hunda fili',
      );
  String get messageSendTo => t('Send to', 'ላክ ወደ', 'Ergi gara');
  String get messageParentHint => t(
        'Tap to search by parent name, student name, or student ID. Required.',
        'በወላጅ ስም፣ ተማሪ ስም ወይም መታወቂያ ይፈልጉ። ይህ አስፈላጊ ነው።',
        'Maqaa maatii, barataa ykn ID tiin barbaadi. Kun dirqama.',
      );
  String get messageParentRequired => t(
        'Select a parent',
        'ወላጅ ይምረጡ',
        'Maatii fili',
      );
  String get messageTeachersOptional => t(
        'Also notify teachers (optional)',
        'መምህራንንም ላክ (አማራጭ)',
        'Barsiisotaafis ergi (filannoo)',
      );
  String get messageTeachersOptionalHint => t(
        'Add teachers to start a group conversation where everyone can reply.',
        'ሁሉም ሊመልሱበት የሚችሉ መምህራንን ወደ ቡድን ውይይት ያክሉ።',
        'Barsiisota dabaluu dandeessa — namni hundi deebii kennuu dandaʼa.',
      );
  String get messageSelectParent => t(
        'Choose a parent…',
        'ወላጅ ይምረጡ…',
        'Maatii fili…',
      );
  String get messageSelectTeachers => t(
        'Choose teachers (optional)…',
        'መምህራን ይምረጡ (አማራጭ)…',
        'Barsiisota fili (filannoo)…',
      );
  String messageTeachersSelected(int count) => t(
        count == 1 ? '1 teacher selected' : '$count teachers selected',
        count == 1 ? '1 መምህር ተመርጧል' : '$count መምህራን ተመርጠዋል',
        count == 1 ? 'Barsiisaa 1 filatame' : 'Barsiisota $count filataman',
      );
  String get messageSearchParentHint => t(
        'Search by parent name, student name, or student ID.',
        'በወላጅ ስም፣ በተማሪ ስም ወይም በተማሪ መታወቂያ ይፈልጉ።',
        'Maqaa maatii, maqaa barataa ykn ID barataa tiin barbaadi.',
      );
  String get messageSearchTeachersHint => t(
        'Search by teacher name, ID, subject, or class.',
        'በመምህር ስም፣ መታወቂያ፣ ትምህርት ወይም ክፍል ይፈልጉ።',
        'Maqaa barsiisaa, ID, barnoota ykn kutaa tiin barbaadi.',
      );
  String get messageNoSearchResults => t(
        'No matches found',
        'ምንም ውጤት አልተገኘም',
        "Bu'aa hin argamne",
      );
  String get messageDoneSelecting => t(
        'Done',
        'ጨርስ',
        'Xumuri',
      );
  String get messageGroupNotice => t(
        'Community — selected parents and staff can reply',
        'ማህበረሰብ — የተመረጡ ወላጆች እና ሰራተኞች መልስ ሊሰጡ ይችላሉ',
        'Hawwii — maatiin fi hojjettoonni filataman deebii kennuu danda\'u',
      );
  String get communityMembers =>
      t('Community members', 'የማህበረሰብ አባላት', 'Miseensota hawwii');
  String communityMembersCount(int count) => t(
        '$count members',
        '$count አባላት',
        'Miseensota $count',
      );
  String get communityMembersEmpty =>
      t('No members in this community', 'በዚህ ማህበረሰብ ውስጥ አባል የለም', 'Miseensi hin jiru');
  String get removeMember =>
      t('Remove', 'አስወግድ', 'Haqi');
  String get memberRemoved =>
      t('Member removed', 'አባል ተወግዷል', 'Miseensi haqame');
  String get viewMembers =>
      t('View members', 'አባላትን ይመልከቱ', 'Miseensota ilaali');
  String get addMember =>
      t('+ Add member', '+ አባል ጨምር', '+ Miseensa dabaluu');
  String get addCommunityMembers =>
      t('Add members', 'አባላት ጨምር', 'Miseensota dabaluu');
  String get addCommunityMembersHint => t(
        'Select parents or staff to add to this community.',
        'ወደዚህ ማህበረሰብ ለመጨመር ወላጆችን ወይም ሰራተኞችን ይምረጡ።',
        'Gara hawwii kanaatti dabaluuf maatii ykn hojjettoota fili.',
      );
  String get membersAdded =>
      t('Members added', 'አባላት ተጨምረዋል', 'Miseensonni dabalaman');
  String get noMembersAvailableToAdd => t(
        'Everyone is already in this community',
        'ሁሉም በዚህ ማህበረሰብ ውስጥ አሉ',
        'Namni hundi duraan hawwii kana keessa jira',
      );
  String get noParentsRegistered => t(
        'No parents found in student records',
        'በተማሪ መዝገቦች ውስጥ ወላጅ አልተገኘም',
        'Galmeewwan barattootaa keessatti maatiin hin argamne',
      );
  String get noTeachersRegistered => t(
        'No teachers registered for this school',
        'ለዚህ ትምህርት ቤት መምህር አልተመዘገበም',
        'Barsiisni mana barumsaa kanaaf hin galmoofne',
      );
  String get communityNameLabel => t(
        'Community name',
        'የማህበረሰብ ስም',
        'Maqaa hawwii',
      );
  String get communityNameRequired => t(
        'Enter a community name',
        'የማህበረሰብ ስም ያስገቡ',
        'Maqaa hawwii galchi',
      );
  String get communityPhotoOptional => t(
        'Community photo (optional)',
        'የማህበረሰብ ፎቶ (አማራጭ)',
        'Suuraa hawwii (filannoo)',
      );
  String get addCommunityPhoto => t(
        'Add photo',
        'ፎቶ ጨምር',
        'Suuraa dabaluu',
      );
  String get changeCommunityPhoto => t(
        'Change photo',
        'ፎቶ ቀይር',
        'Suuraa jijjiiri',
      );
  String get removeCommunityPhoto => t(
        'Remove photo',
        'ፎቶ አስወግድ',
        'Suuraa haqi',
      );
  String get messageAddAttachment => t(
        'Add attachment',
        'attachment ጨምር',
        'Maxxansa dabaluu',
      );
  String get messageContentRequired => t(
        'Enter a message or add an attachment',
        'መልዕክት ያስገቡ ወይም attachment ጨምሩ',
        'Ergaa galchi ykn maxxansa dabaluu',
      );
  String messageAttachmentCount(int count) => t(
        count == 1 ? '1 attachment' : '$count attachments',
        count == 1 ? '1 attachment' : '$count attachments',
        count == 1 ? 'Maxxansa 1' : 'Maxxansawwan $count',
      );
  String get messageBodyRequired =>
      t('Message is required', 'መልዕክት ያስፈልጋል', 'Ergaan barbaachisa');
  String get messageSubjectOptional =>
      t('Subject (optional)', 'ርዕስ (አማራጭ)', 'Mata duree (filannoo)');
  String get sendMessage =>
      t('Send message', 'መልዕክት ላክ', 'Ergaa ergi');
  String get messageSent =>
      t('Message sent', 'መልዕክት ተልኳል', 'Ergaan ergame');
  String get voiceStartRecording =>
      t('Record voice message', 'የድምፅ መልዕክት መቅዳት', 'Ergaa sagalee waraabi');
  String get voiceStopRecording =>
      t('Stop recording', 'መቅዳት አቁም', 'Waraabuu dhaabi');
  String get voiceMessageReady =>
      t('Voice message ready', 'የድምፅ መልዕክት ዝግጁ', 'Ergaan sagalee qophaa\'e');
  String get voiceRecordFailed =>
      t('Could not save voice message', 'የድምፅ መልዕክት መጨመር አልተሳካም', 'Ergaa sagalee kuufamuu hin dandeenye');
  String get voicePlaybackFailed => t(
        'Could not play voice message',
        'የድምፅ መልዕክት መጫወት አልተሳካም',
        'Ergaa sagalee taphachuu hin dandeenye',
      );
  String get voiceMessageLabel =>
      t('Voice message', 'የድምፅ መልዕክት', 'Ergaa sagalee');
  String get voiceUnavailable => t(
        'Voice message unavailable',
        'የድምፅ መልዕክት አልተገኘም',
        'Ergaa sagalee hin argamne',
      );
  String get voicePermissionDenied => t(
        'Microphone permission is required to record voice messages',
        'የድምፅ መልዕክት ለመቅዳት የማይክሮፎን ፈቃድ ያስፈልጋል',
        'Ergaa sagalee waraabuuuf hayyama maayikiroofoonii barbaachisa',
      );
  String get voiceHoldToRecord =>
      t('Hold to record, release to send', 'ለመቅዳት ይ按住 ይልቀቁ ለመላክ', 'Waraabuuf qabi, erguuf gadi lakkisi');
  String get deleteMessage =>
      t('Delete message', 'መልዕክት ሰርዝ', 'Ergaa haqi');
  String get deleteMessageConfirm => t(
        'Delete this message?',
        'ይህ መልዕክት ይሰረዝ?',
        'Ergaa kana haquu?',
      );
  String get messageDeleted =>
      t('Message deleted', 'መልዕክት ተሰርዟል', 'Ergaan haqame');
  String get changePassword =>
      t('Change password', 'የይለፍ ቃል ቀይር', 'Jecha iccitii jijjiiri');
  String get changePasswordHint => t(
        'Enter your current password, then choose a new one. No OTP required.',
        'የአሁኑን የይለፍ ቃል አስገብተው አዲስ ይምረጡ። OTP አያስፈልግም።',
        'Jecha iccitii ammaa galchi, haaraa filadhu. OTP hin barbaachisu.',
      );
  String get changePasswordCurrentLabel => t(
        'Current password',
        'የአሁኑ የይለፍ ቃል',
        'Jecha iccitii ammaa',
      );
  String get changePasswordCurrentRequired => t(
        'Enter your current password',
        'የአሁኑን የይለፍ ቃል ያስገቡ',
        'Jecha iccitii ammaa galchi',
      );
  String get changePasswordCurrentWrong => t(
        'Current password is incorrect',
        'የአሁኑ የይለፍ ቃል ትክክል አይደለም',
        'Jecha iccitii ammaa sirrii miti',
      );
  String get changePasswordSameAsCurrent => t(
        'New password must be different from the current one',
        'አዲሱ የይለፍ ቃል ከአሁኑ የተለየ መሆን አለበት',
        'Jecha iccitii haaraan ammaa irraa adda ta\'uu qaba',
      );
  String get changePasswordSendOtp =>
      t('Send OTP', 'OTP ላክ', 'OTP ergi');
  String get changePasswordOtpSent =>
      t('OTP sent', 'OTP ተልኳል', 'OTP ergame');
  String changePasswordDemoOtp(String otp) => t(
        'Demo OTP: $otp',
        'Demo OTP: $otp',
        'OTP demo: $otp',
      );
  String get changePasswordOtpLabel =>
      t('OTP code', 'OTP ኮድ', 'Koodii OTP');
  String get changePasswordNewLabel =>
      t('New password', 'አዲስ የይለፍ ቃል', 'Jecha iccitii haaraa');
  String get changePasswordConfirmLabel =>
      t('Confirm password', 'የይለፍ ቃል አረጋግጥ', 'Jecha iccitii mirkaneessi');
  String get changePasswordSave =>
      t('Save password', 'የይለፍ ቃል አስቀምጥ', 'Jecha iccitii kuusi');
  String get changePasswordSuccess =>
      t('Password updated', 'የይለፍ ቃል ተዘምኗል', 'Jecha iccitii haaromfame');
  String get changePasswordFailed =>
      t('Could not update password', 'የይለፍ ቃል መቀየር አልተሳካም', 'Jecha iccitii jijjiiruun hin danda\'amne');
  String get changePasswordInvalidOtp =>
      t('Invalid OTP', 'OTP ትክክል አይደለም', 'OTP sirrii miti');
  String get changePasswordTooShort =>
      t('Password must be at least 10 characters', 'የይለፍ ቃል ቢያንስ 10 ቁምፊ', 'Jecha iccitii yoo xiqqaate qubee 10');
  String get changePasswordMismatch =>
      t('Passwords do not match', 'የይለፍ ቃሎች አይዛመዱም', 'Jechi iccitii wal hin fudhanu');
  String get changePasswordSendOtpFirst =>
      t('Send OTP first', 'መጀመሪያ OTP ላክ', 'Dura OTP ergi');
  String get changePasswordUserNotFound =>
      t('Account not found', 'መለያ አልተገኘም', 'Herrega hin argamne');
  String get noHomeroomTeacherForClass => t(
        'No homeroom teacher registered for this class',
        'ለዚህ ክፍል የመጀመሪያ መምህር አልተመዘገበም',
        'Barsiisaa kutaa kanaaf hin galmoofne',
      );
  String get messageBroadcastNotice => t(
        'School broadcast — replies go to admin only',
        'የትምህርት ቤት ጅምላ መልዕክት',
        'Beeksisa mana barumsaa — deebii gara bulchaa qofa',
      );
  String messageAudienceKey(String key) {
    switch (key) {
      case 'parents':
        return parents;
      case 'teachers':
        return teachers;
      case 'transport':
        return transportStaff;
      default:
        return announcementAudienceKey(key);
    }
  }
  String get noSubjectsAssigned => t('No subjects assigned for you in this class', 'በዚህ ክፍል ምንም ትምህርት አልተመደበዎትም');
  String get description => t('Description', 'መግለጫ');
  String get dueDate => t('Due date', 'የመጨረሻ ጊዜ');
  String get homeworkPosted => t('Homework posted', 'የቤት ስራ ተለጠፈ');
  String get selectClass => t('Select class', 'ክፍል ይምረጡ');
  String get allClasses => t('All classes', 'ሁሉም ክፍሎች');
  String get readOnly => t('Read only', 'ለማንበብ ብቻ');
  String get historyTab => t('History', 'ታሪክ');
  String get markPresent => t('Present', 'ተገኝቷል');
  String get markAbsent => t('Absent', 'ጠፍቷል');
  String get markLate => t('Late', 'ዘግይቷል');
  String get paid => t('Paid', 'ተከፍሏል');
  String get unpaid => t('Unpaid', 'አልተከፈለም');
  String get amount => t('Amount', 'መጠን');
  String get status => t('Status', 'ሁኔታ');
  String get liveLocation => t('Live location', 'ቀጥታ ቦታ');
  String get routeStops => t('Route stops', 'መና ማቆሚያዎች');
  String get scanSuccess => t('Scan recorded', 'ስካን ተሳክቷል');
  String get scanHint => t('Point the camera at the student QR code', 'QR ኮዱን በካሜራው ውስጥ ያስቀምጡ');
  String get childrenOverview =>
      t('Children overview', 'የልጆች አጠቃላይ');
  String get viewDetails => t('View details', 'ዝርዝር ይመልከቱ');
  String get activitySaved => t('Daily activity saved', 'ዕለታዊ እንቅስቃሴ ተቀምጧል');
  String get saveActivity => t('Save activity', 'እንቅስቃሴ አስቀምጥ');
  String get noChildren =>
      t('No linked children', 'ምንም ተመዝገበ ተማሪ የለም');
  String get createNew => t('Create new', 'አዲስ ፍጠር');
  String get all => t('All', 'ሁሉም');
  String get parents => t('Parents', 'ወላጆች');
  String get teachers => t('Teachers', 'መምህራን');
  String get staffAudience => t('Staff', 'ሰራተኞች');
  String get holiday => t('Holiday', 'በዓል');
  String get event => t('Event', 'ክስተት');
  String get noEvents => t('No events on this day', 'ክስተት የለም');
  String get edit => t('Edit', 'አርትዕ');
  String get delete => t('Delete', 'ሰርዝ');
  String get confirm => t('Confirm', 'አረጋግጥ');
  String get search => t('Search', 'ፈልግ');
  String get filter => t('Filter', 'ማጣሪያ');
  String get today => t('Today', 'ዛሬ');
  String get yesterday => t('Yesterday', 'ትላንት');

  // —— My Classes ——
  String get homeroomTeacher =>
      t('Homeroom Teacher', 'የክፍል መምህር');
  String get subjectTeacher =>
      t('Subject Teacher', 'የትምህርት መምህር');
  String studentsCount(int count) =>
      t('$count students', '$count ተማሪዎች');
  String get fullAccess => t('Full access', 'ሙሉ መዳረሻ');
  String get messagesOnlyChip =>
      t('Messages', 'መልዕክቶች');
  String get subjectTeacherAccessChip =>
      t('Subject access', 'የትምህርት መዳረሻ');
  String get classToolsFullAccess =>
      t('Class tools — full access', 'የክፍል መሳሪያዎች — ሙሉ መዳረሻ');
  String get classToolsSubjectAccess =>
      t('Class tools — your subject', 'የክፍል መሳሪያዎች — የእርስዎ ትምህርት');
  String get calendarReadOnly =>
      t('Calendar (view only)', 'ቀን መቁጠሪያ (ለማየት ብቻ)');
  String get editHomework => t('Edit homework', 'የቤት ስራ አርትዕ');
  String get markPhotosLabel =>
      t('Mark sheet photos', 'የውጤት ሉህ ፎቶዎች');
  String get addMarkPhotos =>
      t('Add mark photos', 'የውጤት ፎቶ ጨምር');
  String get homeworkUpdated =>
      t('Homework updated', 'የቤት ስራ ተዘምኗል');
  String get subjectGradesOnlyHint => t(
        'Showing grades for your assigned subject only',
        'ለተመደብዎት ትምህርት ብቻ ውጤቶችን እያሳየ',
      );
  String get homeroomGradesViewOnlyHint => t(
        'You can view all subjects for reports and rankings. You can only edit grades for subjects you teach.',
        'ለሪፖርት እና ደረጃ ሁሉንም ትምህርቶች መመልከት ይችላሉ። የሚያስተምሩትን ትምህርት ብቻ መስተካከል ይችላሉ።',
      );
  String get homeroomGradesReadOnlyHint => t(
        'All subjects shown for reference — only your subject is editable on the Grades tab.',
        'ሁሉም ትምህርቶች ለመመልከት ብቻ — የሚያስተምሩትን ትምህርት ብቻ በውጤቶች ትር ላይ ይስተካከላል።',
      );
  String get classRankingsTitle =>
      t('Class rankings', 'የክፍል ደረጃ');
  String get classRankingsTab => t('Rankings', 'ደረጃ');
  String get gradesDetailTab => t('Grades', 'ውጤቶች');
  String classRankingsSubtitle(int count) => t(
        'All $count students ranked by average',
        'ሁሉም $count ተማሪዎች በአማካይ ደረጃ',
      );
  String get rankLegendTitle => t('Ranking colors', 'የደረጃ ቀለሞች');
  String get rankLegendTop3 => t('Rank 1–3', 'ደረጃ 1–3');
  String get rankLegendTop10 => t('Rank 4–10', 'ደረጃ 4–10');
  String get rankLegendStandard => t('Rank 11+ (50%+)', 'ደረጃ 11+ (50%+)');
  String get rankLegendBelow50 => t('Below 50%', 'ከ 50% በታች');

  String get timetableTitle => t('Timetable', 'የጊዜ ሰሌዳ');
  String get timetableAdminTitle =>
      t('Class Timetables', 'የክፍል የጊዜ ሰሌዳዎች');
  String get timetableMonday => t('Mon', 'ሰኞ');
  String get timetableTuesday => t('Tue', 'ማክሰ');
  String get timetableWednesday => t('Wed', 'ረቡዕ');
  String get timetableThursday => t('Thu', 'ሐሙስ');
  String get timetableFriday => t('Fri', 'አርብ');
  @override
  String get timetableBreak => t('Break', 'እረፍት');
  @override
  String get timetableLunch => t('Lunch', 'ምሳ');
  @override
  String get timetableUntitledLesson => t('Lesson', 'ትምህርት');
  String get timetableEditSlot => t('Edit slot', 'ጊዜ ማስተካከል');
  String get timetableSlotType => t('Slot type', 'የጊዜ አይነት');
  String get timetableSlotLesson => t('Class (40 min default)', 'ትምህርት (40 ደቂቃ)');
  String get timetableDurationMinutes =>
      t('Duration (minutes)', 'ቆይታ (ደቂቃ)');
  String get timetableDayStart => t('Day start time', 'የቀን መጀመሪያ ሰዓት');
  String get timetableAddSlot => t('Add slot', 'ጊዜ ጨምር');
  String get timetableNoClass => t('No class selected', 'ምንም ክፍል አልተመረጠም');
  String get timetableEmptyDay =>
      t('No slots for this day', 'ለዚህ ቀን ጊዜ አልተዘጋጀም');
  String get timetableSaved => t('Timetable saved', 'የጊዜ ሰሌዳ ተቀምጧል');
  String get timetableSaveChanges =>
      t('Save timetable', 'የጊዜ ሰሌዳ አስቀምጥ');
  String get timetableUnsavedChanges => t(
        'Unsaved changes — save to publish for teachers, parents and admins',
        'ያልተቀመጡ ለውቶች — ለመምህሮች፣ ወላጆች እና አስተዳዳሪዎች ለማተም አስቀምጥ',
      );
  String get timetableSaveHint => t(
        'Edits are draft until you save the timetable',
        'የጊዜ ሰሌዳውን እስካልቀመጡ ድረስ ለውቶች draft ናቸው',
      );
  String get timetableDiscardChangesTitle =>
      t('Discard changes?', 'ለውቶች ይወገዱ?');
  String get timetableDiscardChangesMessage => t(
        'You have unsaved timetable changes. Leave without saving?',
        'ያልተቀመጡ የጊዜ ሰሌዳ ለውቶች አሉዎት። ሳያስቀምጡ መውጣት ይፈልጋሉ?',
      );
  String get timetableDiscardConfirm =>
      t('Leave without saving', 'ሳያስቀምጡ ውጣ');
  String timetableLastUpdated(String when) =>
      t('Last updated: $when', 'መጨረሻ ተሻሽሏል፡ $when');
  String get timetableMoveUp => t('Move up', 'ወደ ላይ አንቀሳቅስ');
  String get timetableMoveDown => t('Move down', 'ወደ ታች አንቀሳቅስ');
  String get timetableReadOnlyHint => t(
        'View only — homeroom teacher manages this timetable',
        'ለማየት ብቻ — የክፍል መምህር ይህንን የጊዜ ሰሌዳ ያስተዳድራል',
      );
  String timetableHomeroomBy(String name) =>
      t('Homeroom: $name', 'ክፍል መምህር፡ $name');
  String timetableMinutes(int minutes) =>
      t('$minutes min', '$minutes ደቂቃ');

  String timetableClassPeriod(int period) {
    if (period <= 0) return t('Class', 'ክፍል');
    if (isAmharic) {
      return switch (period) {
        1 => 'መጀመሪያ ክፍል',
        2 => 'ሁለተኛ ክፍል',
        3 => 'ሶስተኛ ክፍል',
        4 => 'ራባተኛ ክፍል',
        5 => 'አምስተኛ ክፍል',
        6 => 'ስድስተኛ ክፍል',
        7 => 'ሰባተኛ ክፍል',
        8 => 'ስምንተኛ ክፍል',
        _ => 'ክፍል $period',
      };
    }
    return switch (period) {
      1 => t('First class', 'መጀመሪያ ክፍል'),
      2 => t('Second class', 'ሁለተኛ ክፍል'),
      3 => t('Third class', 'ሶስተኛ ክፍል'),
      4 => t('Fourth class', 'ራባተኛ ክፍል'),
      5 => t('Fifth class', 'አምስተኛ ክፍል'),
      6 => t('Sixth class', 'ስድስተኛ ክፍል'),
      7 => t('Seventh class', 'ሰባተኛ ክፍል'),
      8 => t('Eighth class', 'ስምንተኛ ክፍል'),
      _ => t('Class $period', 'ክፍል $period'),
    };
  }

  String get dashboardWelcomeSchoolOverview =>
      t('School overview', 'የትምህርት ቤት ማጠቃለያ');
  String get dashboardWelcomeTransportOverview =>
      t('My route', 'የእኔ መስመር');
  String get dashboardNoChildrenLinked =>
      t('No children linked yet', 'ምንም ልጅ አልተገናኘም');
  String get driverIdLabel => t('Driver ID', 'የአሽከርካሪ መታወቂያ');
  String get subjectIdLabel => t('Subject ID', 'የትምህርት መለያ');
  String get teachingSlotIdLabel => t('Assignment ID', 'የመድብ መለያ');
  String get teachingAssignmentsTitle =>
      t('Your teaching assignments', 'የእርስዎ የመምህርነት መድቦች');
  String get teachingAssignmentQrTitle =>
      t('Teaching assignment QR', 'የመምህርነት መድብ QR');
  String get teachingAssignmentQrHint => t(
        'Scan or share this code to verify the teacher, subject, and class link.',
        'መምህር፣ ትምህርት እና ክፍል መያያዣውን ለማረጋገጥ ይህን ኮድ ይቃኙ ወይም ያጋሩ።',
      );
  String get viewTeachingQr => t('View QR', 'QR ይመልከቱ');
  String get routeLabel => t('Route', 'መስመር');
  String get roleAdminLabel => t('Administrator', 'አስተዳዳሪ');
  String get roleDriverLabel => t('Transport driver', 'የትራንስፖርት አሽከርካሪ');
  String get profileMenuHint =>
      t('View and update your account', 'መለያዎን ይመልከቱ እና ያዘምኑ');
  String get settingsMenuHint =>
      t('Language, layout, and security', 'ቋንቋ፣ አቀማመጥ እና ጥበቃ');

  String dashboardStatStaff(int count) =>
      t('$count staff', '$count ሰራተኞች');
  String dashboardStatStudents(int count) =>
      t('$count students', '$count ተማሪዎች');
  String dashboardStatChildren(int count) =>
      t('$count ${count == 1 ? 'child' : 'children'}',
          count == 1 ? '1 ልጅ' : '$count ልጆች');
  String dashboardStatClasses(int count) =>
      t('$count classes', '$count ክፍሎች');
  String dashboardStatHomerooms(int count) =>
      t('$count homeroom', '$count ክፍል መምህር');
  String dashboardStatApprovals(int count) =>
      t('$count approvals', '$count ጥያቄዎች');
  String dashboardStatBus(String busNumber) =>
      t('Bus $busNumber', 'አውቶቡስ $busNumber');
  String dashboardStatPlate(String plate) =>
      t('Plate $plate', 'ሰሌዳ $plate');
  String rankPosition(int rank) => t('Rank #$rank', 'ደረጃ #$rank');
  String get studentConductLabel => t('Student conduct', 'የተማሪ ባሕሪ');
  String get conductExcellent => t('Excellent', 'በጣም ጥሩ');
  String get conductSatisfactory => t('Good standing', 'ጥሩ');
  String get conductNeedsAttention => t('Needs attention', 'ትኩረት ይต้ቀ');
  String get contactParentTitle => t('Contact parent', 'ወላጅን ያግኙ');
  String get callParent => t('Call parent', 'ወላጅን ይደውሉ');
  String get messageInApp => t('Message in app', 'በመተግበሪያው መልዕክት');
  String get sendSms => t('Send SMS', 'SMS ይላኩ');
  String get noParentPhoneOnFile =>
      t('No parent phone number on file', 'የወላጅ ስልክ አልተመዘገበም');
  String get couldNotOpenPhone =>
      t('Could not open phone dialer', 'ስልክ መደወል አልተከፈተም');
  String get couldNotOpenSms => t('Could not open SMS app', 'SMS መክፈት አልተሳካም');
  String homeroomParentSmsTemplate(String studentName, String className) => t(
        'Hello, this is the homeroom teacher for $className regarding $studentName.',
        'ሰላም፣ ስለ $studentName የ$className ክፍል መምህር ነኝ።',
      );
  String get exportCurrentClassReport =>
      t('Export this class', 'ይህንን ክፍል ላክ');
  String get exportAllHomeroomReports =>
      t('Export all homeroom classes', 'ሁሉንም የክፍል ክፍሎች ላክ');
  String get subjectHomeworkOnlyHint => t(
        'Showing homework you posted for this class',
        'ለዚህ ክፍል የለጠፉት የቤት ስራ ብቻ',
      );
  String get homeroomClass => t('Homeroom Class', 'የክፍል ክፍል');
  String get studentsTapPhoto =>
      t('Students', 'ተማሪዎች');
  String get adminOnlyPhotoHint =>
      t('Photo — admin only', 'ፎቶ — አድሚን ብቻ');
  String get changeProfilePhoto =>
      t('Change photo', 'ፎቶ ቀይር');
  String get staffOverview =>
      t('Staff overview', 'የሰራተኞች መረጃ');
  String get staffOverviewHint => t(
        'Teachers and transport staff at your school',
        'የትምህርት ቤቱ መምህራን እና የትራንስፖርት ሰራተኞች',
      );
  String parentOf(String name) =>
      t('Parent: $name', 'ወላጅ: $name');
  String gradeLevel(String grade) =>
      t('Grade $grade', 'ክፍል $grade');

  // —— Homework ——
  String get addHomework => t('Add Homework', 'የቤት ስራ ጨምር');
  String get homeworkDetails =>
      t('Homework details', 'የቤት ስራ ዝርዝር');
  String get homeworkPostedForParents => t('Homework posted for parents', 'የቤት ስራ ለወላጆች ተለጠፈ');
  String get noHomeworkPosted =>
      t('No homework posted yet', 'የቤት ስራ አልተለጠፈም');

  // —— Gallery ——
  String get classGallery => t('Class Gallery', 'የክፍል ጋለሪ');
  String get captionNotes =>
      t('Caption / Notes', 'መግለጫ / ማስታወሻ');
  String chooseMedia(String type) =>
      t('Choose $type', '$type ይምረጡ');
  String get photoSelectedDemo =>
      t('Photo selected (demo upload)', 'ፎቶ ተመርጧል (ማሳያ)');
  String get videoSelectedDemo =>
      t('Video selected (demo upload)', 'ቪዲዮ ተመርጧል (ማሳያ)');
  String downloadedDemo(String file) => t('Downloaded $file (demo — saved to gallery folder)', '$file ተወርዷል (ማሳያ)');
  String savedNote(String title) =>
      t('Saved note: $title', 'ማስታወሻ ተቀምጧል: $title');

  // —— Grade Reports ——
  String editSubjectTitle(String subject) =>
      t('Edit $subject', '$subject አርትዕ');
  String scoreOutOf(double max) =>
      t('Score (out of ${max.toInt()})', 'ውጤት (ከ $max)');
  String get commentLabel => t('Comment', 'አስተያየት');
  String get subjectNameHint =>
      t('e.g. ICT, Music, PE', 'ለምሳሌ ICT, Music, PE');
  String get subjectNameLabel =>
      t('Subject name', 'የትምህርት ስም');
  String get subjectAdded => t('Subject added — tap edit to enter grade', 'ትምህርት ተጨመረ — ደረጃ ለመግባት አርትዕ ይንኩ');
  String get subjectAlreadyExists =>
      t('Subject already exists', 'ትምህርቱ አስቀድሞ አለ');
  String get subjectBreakdown =>
      t('Subject Breakdown', 'በትምህርት ዝርዝር');
  String averageLabel(double avg) =>
      t('Average: ${avg.toStringAsFixed(1)}%', 'አማካይ: ${avg.toStringAsFixed(1)}%');
  String get editGradeTooltip =>
      t('Edit grade', 'ደረጃ አርትዕ');
  String get adminGradeOverviewSubtitle => t(
        'Top performers and students below 50% — compiled from teacher grade reports',
        'ከፍተኛ አፈጻጸም እና ከ 50% በታች — ከመምህር ደረጃ ሪፖርቶች',
        'Performansii ol\'aanaa fi 50% gadi — gabaasa barsiisaa irraa',
      );
  String get adminGradeTopPerformersCaption => t(
        'Top performers',
        'ከፍተኛ አፈጻጸም',
        'Performansii ol\'aanaa',
      );
  String get adminGradeNeedsSupportCaption => t(
        'Need support',
        'ድጋፍ ያስፈልጋል',
        'Deeggarsa barbaachisa',
      );
  String get topScorersTab =>
      t('Top scorers', 'ከፍተኛ ውጤት', 'Qabxii ol\'aanaa');
  String get underperformingTab =>
      t('Underperforming', 'ዝቅተኛ አፈጻጸም', 'Performansii gadi aanaa');
  String get gradeWideTopTen => t(
        'Grade-wide top 10',
        'በክፍል ደረጃ 10 ምርጦች',
        'Qabxii 10 ol\'aanaa kutaa',
      );
  String get adminGradeTopTenSummary => t(
        'Section leaders and grade-wide ranking',
        'የሴክሽን ምርጦች እና በክፍል ደረጃ',
        'Filatamtoota kutaa fi sadarkaa kutaa',
      );
  String sectionTopTen(String section, String className) => t(
        'Section $section · top 10 ($className)',
        'ሴክሽን $section · 10 ምርጦች ($className)',
        'Kutaa $section · 10 ol\'aanaa ($className)',
      );
  String sectionUnderperforming(String section, String className, int count) =>
      t(
        'Section $section · under 50% ($className) · $count',
        'ሴክሽን $section · ከ 50% በታች ($className) · $count',
        'Kutaa $section · 50% gadi ($className) · $count',
      );
  String underperformingCount(int count) => t(
        '$count student${count == 1 ? '' : 's'} below 50%',
        '$count ተማሪ${count == 1 ? '' : 'ዎች'} ከ 50% በታች',
        'Barataa $count 50% gadi',
      );
  String get underperformingThresholdNote => t(
        'Students listed here scored below 50% average across their reported subjects.',
        'እዚህ የተዘረዘሩ ተማሪዎች በሪፖርት የተደረጓቸው ትምህርቶች አማካይ ከ 50% በታች ነው።',
        'Barattoonni kun dachaa gadi 50% qabxii waliigalaa qabu.',
      );
  String get noTopScorersData => t(
        'No grade reports yet. Teachers must enter scores first.',
        'የደረጃ ሪፖርት የለም። መምህራን መጀመሪያ ደረጃ መግባት አለባቸው።',
        'Gabaasi qabxii hin jiru. Barsiisoonni dura qabxii galchuu qabu.',
      );
  String get noUnderperformingStudents => t(
        'No students below 50% in current reports.',
        'በአሁኑ ሪፖርት ከ 50% በታች ተማሪ የለም።',
        'Gabaasa amma keessatti barataa 50% gadi hin jiru.',
      );
  String get noSectionGradeData => t(
        'No scores reported for this section yet',
        'ለዚህ ሴክሽን ደረጃ ገና አልተመዘገበም',
        'Kutaaf qabxiin ammallee hin galmoofne',
      );
  String get sendCongratsToParent => t(
        'Send congratulations',
        'እንኳን ደስ አለው መልዕክት ላክ',
        'Baga gammaddan ergi',
      );
  String get sendAllCongrats => t(
        'Send all congratulations',
        'ሁሉንም እንኳን ደስ አለው መልዕክት ላክ',
        'Baga gammaddan hunda ergi',
      );
  String get askHomeroomRecommendation => t(
        'Ask homeroom teacher',
        'የክፍል መምህርን ጥያቄ ላክ',
        'Barsiisaa kutaa gaafadhu',
      );
  String get askAllHomeroomRecommendations => t(
        'Ask all homeroom teachers',
        'ለሁሉም የክፍል መምህራን ጥያቄ ላክ',
        'Barsiisota kutaa hunda gaafadhu',
      );
  String get congratsSent =>
      t('Congratulations sent to parent', 'እንኳን ደስ አለው መልዕክት ተልኳል', 'Baga gammaddan ergame');
  String get recommendationRequested => t(
        'Recommendation request sent to homeroom teacher',
        'የማሻሻያ ጥያቄ ለክፍል መምህር ተልኳል',
        'Gaaffiin gorsaa barsiisaa kutaa ergame',
      );
  String get noParentOnFile => t(
        'No parent contact found for this student',
        'ለዚህ ተማሪ ወላጅ አልተገኘም',
        'Maatiin barataa kanaaf hin argamne',
      );
  String get noHomeroomTeacher => t(
        'No homeroom teacher assigned for this class',
        'ለዚህ ክፍል የክፍል መምህር አልተመደበም',
        'Barsiisni kutaa kanaaf hin ramadamne',
      );
  String bulkCongratsSent(int count) => t(
        'Congratulations sent to $count parent${count == 1 ? '' : 's'}',
        'እንኳን ደስ አለው መልዕክት ለ $count ወላጅ${count == 1 ? '' : 'ዎች'} ተልኳል',
        'Baga gammaddan gara maatii $count ergame',
      );
  String bulkRecommendationsSent(int count) => t(
        '$count recommendation request${count == 1 ? '' : 's'} sent',
        '$count የማሻሻያ ጥያቄ${count == 1 ? '' : 's'} sent',
        'Gaaffii gorsaa $count ergame',
      );
  String get sentLabel => t('Sent', 'ተልኳል', 'Ergame');
  String confirmSendAllCongrats(int count) => t(
        'Send congratulations to $count parent${count == 1 ? '' : 's'}?',
        'ለ $count ወላጅ${count == 1 ? '' : 's'} እንኳን ደስ አለው መልዕክት ይላክ?',
        'Baga gammaddan gara maatii $count erguu?',
      );
  String confirmAskAllRecommendations(int count) => t(
        'Request improvement recommendations for $count student${count == 1 ? '' : 's'}?',
        'ለ $count ተማሪ${count == 1 ? '' : 's'} የማሻሻያ ጥያቄ ይላክ?',
        'Gaaffii fooyya\'iinsaa barataa $count erguu?',
      );
  String get exportGradeReport => t(
        'Export report',
        'ሪፖርት ላክ',
        'Gabaasa baasi',
      );
  String get exportGradeReportTitle => t(
        'Grade performance report',
        'የደረጃ አፈጻጸም ሪፖርት',
        'Gabaasa performansii qabxii',
      );
  String get exportTopScorersSheet =>
      t('Top scorers', 'ከፍተኛ ውጤት', 'Qabxii ol\'aanaa');
  String get exportTopScorerSubjectsSheet => t(
        'Top scorer subjects',
        'የከፍተኛ ውጤት ትምህርቶች',
        'Barnoota qabxii ol\'aanaa',
      );
  String get exportUnderperformingSheet =>
      t('Underperforming', 'ዝቅተኛ አፈጻጸም', 'Performansii gadi aanaa');
  String get exportUnderperformingSubjectsSheet => t(
        'Underperforming subjects',
        'የዝቅተኛ አፈጻጸም ትምህርቶች',
        'Barnoota performansii gadi aanaa',
      );
  String get exportRankTypeColumn => t('Rank type', 'የደረጃ አይነት', 'Gosa sadarkaa');
  String get exportRankColumn => t('Rank', 'ደረጃ', 'Sadarkaa');
  String get exportAverageColumn => t('Average %', 'አማካይ %', 'Giddugalee %');
  String get exportScoreColumn => t('Score', 'ውጤት', 'Qabxii');
  String get exportMaxScoreColumn => t('Max score', 'ከፍተኛ ውጤት', 'Qabxii ol\'aanaa');
  String get exportPercentageColumn => t('Percentage', 'መቶኛ', 'Dhibbeentaa');
  String get exportLetterGradeColumn => t('Letter grade', 'የቁጥር ደረጃ', 'Qabxii qubee');
  String get exportRankTypeGradeWide =>
      t('Grade-wide', 'በክፍል ደረጃ', 'Kutaa waliigalaa');
  String get exportRankTypeSection => t('Section', 'ሴክሽን', 'Kutaa');
  String get exportGradeReportSuccess => t(
        'Grade report Excel file ready to share',
        'የደረጃ ሪፖርት Excel ፋይል ለማጋራት ዝግጁ ነው',
        'Faayilii Excel gabaasa qabxii qooduuf qophaa\'e',
      );
  String get exportGradeReportFailed => t(
        'Could not export grade report',
        'የደረጃ ሪፖርት ላክ አልተሳካም',
        'Gabaasa qabxii baasuu hin dandeenye',
      );

  // —— Calendar ——
  String get dateLabel => t('Date', 'ቀን');
  String get typeLabel => t('Type', 'አይነት');
  String get autoPostAnnouncements => t(
        'Auto-post to Announcements (1 day before & on event day)',
        'በክስተት ቀን 1 ቀን በፊት እና በቀን ማስታወቂያ በራስ-ሰር ለጥፍ',
        'Beeksisa guyyaa dura 1 fi guyyaa kana ofiin maxxansi',
      );
  String get upcomingEthiopianHolidays => t('Upcoming Ethiopian Holidays', 'የሚመጡ የኢትዮጵያ በዓላት');
  String eventsThisMonth(int count) => t('$count event(s) this month', 'በዚህ ወር $count ክስተት(ዎች)');
  String noEventsOnDay(String date) => t('No events on $date', 'በ $date ክስተት የለም');
  String get ethiopianHolidayLabel =>
      t('🇪🇹 Ethiopian Holiday', '🇪🇹 የኢትዮጵያ በዓል');
  String get postedToAnnouncements =>
      t('Posted to announcements', 'በማስታወቂያዎች ተለጠፈ');
  String get willPostToAnnouncements => t(
        'Will post reminder 1 day before and on event day',
        '1 ቀን በፊት እና በክስተት ቀን ማስታወቂያ ይለጠፋል',
        'Guyyaa dura 1 fi guyyaa kana beeksisa ni maxxansama',
      );
  String get postedReminderToAnnouncements => t(
        'Reminder posted to announcements',
        'የቅድመ-ማስታወቂያ ተለጠፈ',
        'Yaadachiisa duraan maxxanfame',
      );
  String get willPostReminderToAnnouncements => t(
        'Reminder will post 1 day before',
        '1 ቀን በፊት የቅድመ-ማስታወቂያ ይለጠፋል',
        'Yaadachiisa guyyaa dura 1 ni maxxansama',
      );
  String get willPostEventDayAnnouncement => t(
        'Event-day announcement will post on the date',
        'በክስተት ቀን ማስታወቂያ ይለጠፋል',
        'Beeksisa guyyaa kana ni maxxansama',
      );
  String get studentsAudience => t('Students', 'ተማሪዎች');

  String audienceLabel(String audience) {
    switch (audience) {
      case 'All':
        return all;
      case 'Parents':
        return parents;
      case 'Teachers':
        return teachers;
      case 'Students':
        return studentsAudience;
      case 'Staff':
        return staffAudience;
      default:
        return announcementAudienceKey(audience);
    }
  }

  String announcementAudienceKey(String key) {
    switch (key) {
      case 'all':
        return all;
      case 'parents':
        return parents;
      case 'teachers':
        return teachers;
      case 'students':
        return studentsAudience;
      case 'transport':
        return transportStaff;
      case 'admin':
        return adminAudience;
      default:
        return key;
    }
  }

  String get transportStaff =>
      t('Transport', 'ትራንስፖርት', 'Geejjiba');
  String get adminAudience =>
      t('Admin', 'አስተዳዳሪ', 'Bulchaa');
  String get announcementPriority =>
      t('Priority', 'ቅድሚያ', 'Dursa');
  String get announcementPriorityNormal =>
      t('Normal', 'መደበኛ', 'Idilee');
  String get announcementPriorityImportant =>
      t('Important', 'አስፈላጊ', 'Barbaachisaa');
  String get announcementPriorityUrgent =>
      t('Urgent', 'አስቸኳይ', 'Hatattamaa');
  String get announcementAttachments =>
      t('Attachments', 'attachments', 'Maxxansa');
  String get announcementAddAttachment =>
      t('Add attachment', 'attachment ጨምር', 'Maxxansa dabaluu');
  String get announcementAttachmentHint => t(
        'Any file type: PDF, Word, Excel, PowerPoint, images, video, audio, ZIP, and more.',
        'Any file: PDF, Word, Excel, PowerPoint, photos, video, audio, ZIP, and more.',
        'Gosa faayilii hunda: PDF, Word, Excel, PowerPoint, suuraa, viidiyoo, sagalee, ZIP fi kan biroo.',
      );
  String get announcementAudienceHint => t(
        'Select who should receive this announcement. You can choose more than one.',
        'ማን እንደሚያገኝ ይምረጡ። ከአንድ በላይ መምረጥ ይቻላል።',
        'Eenyu akka argatu fili. Filannoo dachaa filachuu dandeessa.',
      );
  String get announcementAudienceRequired => t(
        'Select at least one audience',
        'ቢያንስ አንድ ታዳሚ ይምረጡ',
        'Yoo xiqqaate tokko fili',
      );
  String get announcementAttachmentOpenFailed => t(
        'Could not open attachment on this device',
        'attachment መክፈት አልተሳካም',
        'Maxxansa banuun hin danda\'amne',
      );
  String announcementAttachmentCount(int count) => t(
        '$count attachment${count == 1 ? '' : 's'}',
        '$count attachment',
        'Maxxansa $count',
      );

  String monthName(int month) {
    if (isAmharic) {
      const names = [
        'ጥር', 'የካ', 'መጋ', 'ሚያ', 'ግን', 'ሰኔ',
        'ሐም', 'ነሐ', 'መስ', 'ጥቅ', 'ህዳ', 'ታህ',
      ];
      return names[month - 1];
    }
    if (isOromo) {
      const names = [
        'Amajjii', 'Guraandhala', 'Bitooteessa', 'Ebla', 'Caamsa', 'Waxabajjii',
        'Adooleessa', 'Hagayya', 'Fuulbana', 'Onkololeessa', 'Sadaasa', 'Muddee',
      ];
      return names[month - 1];
    }
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }

  String calendarDayHeader(int index) {
    if (isAmharic) {
      const names = ['እሁ', 'ሰኞ', 'ማክ', 'ረቡ', 'ሐሙ', 'ዓር', 'ቅ'];
      return names[index];
    }
    if (isOromo) {
      const names = ['Dil', 'Wix', 'Qib', 'Rob', 'Kam', 'Jim', 'San'];
      return names[index];
    }
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return names[index];
  }

  // —— Attendance ——
  String get takeAttendance =>
      t('Take Attendance', 'መገኘት ይመዝግቡ');
  String childAttendanceTitle(String name) {
    if (isAmharic) return 'የ$name መገኘት';
    if (isOromo) return 'Argama $name';
    return "$name's Attendance";
  }
  String get takeAttendanceTooltip =>
      t('Take attendance', 'መገኘት ይመዝግቡ');
  String get viewHistoryTooltip =>
      t('View history', 'ታሪክ ይመልከቱ');
  String get selectedDate =>
      t('Selected date', 'የተመረጠ ቀን');
  String get change => t('Change', 'ቀይር');
  String conductedByName(String name) =>
      t('Conducted by: $name', 'የተመዘገበ በ: $name');
  String get markAllPresent =>
      t('Mark All Present', 'ሁሉንም ተገኝቷል ምልክት');
  String get close => t('Close', 'ዝጋ');
  String noAttendanceHistory(String className) => t('No attendance history for $className', 'ለ$className የመገኘት ታሪክ የለም');
  String attendanceSavedFor(String className, String conductor) => t('Attendance saved for $className by $conductor', 'መገኘት ለ $className በ $conductor ተቀምጧል');
  String historyPresentLateAbsent(int present, int late, int absent) =>
      t('Present: $present · Late: $late · Absent: $absent', 'ተገኝ: $present · ዘግ: $late · ጠፍ: $absent');
  String historyConductedBy(String name) =>
      t('Conducted by $name', 'የተመዘገበ በ $name');

  // —— Announcements ——
  String get announcement => t('Announcement', 'ማስታወቂያ');
  String get newShort => t('New', 'አዲስ');
  String get newAnnouncement =>
      t('New Announcement', 'አዲስ ማስታወቂያ');
  String get pinned => t('Pinned', 'ተሰቅሏል');
  String postedOn(String date) =>
      t('Posted $date', 'ተለጠፈ $date');
  String get messageLabel => t('Message', 'መልዕክት');
  String get titleMessageRequired => t('Title and message are required', 'ርዕስ እና መልዕክት ያስፈልጋል');
  String get publishAnnouncementFull => t('Publish Announcement', 'ማስታወቂያ ለጥፍ');

  // —— Fees ——
  String get finance => t('Finance', 'ፋይናንስ');
  String get comingSoon =>
      t('Coming soon', 'በቅርቡ ይመጣል', 'Fuulduraaf dhufaa jira');
  String get financeComingSoonSubtitle => t(
        'School finance & payments hub',
        'የትምህርት ቤት ፋይናንስ እና ክፍያ',
        'Giddugala faayinaansii fi kaffaltii mana barumsaa',
      );
  String get financeComingSoonDescription => t(
        'We are building a complete finance module for fee tracking, invoicing, collections, and reports — all in one place.',
        'የክፍያ መከታተያ፣ መጠየቂያ፣ ገቢ ስብስብ እና ሪፖርትን በአንድ ቦታ ለማቅረብ ሙሉ ፋይናንስ ሞዱል እየገነባን ነው።',
        'Modulee faayinaansii guutuu hojii hordoffii kaffaltii, waraqaa kaffaltii, walitti qabamaa fi gabaasaaf ijaaraa jirra.',
      );
  String get financePlannedFeatures => t(
        'Planned capabilities',
        'የታቀዱ ችሎታዎች',
        'Dandeettiiwwan karoorfaman',
      );
  String get financeFeatureFees => t('Fee management', 'የክፍያ አስተዳደር', 'Bulchiinsa kaffaltii');
  String get financeFeatureFeesHint => t(
        'Terms, schedules, and student balances',
        'ወቅቶች፣ መርሃ ግብሮች እና ቀሪ ሂሳቦች',
        'Yeroo, sagantaa fi haftee barataa',
      );
  String get financeFeatureInvoices =>
      t('Invoices & billing', 'መጠየቂያዎች', 'Waraqaa kaffaltii');
  String get financeFeatureInvoicesHint => t(
        'Generate and send fee invoices',
        'የክፍያ መጠየቂያ መፍጠር እና መላክ',
        'Waraqaa kaffaltii uumuun erguu',
      );
  String get financeFeaturePayments =>
      t('Payment tracking', 'የክፍያ መከታተያ', 'Hordoffii kaffaltii');
  String get financeFeaturePaymentsHint => t(
        'Telebirr, bank, and cash reconciliation',
        'ቴሌብር፣ ባንክ እና ጥሬ ገንዘብ ማጣጣም',
        'Telebirr, baankii fi qarshii wal simsiisuu',
      );
  String get financeFeatureReports =>
      t('Reports & analytics', 'ሪፖርት እና ትንተና', 'Gabaasa fi xiinxala');
  String get financeFeatureReportsHint => t(
        'Collections, overdue, and term summaries',
        'ገቢ፣ ያለፈ ጊዜ ክፍያዎች እና ወቅታዊ ማጠቃለያ',
        'Walitti qabamaa, kaffaltii darbee fi cuunfaa',
      );
  String get financeInDevelopment =>
      t('In active development', 'በንቃት እየተገነባ ነው', 'Hojii ijaarsaa irra jira');
  String get financeComingSoonNote => t(
        'This module will roll out in a future update. Parent fee payments remain available from the parent dashboard.',
        'ይህ ሞዱል በቅርቡ ይገኛል። የወላጅ ክፍያ በወላጅ መተግበሪያ ይገኛል።',
        'Moduleen kun fooyya’iinsa fuulduraatiin ni dhufa. Kaffaltii maatii irraa daashboordii maatii argamuu danda’a.',
      );
  String get outstanding => t('Outstanding', 'ያልተከፈለ');
  String get paidTab => t('Paid', 'ተከፍሏል');
  String get paymentSummary =>
      t('Payment Summary', 'የክፍያ ማጠቃለያ');
  String get summary => t('Summary', 'ማጠቃለያ', 'Cuunfaa');
  String get totalLabel => t('Total', 'ጠቅላላ', 'Ida\'ama');
  String etbDue(double amount) => t('${amount.toStringAsFixed(0)} ETB due', '${amount.toStringAsFixed(0)} ብር ይቀርባል');
  String get overdueLabel => t('Overdue', 'ያለፈ ጊዜ');
  String get noRecordsHere =>
      t('No records here', 'መዝገብ የለም');
  String get pending => t('Pending', 'በመጠባበቅ');
  String get overdue => t('Overdue', 'ያለፈ ጊዜ');
  String studentLabel(String name) =>
      t('Student: $name', 'ተማሪ: $name');
  String paidOn(String date, String method) => t('Paid $date via $method', 'ተከፍሏል $date በ $method');
  String dueOn(String date) =>
      t('Due $date', 'መክፈያ $date');
  String get payNow => t('Pay Now', 'አሁን ይክፈሉ');
  String payFeeTitle(String title) =>
      t('Pay $title', '$title ይክፈሉ');
  String get telebirr => 'Telebirr';
  String get bankTransfer =>
      t('Bank Transfer', 'ባንክ ማስተላለፍ');
  String get cashAtSchool =>
      t('Cash at School', 'በትምህርት ቤት ጥሬ ገንዘብ');
  String paymentSuccessVia(String method) => t('Payment successful via $method', 'ክፍያ በ $method ተሳክቷል');
  String get paymentFailed =>
      t('Payment failed. Please try again.', 'ክፍያ አልተሳካም። እንደገና ይሞክሩ።');
  String overdueItems(int count) => t('$count items', '$count ያለፉ');

  // —— Bus Tracking ——
  String get myRoute => t('My Route', 'መስመሬ');
  String get googleMap => t('Google Map', 'Google ካርታ');
  String get trackBusFor =>
      t('Track bus for', 'አውቶቡስን ለ');
  String driverLabel(String name) =>
      t('Transport: $name', 'ትራንስፖርት: $name');
  String stopLabel(String name) =>
      t('Stop: $name', 'መና: $name');
  String etaMin(int min) =>
      t('ETA: ~$min min', 'ETA: ~$min ደቂቃ');
  String get busReachedSchoolSafely => t('Bus has reached school safely', 'አውቶቡስ በደህና ትምህርት ቤት ደርሷል');
  String get liveRoute => t('Live Route', 'ቀጥታ መስመር');
  String scheduledAt(String time) =>
      t('Scheduled: $time', 'ቀጠሮ: $time');
  String studentsAtStop(String names) =>
      t('Students: $names', 'ተማሪዎች: $names');
  String get driverControls =>
      t('Transport Controls', 'የትራንስፖርት ቁጥጥር');
  String get startRoute =>
      t('Start Route', 'መስመር ጀምር');
  String get stopMarkedComplete =>
      t('Stop marked complete', 'መና ተጠናቋል');
  String get completeCurrentStop =>
      t('Complete Current Stop', 'አሁን ያለ መና አጠናቅ');
  String get endRouteAtSchool =>
      t('End Route at School', 'በትምህርት ቤት መስመር አቁም');
  String get routeCompletedToday =>
      t('Route completed for today', 'የዛሬ መስመር ተጠናቋል');

  // —— QR ——
  String get scannerTab => t('Scanner', 'ስካነር');
  String get studentQrCodes =>
      t('Student QR Codes', 'የተማሪ QR ኮዶች');
  String get showQrAtGate => t('Show this QR at school gate for quick entry/exit', 'በትምህርት ቤት በር ለፈጣን መግቢያ/መውጫ ይህን QR አሳዩ');
  String get generateStudentQr => t(
        'Generate / View QR Code',
        'QR ኮድ ፍጠር / ይመልከቱ',
      );
  String get scanStudentQr => t(
        'Scan student QR',
        'የተማሪ QR ይስካን',
      );
  String get qrScannerAlignHint => t(
        'Align the student QR inside the frame for instant profile lookup.',
        'የተማሪ QR ኮድን በፍሬሙ ውስጥ ለፈጣን ፕሮፋይል መዳረሻ ያስተካክሉ።',
      );
  String get invalidStudentQr => t(
        'Invalid student QR code',
        'ልክ ያልሆነ የተማሪ QR ኮድ',
      );
  String get studentQrUsageHint => t(
        'Use for bus boarding, discharge, class attendance, and quick profile access.',
        'ለአውቶቡስ መውጣት/መውረጃ፣ የክፍል መገኘት እና ፈጣን የፕሮፋይል መዳረሻ ይጠቀሙ።',
      );
  String get cameraScannerAvailable => t('Camera scanner available on Android & iOS', 'ካሜራ ስካነር በ Android እና iOS ላይ ይገኛል');
  String get qrScannerStartError => t(
        'Unable to start the camera scanner. Please try again.',
        'ካሜራ ስካነር መከፈት አልተቻለም። እንደገና ይሞክሩ።',
      );
  String get cameraPermissionRequired => t(
        'Camera permission is required to scan QR codes. Enable it in phone settings, then tap Try again.',
        'QR ኮዶችን ለመቃኘት የካሜራ ፈቃድ ያስፈልጋል። በስልክ ቅንብሮች ውስጥ ያንቁና «እንደገና ይሞክሩ» ይጫኑ።',
      );
  String get cameraStarting => t('Starting camera…', 'ካሜራ በመከፈት ላይ…');
  String get tryAgain => t('Try again', 'እንደገና ይሞክሩ');
  String get manualCheckIn =>
      t('Manual check-in (for testing)', 'በእጅ መግቢያ (ለሙከራ)');
  String get selectStudent =>
      t('Select student', 'ተማሪ ይምረጡ');
  String recordAction(String action) =>
      t('Record $action', '$action ይመዝግቡ');
  String get noScansYet =>
      t('No scans yet', 'ስካን የለም');
  String scanRecordedFor(String name, String action) => t('$name — $action recorded', '$name — $action ተመዝግቧል');

  // —— My Children ——
  String get teacherLabelShort =>
      t('Teacher', 'መምህር');
  String teacherOf(String name) =>
      t('Teacher: $name', 'መምህር: $name');
  String get viewAttendance =>
      t('View Attendance', 'መገኘት ይመልከቱ');
  String get viewGradeReport =>
      t('View Grade Report', 'የደረጃ ሪፖርት ይመልከቱ');
  String get viewHomework =>
      t('View Homework', 'የቤት ስራ ይመልከቱ');
  String get teachersTab => t('Teachers', 'መምህራን');
  String get otherStaffTab => t('Other staff', 'ሌሎች ሰራተኞች', 'Hojjetoota biroo');
  String get adminsTab => t('Admins', 'አስተዳዳሪዎች');
  String get driversTab => t('Transport', 'ትራንስፖርት');
  String get addStaffRecord =>
      t('Add staff record', 'የሰራተኛ መዝገብ ጨምር', 'Galmee hojjetootaa dabali');
  String get noEmployeeRecords => t(
        'No staff records yet. Tap Add to register non-login staff.',
        'የሰራተኛ መዝገብ የለም። መግቢያ የሌላቸውን ሰራተኞች ለመመዝገብ ጨምር ይጫኑ።',
        'Galmeen hojjetootaa hin jiru. Hojjetoota login hin qabne galmeessuuf Dabali tuqi.',
      );
  String studentsInClass(int count) => t('$count students', '$count ተማሪዎች');
  String get viewAttendanceReport => t('View attendance report', 'የመገኘት ሪፖርት ይመልከቱ');
  String attendanceThisTerm(int pct) => t('$pct% this term', 'በዚህ ወቅት $pct%');
  String get attendanceReportsTitle =>
      t('Attendance Reports', 'የመገኘት ሪፖርቶች', 'Gabaasawwan Argamaa');
  String get generatedReport =>
      t('Generated report', 'የተፈጠረ ሪፖርት', 'Gabaasa uumame');
  String get readOnlyReportHint => t(
        'This report is generated from teacher attendance and cannot be edited.',
        'ይህ ሪፖርት ከመምህራን መገኘት የተፈጠረ ሲሆን ሊስተካከል አይችልም።',
        'Gabaasni kun argama barsiisotaa irraa uumamee jira; gulaalamuu hin danda\'u.',
      );
  String get teachersRecordedAttendance => t(
        'Teachers who recorded attendance',
        'መገኘት ያስመዘገቡ መምህራን',
        'Barsiisota argama galchitan',
      );
  String get noAttendanceReportForDay => t(
        'No attendance recorded for this day',
        'ለዚህ ቀን መገኘት አልተመዘገበም',
        'Guyyaa kanaaf argamni hin galmoofne',
      );
  String get absents => t('Absents', 'የጠፉ', 'Hin argamne');
  String get lateArrivals => t('Late', 'ዘግይተው', 'Deebi\'aa');
  String get presentToday => t('Present', 'ተገኝተዋል', 'Argaman');
  String attendanceSummaryCounts(int absent, int late, int present) => t(
        '$absent absent · $late late · $present present',
        '$absent ጠፍ · $late ዘግ · $present ተገኝ',
        '$absent hin argamne · $late debi\'aa · $present argaman',
      );
  String gradeAbsentCount(String grade, int count) => t(
        '$grade · $count absent',
        '$grade · $count ጠፍ',
        '$grade · $count hin argamne',
      );
  String gradeLateCount(String grade, int count) => t(
        '$grade · $count late',
        '$grade · $count ዘግ',
        '$grade · $count debi\'aa',
      );
  String gradePresentCount(String grade, int count) => t(
        '$grade · $count present',
        '$grade · $count ተገኝ',
        '$grade · $count argaman',
      );
  String studentsWithStatus(int count, String statusLabel) => t(
        '$count students $statusLabel',
        '$count ተማሪዎች $statusLabel',
        'Barattoonni $count $statusLabel',
      );
  String get tapGradeToInvestigate => t(
        'Tap a grade to see student details',
        'ዝርዝር ለማየት ክፍል ይንኩ',
        'Bal\'ina barattootaa argachuuf sadarkaa tuqi',
      );
  String get exportAttendanceExcel =>
      t('Export Excel', 'Excel ላክ', 'Excel baasi');
  String get exportAttendanceTitle => t(
        'Export attendance report',
        'የመገኘት ሪፖርት Excel ላክ',
        'Gabaasa argamaa Excel baasi',
      );
  String get exportAttendanceChooseDate => t(
        'Choose the date range for the export file',
        'ለማስመጣት የቀን ክልል ይምረጡ',
        'Daangii guyyaa gabaasa baasuuf filadhu',
      );
  String get exportLast30Days =>
      t('Last 30 days', 'ያለፉ 30 ቀናት', 'Guyyoota 30 darban');
  String get exportFromDate => t('From date', 'ከቀን', 'Guyyaa jalqabaa');
  String get exportToDate => t('To date', 'እስከ', 'Guyyaa xumuraa');
  String get exportDateRangeInvalid => t(
        'From date must be on or before to date',
        'የመጀመሪያ ቀን ከመጨረሻ ቀን በፊት ወይም እኩል መሆን አለበት',
        'Guyyaan jalqabaa guyyaa xumuraa dura ykn wal qixa ta\'uu qaba',
      );
  String get exportAttendanceDailySheet =>
      t('Daily totals', 'ዕለታዊ ድምር', 'Ida\'ama guyyaa guyyaa');
  String get exportDaysWithRecords => t(
        'Days with attendance',
        'መገኘት የተመዘገበባቸው ቀናት',
        'Guyyoota argamni galmaa\'e',
      );
  String get exportAttendanceShareTitle => t(
        'Download or share report',
        'ሪፖርት አውርድ ወይም አጋራ',
        'Gabaasa buufadhu ykn qoodi',
      );
  String get exportAttendanceShareHint => t(
        'Save the Excel file or send it to management',
        'Excel ፋይሉን አስቀምጥ ወይም ለአመራር ላክ',
        'Faayilii Excel kuusi ykn bulchiinsaaf ergi',
      );
  String get sendViaEmail => t('Email', 'ኢሜይል', 'Imeelii');
  String attendanceDownloadedTo(String path) => t(
        'Saved to $path',
        'ወደ $path ተቀምጧል',
        'Gara $path kuufame',
      );
  String get exportAttendanceSuccess => t(
        'Attendance Excel file ready to share',
        'የመገኘት Excel ፋይል ለማጋራት ዝግጁ ነው',
        'Faayilii Excel argamaa qooduuf qophaa\'e',
      );
  String get exportAttendanceIosSaveHint => t(
        'Choose Save to Files, Excel, or Numbers to open the report',
        'ሪፖርቱን ለመክፈት Save to Files፣ Excel ወይም Numbers ይምረጡ',
        'Gabaasa banuuf Save to Files, Excel ykn Numbers filadhu',
      );
  String get exportAttendanceFailed => t(
        'Export failed. Please try again.',
        'ማስመጣት አልተሳካም። እንደገና ይሞክሩ።',
        'Baasuu hin milkoofne. Irra deebi\'i yaali.',
      );
  String get exportAttendanceSummarySheet =>
      t('Summary', 'ማጠቃለያ', 'Cuunfaa');
  String get exportAttendanceDetailsSheet =>
      t('Student details', 'የተማሪ ዝርዝር', 'Bal\'ina barattootaa');
  String get exportStudentColumn => t('Student', 'ተማሪ', 'Barataa');
  String get exportTeacherColumn => t('Teacher', 'መምህር', 'Barsiisaa');

  // —— Daily Activities ——
  String get dailyReport =>
      t('Daily report', 'ዕለታዊ ሪፖርት');
  String get todaysActivities =>
      t("Today's Activities", 'የዛሬ እንቅስቃሴዎች', 'Sochiiwwan Har\'aa');
  String get teacherCommentLabel =>
      t('Teacher comment', 'የመምህር አስተያየት');
  String get teacherCommentHint => t(
        "Add notes about today's activities...",
        'ስለ ዛሬው እንቅስቃሴ ማስታወሻ...',
        'Waa\'ee sochiiwwan har\'aa yaadannoo dabaluu...',
      );
  String get parentCommentLabel =>
      t('Parent comment', 'የወላጅ አስተያየት');
  String get yourCommentOptional =>
      t('Your comment (optional)', 'አስተያየትዎ (አማራጭ)');
  String get saveReport =>
      t('Save Report', 'ሪፖርት አስቀምጥ');
  String get noReportForDay =>
      t('No report for this day yet', 'ለዚህ ቀን ሪፖርት የለም');
  String get parentNotifiedViewed => t('Teacher has been notified that you viewed this report', 'ሪፖርቱን እንዳዩት ለመምህሩ ተሳውቋል');
  String get youViewedReport =>
      t('You viewed this report', 'ይህን ሪፖርት አይተዋል');
  String get parentSeenReport =>
      t('Parent has seen this report', 'ወላጅ ሪፖርቱን አይቷል');
  String parentViewedOn(String name, String date) => t('$name viewed on $date', '$name በ $date አይቷል');
  String get waitingForParentView =>
      t('Waiting for parent to view', 'ወላጅ እስኪያይ ድረስ በመጠባበቅ');
  String get parentWillTapSeen => t('Parent will tap "I Have Seen This Report" on their app', 'ወላጅ በመተግበሪያው "ይህን ሪፖርት አይቻለሁ" ይጫናል');
  String get dailyReportSaved => t('Daily activity report saved', 'ዕለታዊ ሪፖርት ተቀምጧል');
  String seenByOn(String name, String date) => t('Seen by $name on $date', '$name በ $date አይቷል');

  // —— Enrollment Phase 1 ——
  String get registerSchool =>
      t('Register Your School', 'ትምህርት ቤት ይመዝግቡ');
  String get registerSchoolIntro => t(
        'Register your school to get a unique School ID, then add administration staff and students.',
        'ትምህርት ቤትዎን ይመዝግቡ እና ልዩ School ID ይቀበሉ። ከዚያ የአስተዳደር ሰራተኞችን እና ተማሪዎችን ይጨምራሉ።',
        'Mana barumsaa keessan galmeessaa School ID addaa argadhaa, sana booda hojjettoota bulchiinsaa fi barattoota dabalaa.',
      );
  String get schoolDetails =>
      t('School Details', 'የትምህርት ቤት መረጃ');
  String get schoolNameLabel =>
      t('School Name', 'የትምህርት ቤት ስም');
  String get city => t('City', 'ከተማ');
  String get academicYear =>
      t('Academic Year', 'የትምህርት ዓመት');
  String get gradeLevelsHint => t('Grade levels (comma-separated)', 'ክፍሎች (comma-separated)');
  String get sectionsHint => t('Sections (Grade 1A, Grade 1B...)', 'ሴክሽኖች (Grade 1A, Grade 1B...)');
  String get principalAccount =>
      t('Principal / Admin Account', 'የአስተዳዳሪ/ዋና መምህር መለያ');
  String get username => t('Username', 'የተጠቃሚ ስም');
  String get createSchool =>
      t('Create School', 'ትምህርት ቤት ፍጠር');
  String get schoolRegistered => t('School Registered!', 'ትምህርት ቤት ተመዝግቧል!');
  String get saveSchoolIdHint => t('Save this School ID — teachers and parents will need it.', 'School ID ይህንን ያስቀምጡ — መምህራን እና ወላጆች ይጠቀሙበታል።');
  String get registerAsParent =>
      t('Register as Parent', 'በወላጅነት ይመዝገቡ');
  String get parentSignupIntro => t('Your child must already exist in the school database. Enter School ID + Student ID + date of birth.', 'ተማሪው በትምህርት ቤቱ database ላይ መጀመሪያ መኖር አለበት። School ID + Student ID + የልደት ቀን ያስገቡ።');
  String get linkToStudent =>
      t('Link to Student', 'ከተማሪ ጋር ያገናኙ');
  String get studentDateOfBirth =>
      t('Student Date of Birth', 'የተማሪ የልደት ቀን');
  String get dateFormatHint =>
      t('DD/MM/YYYY', 'DD/MM/YYYY');
  String get verifyStudent =>
      t('Verify Student', 'ተማሪ አረጋግጥ');
  String get studentVerified =>
      t('Student verified ✓', 'ተማሪ ተረጋግጧል ✓');
  String get studentVerifyFailed => t('Verification failed — check School ID, Student ID, or date of birth', 'ማረጋገጫ አልተሳካም — School ID, Student ID ወይም ቀን ስህተት');
  String get verifyStudentFirst => t('Please verify the student first', 'መጀመሪያ ተማሪውን ያረጋግጡ');
  String get yourAccount =>
      t('Your Account', 'የእርስዎ መለያ');
  String get relationship =>
      t('Relationship', 'ግንኙነት');
  String get usernameOptional => t('Username (optional)', 'የተጠቃሚ ስም (አማራጭ)');
  String get parentPendingApprovalMessage => t('Account created. Your school or homeroom teacher must approve your access before you can view full data.', 'መለያዎ ተፈጥሯል። የትምህርት ቤቱ ወይም የክፍል መምህር ከመጣትዎ በኋላ ይፈቀዳል።');
  String get pendingApproval =>
      t('Pending Approval', 'መጽደቅ በመጠበቅ ላይ');
  String get pendingApprovalTitle => t('Your access request is pending', 'የመዳረሻ ጥያቄዎ በመጠበቅ ላይ ነው');
  String get pendingApprovalBody => t('The school admin or your child\'s homeroom teacher will verify the link. Until approved, access is limited.', 'የትምህርት ቤቱ ወይም የልጅዎን ክፍል የሚያስተዳድረው መምህር ያረጋግጣል። እስከ መጽደቅ ድረስ ገደብ ያለ መዳረሻ ይኖርዎታል።');
  String get parentApprovals =>
      t('Parent Approvals', 'የወላጅ ጥያቄዎች');
  String get noPendingApprovals =>
      t('No pending requests', 'በመጠበቅ ላይ ያለ ጥያቄ የለም');
  String get approve => t('Approve', 'አጽድቅ');
  String get reject => t('Reject', 'አስቀር');
  String get parentApproved => t('Parent request approved', 'ወላጅ ጥያቄ ተጽድቋል');
  String get addTeacher => t(
        'Add Administration Staff',
        'የአስተዳደር ሰራተኛ ጨምር',
        'Hojjettaa Bulchiinsaa Dabaluu',
      );
  String get addStudent =>
      t('Add Student', 'ተማሪ ጨምር');
  String get employeeId =>
      t('Staff ID', 'የሰራተኛ መለያ', 'ID Hojjettootaa');
  String get employeeIdOptional =>
      t('Staff ID (optional)', 'የሰራተኛ መለያ (አማራጭ)', 'ID Hojjettootaa (filannoo)');
  String get teacherPhotoHint =>
      t('Tap to add teacher photo', 'የመምህር ፎቶ ለመጨመር ይንኩ');
  String get sendLoginToTeacher =>
      t('Send login to teacher', 'መግቢያ ለመምህር ላክ');
  String get sendLoginToDriver =>
      t('Send login to driver', 'ለሾፌር መግቢያ ላክ', 'Gara konkolaachisaa seensaa ergi');
  String get sendLoginNoPhoneDriver => t(
        'No phone number on file. Use Share to send the login details manually.',
        'ስልክ ቁጥር የለም። መግቢያ መረጃውን በShare ይላኩ።',
        'Lakkoofsi bilbilaa hin jiru. Bal\'ina seensaa share\'n qoodi.',
      );
  String get savedLoginDetails =>
      t('Saved login', 'የተቀመጠ መግቢያ', 'Seensa kuufame');
  String get driverCredentialsSaved => t(
        'Saved on this profile so you can share login again if the driver loses it.',
        'ሾፌሩ ከሳለ የመግቢያ መረጃውን እንደገና ለመስጠት እዚህ ተቀምጧል።',
        'Konkolaachisni yoo badde bal\'ina seensaa irra deebi\'anii qooduuf as kuufame.',
      );
  String driverLoginSent(String channel) => t(
        'Opened $channel with transport login message',
        '$channel በትራንስፖርት መግቢያ መልዕክት ተከፍቷል',
        '$channel ergaa seensaa geejjibaa waliin baname',
      );
  String get teacherCredentialsSaved =>
      t('Login details saved on this teacher profile.', 'የመግቢያ መረጃ ተቀምጧል።');
  String get staffSavedSuccessfully => t(
        'Saved successfully. Staff count on your dashboard will update.',
        'በተሳካ ሁኔታ ተቀምጧል። የሰራተኞች ብዛት በዳሽቦርድ ይዘምናል።',
        'Milkaa\'inaan kuufame. Lakkoofsi hojjettootaa daashboordii ni haaromsa.',
      );
  String get loginUsername =>
      t('Login Username', 'የመግቢያ ተጠቃሚ ስም');
  String get tempPassword =>
      t('Temporary password', 'ጊዜያዊ የይለፍ ቃል');
  String get teacherCreated =>
      t('Teacher Created', 'መምህር ተፈጥሯል');
  String get createTeacherAccount => t('Create Teacher Account', 'መምህር መለያ ፍጠር');
  String get addTransportStaff =>
      t('Add Transport Staff', 'የትራንስፖርት ሰራተኛ ጨምር');
  String get createDriverAccount =>
      t('Create Transport Account', 'የትራንስፖርት መለያ ፍጠር');
  String get driverCreated =>
      t('Transport Staff Created', 'የትራንስፖርት ሰራተኛ ተፈጥሯል');
  String get driverPhotoHint =>
      t('Tap to add driver photo', 'የሾፌር ፎቶ ለመጨመር ይንኩ');
  String get routeNameHint =>
      t('e.g. Bole → Megenagna → School', 'ለምሳሌ Bole → Megenagna → School');
  String get routePathHint => t(
        'From → through → to — helps parents and staff identify the exact bus path.',
        'ከ → በ → ወደ — ወላጆችና ሰራተኞች የአውቶቡስ መስመር እንዲለዩ ይረዳል።',
        'Ka\'ee → keessa → gara — maatii fi hojjettoonni karaa autobusii adda baasu.',
      );
  String get routeFrom =>
      t('Route from', 'መስመር ከ', 'Ka\'ee geejjibaa');
  String get routeTo =>
      t('Route to', 'መስመር ወደ', 'Gara geejjibaa');
  String get routeFromHint =>
      t('e.g. Bole', 'ለምሳ. Bole', 'fkn. Bole');
  String get routeThrough =>
      t('Route through', 'መስመር በ', 'Karaa keessa');
  String get routeThroughHint =>
      t('e.g. Megenagna', 'ለምሳ. Megenagna', 'fkn. Megenagna');
  String get routeToHint =>
      t('e.g. School', 'ለምሳ. School', 'fkn. Mana barumsaa');
  String get transportRouteRequired => t(
        'Please enter route from, through, and to',
        'መስመር ከ፣ በ፣ እና ወደ ያስገቡ',
        'Ka\'ee, keessa, fi gara geejjibaa galchi',
      );
  String get transportPlateRequired => t(
        'Please enter the plate number',
        'የሰሌዳ ቁጥር ያስገቡ',
        'Lakkoofsa gabatee galchi',
      );
  String get busNumberHint => t('e.g. Bus 12', 'ለምሳሌ Bus 12');
  String get busNumberRequired => t(
        'Enter the bus number for this route.',
        'ለዚህ መስመር የአውቶቡስ ቁጥር ያስገቡ።',
        'Lakkoofsa autobusii karaa kanaaf galchi.',
      );
  String get busLinkId => t(
        'Bus Link ID',
        'የአውቶቡስ መያያዣ መለያ',
        'ID Walitti hidhamuu Autobusii',
      );
  String get busLinkIdAutoHint => t(
        'A Bus Link ID (e.g. BUS-1004) is created automatically and links this bus number to the driver and parents.',
        'የአውቶቡስ መያያዣ መለያ (ለምሳ. BUS-1004) በራስ-ሰር ይፈጠራል እና የአውቶቡስ ቁጥሩን ከአሽከርካሪው እና ከወላጆች ጋር ያገናኛል።',
        'ID walitti hidhamuu autobusii (fkn. BUS-1004) ofiin uumama — lakkoofsa autobusii konkolaachisaa fi maatiin waliin wal qunnamsiisa.',
      );
  String get busLinkIdStudentHint => t(
        'e.g. BUS-1001',
        'ለምሳ. BUS-1001',
        'fkn. BUS-1001',
      );
  String get busLinkIdOptionalHint => t(
        'Optional now — share the Bus Link ID with parents to connect bus tracking.',
        'አሁን አማራጭ — የአውቶቡስ መያያዣ መለያውን ለወላጆች ያጋሩ።',
        'Amma filannoo — ID walitti hidhamuu autobusii maatiif qoodaa.',
      );
  String get selectRegisteredBus => t(
        'Select registered bus',
        'የተመዘገበ አውቶቡስ ይምረጡ',
        'Autobusii galmeeffame filadhu',
      );
  String get lookupBus => t('Verify bus ID', 'የአውቶቡስ መለያ ያረጋግጡ', 'ID autobusii mirkaneessi');
  String transportBusNotRegisteredWithId(String id) => t(
        'There is no registered bus with ID $id',
        'በ $id መለያ የተመዘገበ አውቶቡስ የለም',
        'Autobusii galmeeffame ID $id tiin hin jiru',
      );
  String transportBusRegisteredLabel(
    String busId,
    String busNumber,
    String driverName, [
    String routeName = '',
  ]) {
    final route = routeName.trim();
    final routePart = route.isEmpty ? '' : ' · $route';
    return t(
      'Registered bus: $busId · $busNumber$routePart · driver $driverName',
      'የተመዘገበ አውቶቡስ: $busId · $busNumber$routePart · አሽከርካሪ $driverName',
      'Autobusii galmeeffame: $busId · $busNumber$routePart · konkolaachisaa $driverName',
    );
  }
  String get plateNumberHint =>
      t('e.g. AA-3-45678', 'ለምሳሌ AA-3-45678');
  String get editDriver => t('Edit transport staff', 'የትራንስፖርት ሰራተኛ አርትዕ');
  String get deactivateDriver =>
      t('Deactivate transport staff', 'የትራንስፖርት ሰራተኛ አቦዝን');
  String get confirmDeactivateDriver => t(
        'Remove this driver from active transport staff? They will no longer appear on routes.',
        'ይህን ሾፌር ከንቁ የትራንስፖርት ሰራተኞች ይወገድ?',
      );
  String get driverDeactivated =>
      t('Transport staff deactivated', 'የትራንስፖርት ሰራተኛ ተቦዝኗል');
  String get noTransportStaff =>
      t('No transport staff yet. Tap Add to register a driver.', 'የትራንስፖርት ሰራተኛ የለም። ለመመዝገብ ጨምር ይጫኑ።');
  String get driverUpdated =>
      t('Transport staff updated', 'የትራንስፖርት ሰራተኛ ተዘምኗል');
  String get transportDetails =>
      t('Bus & route details', 'የአውቶቡስ እና መስመር መረጃ');
  String get teacherRoles =>
      t('Roles', 'ሚናዎች');
  String get studentEnrolled =>
      t('Student Enrolled', 'ተማሪ ተመዝግቧል');
  String get enrollStudent =>
      t('Enroll Student', 'ተማሪ መዝግብ');
  String get gender => t('Gender', 'ጾታ');
  String get genderMale => t('Male', 'ወንድ');
  String get genderFemale => t('Female', 'ሴት');
  String get selectGender => t('Please select gender', 'ጾታ ይምረጡ');
  String get studentPhotoHint =>
      t('Tap to add student photo', 'የተማሪ ፎቶ ለመጨመር ይንኩ');
  String get fatherDetails => t('Father', 'አባት');
  String get fatherName => t("Father's name", 'የአባት ስም');
  String get fatherPhone => t("Father's phone", 'የአባት ስልክ');
  String get motherDetails => t('Mother', 'እናት');
  String get motherName => t("Mother's name", 'የእናት ስም');
  String get motherPhone => t("Mother's phone", 'የእናት ስልክ');
  String get guardianDetailsOptional =>
      t('Guardian (if any)', 'አሳዳጊ (ካለ)');
  String get guardianNameOptional =>
      t('Guardian name (optional)', 'የአሳዳጊ ስም (አማራጭ)');
  String get guardianPhoneOptional =>
      t('Guardian phone (optional)', 'የአሳዳጊ ስልክ (አማራጭ)');
  String get schoolEnrollmentDetails =>
      t('School enrollment', 'የትምህርት ቤት መዝገብ');
  String get homeroomTeacherId =>
      t('Homeroom teacher ID', 'የክፍል መምህር መለያ');
  String get teacherNotFoundForSchool =>
      t('Teacher not found for this school', 'መምህር አልተገኘም');
  String get emergencyContactsSection =>
      t('Emergency contacts (optional)', 'ድንገተኛ ግንኙነት (አማራጭ)');
  String get emergencyContactName =>
      t('Contact name (parent/guardian)', 'ስም (ወላጅ/አሳዳጊ)');
  String get emergencyPhone => t('Phone number', 'ስልክ');
  String get sendInviteToContacts =>
      t('Send invite to contacts', 'ግብዣ ለግንኙነቶች ላክ');
  String get contactNumbersOnFile =>
      t('numbers on file', 'ቁጥሮች');
  String get sendAllViaSms => t('Send SMS to all contacts', 'SMS ለሁሉም ላክ');
  String get sendAllViaSmsHint => t(
        'Opens SMS for each number, one at a time',
        'ለእያንዳንዱ ቁጥር SMS በተራ ይከፍታል',
      );
  String inviteBulkContactsDone(int sent, int skipped) => t(
        'Opened invite on $sent contact(s)${skipped > 0 ? ', $skipped skipped' : ''}',
        'ግብዣ በ$sent ግንኙነት(ዎች) ተከፍቷል${skipped > 0 ? ', $skipped ተዘግተዋል' : ''}',
      );
  String get sendInviteNextContactTitle =>
      t('Send to next contact?', 'ለሌላው ግንኙነት ላክ?');
  String sendInviteNextContactBody(String label, String phone) => t(
        'After you send the message, tap Continue to open the next contact.\n\n$label · $phone',
        'መልዕክቱን ከላኩ በኋላ Continue ይጫኑ።\n\n$label · $phone',
      );
  String get sendInviteContinue => t('Continue', 'Continue');
  String get sendInviteSkipRemaining =>
      t('Skip remaining', 'የቀሩትን ዝለል');
  String get gradeSectionHint =>
      t('e.g. Grade 4 and section A → Grade 4A', 'ለምሳ. Grade 4 እና A → Grade 4A');
  String get gradeSectionRequired =>
      t('Please enter grade and section', 'ክፍል እና ሴክሽን ያስገቡ');
  String get section => t('Section', 'ሴክሽን');
  String get emergencyContact =>
      t('Emergency Contact', 'ድንገተኛ ግንኙነት');
  String get transportEnabled =>
      t('Uses school transport', 'ትራንስፖርት አለ');
  String get transportNotEnabled =>
      t('Not enabled', 'አልተነቃም');
  String get schoolTransportId =>
      t('School Transport ID', 'የትምህርት ቤት ትራንስፖርት መለያ', 'ID Geejjiba Mana Barumsaa');
  String get schoolTransportIdHint => t(
        'Share this ID with parents when linking students to bus tracking.',
        'ተማሪዎችን ከአውቶቡስ መከታተል ጋር ሲያገናኙ ይህን መለያ ለወላጆች ያጋሩ።',
        'ID kana maatii waliin qoodaa yeroo hordoffii autobusii waliin wal qunnamtisan.',
      );
  String get schoolTransportIdAutoHint => t(
        'A unique School Transport ID (e.g. DRV-1004) is created automatically when you save.',
        'ልዩ የትምህርት ቤት ትራንስፖርት መለያ (ለምሳ. DRV-1004) በሚቀምጡበት ጊዜ በራስ-ሰር ይፈጠራል።',
        'ID geejjiba mana barumsaa addaa (fkn. DRV-1004) yeroo kuusitan ofiin uumama.',
      );
  String get schoolTransportIdStudentHint => t(
        'e.g. DRV-1001',
        'ለምሳ. DRV-1001',
        'fkn. DRV-1001',
      );
  String get schoolTransportIdOptionalHint => t(
        'Optional now — you can add or update this later on the student profile.',
        'አሁን አማራጭ — በኋላ በተማሪ መገለጫ ላይ ሊጨመር ይችላል።',
        'Amma filannoo — booda piroofaayilii barataa irratti dabaluu dandeessa.',
      );
  String get transportIdNotFound => t(
        'Transport ID not found. Check the ID from Staff → Transport.',
        'የትራንስፖርት መለያ አልተገኘም። Staff → Transport ይመልከቱ።',
        'ID geejjibaa hin argamne. Staff → Transport ilaali.',
      );
  String transportDriverNotRegisteredWithId(String id) => t(
        'There is no registered driver with ID $id',
        'በ $id መለያ የተመዘገበ አሽከርካሪ የለም',
        'Konkolaachisaa galmeeffame ID $id tiin hin jiru',
      );
  String transportDriverRegisteredLabel(
    String id,
    String name,
    String bus,
  ) =>
      t(
        'Registered driver: $name · $bus ($id)',
        'የተመዘገበ አሽከርካሪ: $name · $bus ($id)',
        'Konkolaachisaa galmeeffame: $name · $bus ($id)',
      );
  String get transportNoRegisteredDrivers => t(
        'No registered transport staff for this school. Add drivers under Staff → Transport first.',
        'ለዚህ ትምህርት ቤት የተመዘገበ ትራንስፖርት ሰራተኛ የለም። በ Staff → Transport መጀመሪያ አሽከርካሪ መዝግቡ።',
        'Mana barumsaa kanaaf hojjettoonni geejjibaa galmeeffaman hin jiru. Staff → Transport irraa dura dabalaa.',
      );
  String get selectRegisteredDriver => t(
        'Select registered driver',
        'የተመዘገበ አሽከርካሪ ይምረጡ',
        'Konkolaachisaa galmeeffame filadhu',
      );
  String get transportIdWrongSchool => t(
        'This Transport ID belongs to another school.',
        'ይህ የትራንስፖርት መለያ ለሌላ ትምህርት ቤት ነው።',
        'ID geejjibaa kun mana barumsaa biraaaf dha.',
      );
  String get optionalLabel => t('optional', 'አማራጭ', 'filannoo');
  String get transportWired => t('Transport linked', 'ትራንስፖርት ተገናኝቷል', 'Geejjibni wal qunnamtame');
  String get transportNotWired => t(
        'Not linked yet',
        'እስካሁን አልተገናኘም',
        'Hanga ammaatti hin wal qunnamne',
      );
  String get parentBusLinkTitle => t(
        'School bus',
        'የትምህርት ቤት አውቶቡስ',
        'Awutobusii mana barumsaa',
      );
  String get schoolBusTool => t(
        'School Bus',
        'የትምህርት ቤት አውቶቡስ',
        'Awutobusii Mana Barumsaa',
      );
  String get parentBusLinkSubtitle => t(
        'Enter the Bus Link ID from the school to track your child\'s bus.',
        'የልጅዎን አውቶቡስ ለመከታተል ከትምህርት ቤቱ የተሰጠውን Bus Link ID ያስገቡ።',
        'Awutobusii ijoollee kee hordofuuf ID walitti hidhamuu autobusii mana barumsaa irraa galchi.',
      );
  String get parentBusLinkIdLabel => t(
        'Bus Link ID',
        'Bus Link ID',
        'ID Walitti hidhamuu Autobusii',
      );
  String get parentBusLinkSave => t(
        'Link to bus',
        'ከአውቶቡስ ጋር ያገናኙ',
        'Autobusii waliin wal qunnamsiisi',
      );
  String get parentBusLinkUpdate => t(
        'Update bus link',
        'የአውቶቡስ መያያዣ ያዘምኑ',
        'Walitti hidhamuu autobusii haaromsi',
      );
  String parentBusLinkedSuccess(String childName) => t(
        '$childName is now linked to the school bus.',
        '$childName ከአውቶቡስ ጋር ተገናኝቷል።',
        '$childName amma autobusii mana barumsaa waliin wal qunnamtameera.',
      );
  String get parentBusUnlinkedSuccess => t(
        'Bus link removed.',
        'የአውቶቡስ መያያዣ ተወግዷል።',
        'Walitti hidhamni autobusii haqame.',
      );
  String get parentBusLinkAccessDenied => t(
        'You can only link buses for your own children.',
        'ለራስዎ ልጆች ብቻ አውቶቡስ መያያዣ ማድረግ ይችላሉ።',
        'Ijoollee kee qofaaf autobusii wal qunnamsiisuu dandeessa.',
      );
  String get parentUnlinkBusTitle => t(
        'Remove bus link?',
        'የአውቶቡስ መያያዣ ይወግድ?',
        'Walitti hidhamuu autobusii haquu?',
      );
  String parentUnlinkBusMessage(String childName) => t(
        'Stop bus tracking for $childName on this device. You can link again anytime.',
        'ለ $childName የአውቶቡስ መከታተል ይቆም። በማንኛውም ጊዜ እንደገና መያያዣ ማድረግ ይችላሉ።',
        'Hordoffiin autobusii $childName dhaabbata. Yeroo kamiyyuu irra deebi\'an wal qunnamsiisuu dandeessa.',
      );
  String get parentUnlinkBusConfirm => t(
        'Remove link',
        'መያያዣ አስወግድ',
        'Walitti hidhamuu haqi',
      );
  String parentBusLinkedDriver(String driverName, String busId) => t(
        'Driver: $driverName · $busId',
        'አሽከርካሪ: $driverName · $busId',
        'Konkolaachisaa: $driverName · $busId',
      );
  String get parentBusLinkPrompt => t(
        'Link your child\'s bus first to see live tracking.',
        'ቀጥታ መከታተል ለማየት መጀመሪያ የልጅዎን አውቶቡስ ያገናኙ።',
        'Hordoffii kallattii arguuf dursa autobusii ijoollee kee wal qunnamsiisi.',
      );
  String get busRouteMapUnavailable => t(
        'Bus route map is loading. Live GPS will appear when the driver shares location.',
        'የአውቶቡስ መስመር ካርታ በመጫን ላይ ነው። አሽከርካሪው ቦታ ሲጋራ ቀጥታ GPS ይታያል።',
        'Kaartni karaa autobusii fe\'aa jira. Konkolaachisaa bakka yoo qoodu GPS kallattii ni mul\'ata.',
      );
  String get transportBusList =>
      t('School buses', 'የትራንስፖርት አውቶቡሶች', 'Awutobusii mana barumsaa');
  String get viewPassengerList =>
      t('View passengers', 'ተሳፋሪዎችን ይመልከቱ', 'Fayyadamtoota ilaali');
  String get passengers =>
      t('Passenger List', 'ተሳፋሪዎች', 'Tarree fayyadamtootaa');
  String get transportOnboard =>
      t('Onboard', 'በአውቶቡስ ላይ', 'Awutobusii irra');
  String get transportWaiting =>
      t('Not onboard', 'በአውቶቡስ ላይ አይደለም', 'Awutobusii irra miti');
  String get transportDischarge =>
      t('Discharge', 'ማውረድ', 'Buusi');
  String get transportNoPassengers => t(
        'No students assigned to this bus yet.',
        'ለዚህ አውቶቡስ ተማሪዎች አልተመደቡም።',
        'Barattoonni awutobusii kanaaf hin ramadamne.',
      );
  String get transportNoAssignedBus => t(
        'No bus linked to your driver account.',
        'ለመለያዎ አውቶቡስ አልተገናኘም።',
        'Awutobusni akkaawuntii konkolaachisaa kee waliin hin qunnamne.',
      );
  String get transportOnboardRecorded => t(
        'Student onboard — parent notified',
        'ተማሪ በአውቶቡስ ላይ — ወላጅ ተሳውቋል',
        'Barataan awutobusii irra — maatiin beekame',
      );
  String get transportDischargeRecorded => t(
        'Student discharged — parent notified',
        'ተማሪ ወርዷል — ወላጅ ተሳውቋል',
        'Barataan buufame — maatiin beekame',
      );
  String get transportScanHint => t(
        'Scan the student QR code to onboard or discharge. Parents receive a notification.',
        'ለመውጣት/ማውረድ QR ኮዱን ይስካኑ። ወላጆች ማሳወቂያ ይደርሳቸዋል።',
        'Seenuuf/buusuuf QR barataa iskaanii. Beeksisa maatii ni dhufa.',
      );
  String get transportBusListHint => t(
        'Tap a bus to view live GPS on Google Maps. Use Passengers for onboard status.',
        'ቀጥታ GPS በGoogle Maps ለማየት አውቶቡስ ይምረጡ። ለተሳፋሪዎች ሁኔታ Passengers ይጫኑ።',
        'GPS kallatti Google Maps irratti ilaaluuf awutobusii fili. Haala fayyadamtootaa Passengers fayyadami.',
      );
  String get busLiveLocation =>
      t('Live bus location', 'ቀጥታ የአውቶቡስ ቦታ', 'Bakka awutobusii kallatti');
  String get busGpsLive => t(
        'Live GPS from driver phone',
        'ከአሽከርካሪ ስልክ ቀጥታ GPS',
        'GPS kallatti bilbila konkolaachisaa irraa',
      );
  String get busGpsAcquiring => t(
        'Acquiring GPS signal…',
        'GPS ሲገኝ…',
        'Mallattoo GPS argachaa jira…',
      );
  String get busGpsWaitingForDriver => t(
        'Waiting for driver GPS — ask driver to open the app with location on',
        'የአሽከርካሪ GPS በመጠበቅ ላይ — አሽከርካሪው ቦታ ከበራበት መተግበሪያውን እንዲከፍት ይጠይቁ',
        'GPS konkolaachisaa eegaa jira — appii bakka ibsamee banuuf himi',
      );
  String busGpsLastSeen(int minutes) => t(
        'Last GPS update $minutes min ago',
        'የመጨረሻ GPS $minutes ደቂቃ በፊት',
        'GPS dhumaa daqiiqaa $minutes dura',
      );
  String get busGpsPermissionDenied => t(
        'Location permission denied. Enable GPS in phone settings.',
        'የቦታ ፍቃድ ተሰርዟል። በስልክ ቅንብር GPS ያብሩ።',
        'Hayyamni bakkaa dide. GPS settings bilbilaa keessatti dandeessisi.',
      );
  String get shareMyLocation =>
      t('Share my location', 'ቦታዬን አጋራ', 'Bakka koo qoodi');
  String get done => t('Done', 'ተከናውኗል');
  String get inviteParent =>
      t('Invite Parent', 'ወላጅ ጋብዝ');
  String get inviteBulkTitle =>
      t('Bulk parent invites', 'ወላጆችን በአጅም');
  String get inviteBulkStart =>
      t('Start SMS invites', 'SMS ጀምር');
  String get inviteBulkEmpty =>
      t('No students to invite', 'ለመጋበዝ ተማሪ የለም');
  String get inviteParentSent => t('SMS or share app opened with invite message', 'SMS / share መተግበሪያ ተከፍቷል');
  String get inviteParentFailed => t('Could not open SMS app', 'SMS መክፈት አልተሳካም');
  String get inviteParentNoRecord => t('Student record not found', 'ተማሪ መዝገብ አልተገኘም');
  String get inviteParentNoPhone => t('No emergency contact phone on file. Use Share to send the invite message manually.', 'የድንገተኛ ግንኙነት ቁጥር የለም። መልዕክቱን ለማጋራት Share ይጠቀሙ።');
  String inviteBulkBody(int total, int withPhone, int withoutPhone) => t('$total parents · $withPhone with phone · $withoutPhone missing phone\n\nThis opens your SMS app once per parent. Send each welcome message.', '$total ወላጆች · $withPhone SMS · $withoutPhone ቁጥር የለም\n\nSMS መተግበሪያውን ለእያንዳንዱ ወላጅ ይከፍታል። እያንዳንዱን መልዕክት ይላኩ።');
  String inviteBulkBodyClass(
    String className,
    int total,
    int withPhone,
    int withoutPhone,
  ) =>
      t('$className · $total parents · $withPhone with phone · $withoutPhone missing phone', '$className · $total ወላጆች · $withPhone SMS · $withoutPhone ቁጥር የለም');
  String inviteBulkDone(int sent, int skipped) {
    if (isAmharic) {
      return 'SMS መተግበሪያ ለ $sent ወላጆች ተከፍቷል${skipped > 0 ? ' · $skipped ቁጥር የለም' : ''}';
    }
    if (isOromo) {
      return 'SMS appii maatii $sent tiif baname${skipped > 0 ? ' · $skipped hin darbine (bilbila hin qabu)' : ''}';
    }
    return 'Opened SMS for $sent parent(s)${skipped > 0 ? ' · $skipped skipped (no phone)' : ''}';
  }
  String get sendInviteNow =>
      t('Invite parent (SMS)', 'ወላጅ ጋብዝ (SMS)');
  String get fillRequiredFields => t('Please fill all required fields', 'አስፈላጊ መስኮችን ይሙሉ');
  String get usernameExists =>
      t('Username already exists', 'ተጠቃሚ ስም አለ');
  String get alreadyLinkedStudent => t('You already have a link request for this student', 'ከዚህ ተማሪ ጋር ቀድሞ ተገናኝተዋል');
  String get registrationFailed =>
      t('Registration failed', 'መዝገብ አልተሳካም');
  String get invalidDateFormat => t('Use date format DD/MM/YYYY', 'ቀን DD/MM/YYYY በሚሆን መልክ ያስገቡ');
  String get staffSignupClosed => t(
        'Administration staff are created by your school admin — not through public signup.',
        'የአስተዳደር ሰራተኞች በትምህርት ቤቱ አስተዳዳሪ ይፈጠራሉ — በዚህ አይመዘገቡ።',
        'Hojjettoonni bulchiinsaa bulchaa mana barumsaa keessaniin uumamu — galmee ummataatiin miti.',
      );
  String get registerYourSchool =>
      t('Register your school', 'ትምህርት ቤትዎን ይመዝግቡ');

  String relationshipLabel(ParentRelationship r) {
    if (isAmharic) {
      return switch (r) {
        ParentRelationship.father => 'አባት',
        ParentRelationship.mother => 'እናት',
        ParentRelationship.guardian => 'አሳዳጊ',
      };
    }
    if (isOromo) {
      return switch (r) {
        ParentRelationship.father => 'Abbaa',
        ParentRelationship.mother => 'Haadha',
        ParentRelationship.guardian => 'Eegduu',
      };
    }
    return switch (r) {
      ParentRelationship.father => 'Father',
      ParentRelationship.mother => 'Mother',
      ParentRelationship.guardian => 'Guardian',
    };
  }

  String linkStatus(ParentLinkStatus status) {
    if (isAmharic) {
      return switch (status) {
        ParentLinkStatus.pending => 'በመጠበቅ ላይ',
        ParentLinkStatus.approved => 'ተጽድቋል',
        ParentLinkStatus.rejected => 'ተሰርዟል',
      };
    }
    if (isOromo) {
      return switch (status) {
        ParentLinkStatus.pending => 'Eeggachaa jira',
        ParentLinkStatus.approved => 'Mirkanaa\'eera',
        ParentLinkStatus.rejected => 'Dide',
      };
    }
    return switch (status) {
      ParentLinkStatus.pending => 'Pending',
      ParentLinkStatus.approved => 'Approved',
      ParentLinkStatus.rejected => 'Rejected',
    };
  }

  String teacherRoleLabel(TeacherStaffRole role) {
    if (isAmharic) {
      return switch (role) {
        TeacherStaffRole.homeroomTeacher => 'የክፍል መምህር',
        TeacherStaffRole.subjectTeacher => 'የትምህርት መምህር',
      };
    }
    if (isOromo) {
      return switch (role) {
        TeacherStaffRole.homeroomTeacher => 'Barsiisaa Kutaa',
        TeacherStaffRole.subjectTeacher => 'Barsiisaa Barnootaa',
      };
    }
    return switch (role) {
      TeacherStaffRole.homeroomTeacher => 'Homeroom Teacher',
      TeacherStaffRole.subjectTeacher => 'Subject Teacher',
    };
  }

  String get rulesAndRegulationsTitle =>
      t('Rules & Regulations', 'ደንቦች እና መመሪያዎች');
  String get waitingForSchoolApproval =>
      t('Waiting for school approval', 'የትምህርት ቤት መጽደቅ በመጠበቅ ላይ');
  String get parentApprovalNotificationTitle =>
      t('Child link approved', 'የልጅ ግንኙነት ተጽድቋል');
  String parentApprovalNotificationBody(String childName, String studentId) => t(
        'Your link to $childName ($studentId) has been approved. You can now view their school data.',
        'ወደ $childName ($studentId) ግንኙነትዎ ተጽድቋል። አሁን የትምህርት መረጃ መመልከት ይችላሉ።',
      );
  String get addAnotherChild => t('+ Add another child', '+ ሌላ ልጅ ጨምር');
  String get yes => t('Yes', 'አዎ', 'Eeyyee');
  String get no => t('No', 'አይ', 'Lakki');
  String get parentChildLinkStep =>
      t('Link your child', 'ልጅዎን ያገናኙ', 'Ijoollee keessan hidhaa');
  String get studentMedicalSection =>
      t('Medical information', 'የصحت መረጃ', 'Odeeffannoo fayyaa');
  String get studentMedicalQuestion => t(
        'Does the student have any medical condition?',
        'ልጁ የصحت ችግር አለው?',
        'Ijoolleen sun haala fayyaa qaba?',
      );
  String get studentMedicalSpecify =>
      t('If yes, please specify', 'አዎ ከሆነ ይግለጹ', 'Yoo eeyyee ta\'e ibsaa');
  String get studentMedicalOtherInfo => t(
        'Other important medical information for school',
        'ለትምህርት ቤት ሌላ አስፈላጊ የصحت መረጃ',
        'Odeeffannoo fayyaa barbaachisaa biroo mana barumsaaf',
      );
  String get studentMedicalRequired => t(
        'Please answer the medical condition question',
        'የصحت ጥያቄውን ይመልሱ',
        'Gaaffii haala fayyaa deebisaa',
      );
  String get studentMedicalSpecifyRequired => t(
        'Please specify the medical condition',
        'የصحت ችግሩን ይግለጹ',
        'Haala fayyaa ibsaa',
      );
  String get studentMedicalYes =>
      t('Has medical condition', 'የصحت ችግር አለ', 'Haala fayyaa qaba');
  String get studentMedicalNone => t(
        'No medical condition reported',
        'የصحت ችግር አልተመዘገበም',
        'Ragaa fayyaa hin jiru',
      );
  String get otpSentViaSms => t(
        'Verification code sent via SMS',
        'ማረጋገጫ ኮድ በ SMS ተልኳል',
        'Koodii mirkaneessaa SMSn ergame',
      );
  String get otpFirebaseFallback => t(
        'Firebase not configured — using demo OTP for testing',
        'Firebase አልተዋቀረም — ለሙከራ demo OTP ጥቅም ላይ ይውላል',
        'Firebase hin qindaa\'e — OTP demo tijaajilaaf',
      );
  String get otpSmsFailed => t(
        'SMS could not be sent. Check the phone number and Firebase Phone Auth setup.',
        'SMS መላክ አልተቻለም። ስልክ ቁጥር እና Firebase Phone Auth ያረጋግጡ።',
        'SMS ergamuu hin dandeenye. Lakkoofsa bilbilaa fi Firebase mirkaneessi.',
      );
  String get otpFirebaseSha1Setup => t(
        'Firebase Phone Auth is not fully set up. In Firebase Console: (1) Authentication → enable Phone and Google sign-in, (2) Project settings → Android app → add SHA-1 and SHA-256, (3) wait 5 minutes and re-download google-services.json. Until oauth_client is populated, add a test phone number under Authentication → Phone → Phone numbers for testing.',
        'Firebase Phone Auth ሙሉ አልተዋቀረም። Firebase Console → Authentication → Phone እና Google sign-in ያንቁ፣ SHA-1/SHA-256 ያክሉ፣ google-services.json እንደገና ያውርዱ።',
        'Firebase Phone Auth hin qindaa\'e. Firebase Console keessatti Phone fi Google sign-in banadhaa, SHA-1/SHA-256 dabalaa.',
      );
  String get otpSmsRegionNotEnabled => t(
        'Ethiopia (+251) is not enabled for SMS in Firebase. Go to Authentication → Settings → SMS region policy → Allow → add Ethiopia (ET), then try again. Real SMS also requires the Blaze (pay-as-you-go) plan.',
        'ኢትዮጵያ (+251) ለ SMS በ Firebase አልተነቀሰም። Authentication → Settings → SMS region policy → Allow → Ethiopia (ET) ያክሉ። እውነተኛ SMS Blaze plan ይፈልጋል።',
        'Itoophiyaa (+251) SMS irratti hin bane. Firebase → Authentication → Settings → SMS region policy keessatti ET dabalaa.',
      );
  String get otpBillingNotEnabled => t(
        'Real SMS requires Firebase Blaze (pay-as-you-go) billing. In Firebase Console click Upgrade, enable billing, then retry. For free testing: Authentication → Phone → add your number under Phone numbers for testing (fixed code, no SMS).',
        'እውነተኛ SMS Firebase Blaze billing ይፈልጋል። Firebase Console → Upgrade → billing ያንቁ። ለነጻ ሙከራ: Authentication → Phone → Phone numbers for testing ይጠቀሙ።',
        'SMS dhugaa Firebase Blaze billing barbaachisa. Testing: Authentication → Phone → test numbers.',
      );
  String otpSmsFailedDetail(String? detail) => t(
        'SMS could not be sent. $detail',
        'SMS መላክ አልተቻለም። $detail',
        'SMS ergamuu hin dandeenye. $detail',
      );
  String get phoneOtpHint => t(
        '09xxxxxxxx (Ethiopia — +251 added automatically)',
        '09xxxxxxxx (+251 በራስ-ሰር ይ附加ል)',
        '09xxxxxxxx (+251 ofiin ni dabalama)',
      );
  String get verifyChildFirst =>
      t('Verify the student first', 'መጀመሪያ ልጁን አረጋግጡ', 'Dura ijoollee mirkaneessaa');
  String get linkAnotherChild =>
      t('Link another child', 'ሌላ ልጅ መጨመር', 'Ijoollee biraa hidhuu');
  String get addNewChild =>
      t('Add new child', 'አዲስ ልጅ ጨምር', 'Ijoollee haaraa dabaluu');
  String get linkAnotherChildHint => t(
        'Enter your child\'s student ID and date of birth. The school will review and approve the link.',
        'የልጅዎን መለያ እና የልደት ቀን ያስገቡ። ትምህርት ቤቱ ጥያቄውን ይገመግማል።',
        'ID fi guyyaa dhaloota ijoollee galchaa. Mana barumsaa ni mirkaneessa.',
      );
  String get linkAnotherChildShort =>
      t('Tap to register', 'ለመመዝገብ ይንኩ', 'Galmeessuuf tuqi');
  String get submitLinkRequest =>
      t('Submit link request', 'ጥያቄ ላክ', 'Gaaffii ergi');
  String get viewAllChildren =>
      t('View all children', 'ሁሉንም ልጆች', 'Ijoollee hunda ilaali');
  String get parentRegistrationTitle =>
      t('Parent registration', 'የወላጅ ምዝገባ', 'Galmeessa warraa');
  String get childDateOfBirth => t("Child's date of birth", 'የልጅ የልደት ቀን');
  String get verifyChild => t('Verify child', 'ልጅ አረጋግጥ');
  String get addClassAssignment => t('+ Add class', '+ ክፍል ጨምር');
  String get classRole => t('Role for this class', 'ለዚህ ክፍል ሚና');
  String get atLeastOneClass =>
      t('Add at least one class assignment', 'ቢያንስ አንድ ክፍል ያክሉ');
  String classNumberLabel(int n) => t('Class $n', 'ክፍል $n');
  String get approvedStatus => t('Approved', 'ተጽድቋል');
  String get noApprovalRequests =>
      t('No parent approval requests', 'የወላጅ ጥያቄ የለም');

  String timeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) {
      return t('${diff.inMinutes}m ago', 'ከ${diff.inMinutes} ደቂቃ በፊት');
    }
    if (diff.inHours < 24) {
      return t('${diff.inHours}h ago', 'ከ${diff.inHours} ሰዓት በፊት');
    }
    return '${time.day}/${time.month}/${time.year}';
  }

  String dayShort(int weekday) {
    if (isAmharic) {
      return switch (weekday) {
        DateTime.monday => 'ሰኞ',
        DateTime.tuesday => 'ማክ',
        DateTime.wednesday => 'ረቡ',
        DateTime.thursday => 'ሐሙ',
        DateTime.friday => 'ዓር',
        DateTime.saturday => 'ቅ',
        DateTime.sunday => 'እሁ',
        _ => '',
      };
    }
    if (isOromo) {
      return switch (weekday) {
        DateTime.monday => 'Wix',
        DateTime.tuesday => 'Qib',
        DateTime.wednesday => 'Rob',
        DateTime.thursday => 'Kam',
        DateTime.friday => 'Jim',
        DateTime.saturday => 'San',
        DateTime.sunday => 'Dil',
        _ => '',
      };
    }
    return switch (weekday) {
      DateTime.monday => 'Mon',
      DateTime.tuesday => 'Tue',
      DateTime.wednesday => 'Wed',
      DateTime.thursday => 'Thu',
      DateTime.friday => 'Fri',
      DateTime.saturday => 'Sat',
      DateTime.sunday => 'Sun',
      _ => '',
    };
  }

  String get selectGrade => t('Select grade', 'ክፍል ይምረጡ');
  String get noGradesConfigured => t(
        'No grades configured for this school. Ask the platform owner to set grade levels.',
        'ለትምህርት ቤቱ ክፍሎች አልተመዘገቡም። Platform owner grade levels እንዲያክሉ ይጠይቁ።',
      );
  String get sectionAutoCreateHint => t(
        'A, B, C — created automatically if new',
        'A, B, C — አዲስ ከሆነ በራስ-ሰር ይፈጠራል',
      );
  String classAssignmentPreview(String className) => t(
        'Class roster: $className',
        'የክፍል ስም: $className',
      );
  String get selectSection => t('Select section', 'ሴክሽን ይምረጡ');
  String get sectionTeachers => t('Teachers', 'መምህራን');
  String get sectionStudents => t('Students', 'ተማሪዎች');
  String get noTeachersInSection =>
      t('No teachers assigned to this section', 'ለዚህ ሴክሽን መምህር አልተመደበም');
  String get noStudentsInSection =>
      t('No students in this section', 'በዚህ ሴክሽን ተማሪ የለም');
  String get studentProfile => t('Student profile', 'የተማሪ መገለጫ');
  String get messageInternally => t('Message', 'መልዕክት');
  String get callContact => t('Call', 'ይደውሉ');
  String get editStudent => t('Edit student', 'ተማሪ አርትዕ');
  String get deleteStudent => t('Remove student', 'ተማሪ አስወግድ');
  String get transferStudent => t('Transfer student', 'ተማሪ አዛድር');
  String get editTeacher => t('Edit teacher', 'መምህር አርትዕ');
  String get assignTeacherClasses => t('Assign classes', 'ክፍሎች መድብ');
  String get transferTeacher => t('Transfer classes', 'ክፍሎች አዛድር');
  String get deactivateTeacher => t('Remove staff', 'ሰራተኛ አስወግድ');
  String get studentRemoved => t('Student removed from school', 'ተማሪ ተወግዷል');
  String get teacherDeactivated => t(
        'Staff removed. Phone number is free to register again.',
        'ሰራተኛ ተወግዷል። ስልክ ቁጥሩ እንደገና ለመመዝገብ ነፃ ነው።',
      );
  String get confirmDeleteStudent => t(
        'Remove this student from the school? They will no longer appear in class lists.',
        'ይህን ተማሪ ከትምህርት ቤቱ ይወግዱ?',
      );
  String get confirmDeactivateTeacher => t(
        'Remove this staff member from the school? Their login will be deleted and their phone number will be freed automatically.',
        'ይህን ሰራተኛ ከትምህርት ቤቱ ያስወግዱ? መግቢያቸው ይሰረዛል እና ስልክ ቁጥራቸው በራስ-ሰር ነፃ ይሆናል።',
      );
  String get replaceHomeroomTeacher => t(
        'Replace homeroom teacher',
        'የክፍል መምህር ይተኩ',
      );
  String replaceHomeroomPrompt(String className) => t(
        '$className needs a new homeroom teacher before this teacher can be deactivated.',
        '$className አዲስ የክፍል መምህር ይต้องการ ከመቦዝን በፊት።',
      );
  String get chooseReplacementTeacher =>
      t('Choose replacement teacher', 'አዲስ የክፍል መምህር ይምረጡ');
  String get selectReplacementFromStaff => t(
        'Select a teacher from your staff list',
        'ከሰራተኞች ዝርዝር መምህር ይምረጡ',
      );
  String get noTeachersAvailableForReplacement => t(
        'No other teachers in staff. Add a teacher first.',
        'ሌላ መምህር የለም። መጀመሪያ መምህር ጨምሩ።',
      );
  String get addSection => t('Add section', 'ሴክሽን ጨምር');
  String get noSectionsYetAdmin => t(
        'No sections yet. Tap Add section to create one.',
        'ሴክሽን የለም። Add section ይጫኑ።',
      );
  String get sectionAdded => t('Section added', 'ሴክሽን ተጨምሯል');
  String get sectionsManagedByAdmin => t(
        'Sections are added by the school admin in Classes',
        'ሴክሽኖችን አስተዳዳሪ በ Classes ይጨምራሉ',
      );
  String get studentUpdated => t('Student updated', 'ተማሪ ተዘምኗል');
  String get teacherUpdated => t('Teacher updated', 'መምህር ተዘምኗል');
  String get studentTransferred => t('Student transferred', 'ተማሪ ተዛውሯል');
  String get teacherTransferred => t('Classes updated', 'ክፍሎች ተዘምነዋል');

  // Admin transfers
  String get transferHubTitle => t('Transfers', 'አዛወር');
  String get transferStudentsTab => t('Students', 'ተማሪዎች');
  String get transferTeachersTab => t('Teachers', 'መምህሮች');
  String get transferDriversTab => t('Drivers', 'አሽከርካሪዎች');
  String get transferSectionToSection =>
      t('Section → Section', 'ሴክሽን → ሴክሽን');
  String get transferGradeToGrade => t('Grade → Grade', 'ክፍል → ክፍል');
  String get transferTransportToTransport =>
      t('Transport → Transport', 'ትራንስፖርት → ትራንስፖርት');
  String get transferCampusToCampus =>
      t('Campus → Campus', 'ካምፐስ → ካምፐስ');
  String get transferBusToBus => t('Bus → Bus', 'አውቶቡስ → አውቶቡስ');
  String get transferSectionToSectionHint => t(
        'Move a student to another section (same or different grade)',
        'ተማሪን ወደ ሌላ ሴክሽን ያዛውሩ',
      );
  String get transferGradeToGradeHint => t(
        'Move a student to a different grade and section',
        'ተማሪን ወደ ሌላ ክፍል እና ሴክሽን ያዛውሩ',
      );
  String get transferTransportToTransportHint => t(
        'Reassign a student to a different school bus route',
        'ተማሪን ወደ ሌላ አውቶቡስ መስመር ያዛውሩ',
      );
  String get transferCampusToCampusHint => t(
        'Move a student to another campus location',
        'ተማሪን ወደ ሌላ ካምፐስ ያዛውሩ',
      );
  String get transferTeacherSectionHint => t(
        'Move a teacher assignment to another section',
        'የመምህርን መመደብ ወደ ሌላ ሴክሽን ያዛውሩ',
      );
  String get transferTeacherGradeHint => t(
        'Move a teacher assignment to another grade and section',
        'የመምህርን መመደብ ወደ ሌላ ክፍል ያዛውሩ',
      );
  String get transferTeacherCampusHint => t(
        'Move a teacher to another campus location',
        'መምህርን ወደ ሌላ ካምፐስ ያዛውሩ',
      );
  String get transferBusToBusHint => t(
        'Swap bus routes between two drivers',
        'በሁለት አሽከርካሪዎች መካከል የአውቶቡስ መስመር ይቀይሩ',
      );
  String get transferBusToBusDescription => t(
        'Select two drivers to swap their bus numbers, routes, and plates. Passengers stay linked to the same driver account.',
        'መስመራቸውን ለመቀየር ሁለት አሽከርካሪዎችን ይምረጡ።',
      );
  String get transferChooseType =>
      t('Choose transfer type', 'የአዛወር አይነት ይምረጡ');
  String get transferTypesHeading =>
      t('Transfer types', 'የአዛወር አይነቶች');
  String transferStudentsRoster(int count) => t(
        'Students ($count)',
        'ተማሪዎች ($count)',
      );
  String transferTeachersRoster(int count) => t(
        'Teachers ($count)',
        'መምህሮች ($count)',
      );
  String transferDriversRoster(int count) => t(
        'Drivers ($count)',
        'አሽከርካሪዎች ($count)',
      );
  String get transferNoStudents =>
      t('No students to transfer', 'ለመዛወር ተማሪ የለም');
  String get transferNoTransportStudents => t(
        'No students with transport assigned',
        'ትራንስፖርት ያላቸው ተማሪ የለም',
      );
  String get transferNoTeachers =>
      t('No teachers to transfer', 'ለመዛወር መምህር የለም');
  String get transferNoDrivers =>
      t('No drivers to transfer', 'ለመዛወር አሽከርካሪ የለም');
  String get transferNeedTwoDrivers => t(
        'Add at least two drivers to swap bus routes',
        'የአውቶቡስ መስመር ለመቀየር ቢያንስ ሁለት አሽከርካሪዎች ያስፈልጋሉ',
      );
  String get selectTeacher => t('Select teacher', 'መምህር ይምረጡ');
  String get transferToGrade => t('To grade', 'ወደ ክፍል');
  String get transferToSection => t('To section', 'ወደ ሴክሽን');
  String get transferToCampus => t('To campus', 'ወደ ካምፐስ');
  String get transferToBus => t('To bus', 'ወደ አውቶቡስ');
  String get transferFromBus => t('From bus', 'ከአውቶቡስ');
  String get transferFromClass => t('From class', 'ከክፍል');
  String get confirmTransfer => t('Confirm transfer', 'አዛወር ያረጋግጡ');
  String get currentPlacement => t('Current placement', 'አሁን ያለበት');
  String get transferFailed =>
      t('Transfer could not be completed', 'አዛወር አልተሳካም');
  String get driverBusTransferred =>
      t('Bus routes swapped', 'የአውቶቡስ መስመሮች ተቀይረዋል');
  String get campus => t('Campus', 'ካምፐስ');

  String get contactDetails => t('Contact details', 'የግንኙነት መረጃ');
  String get assignedClasses => t('Assigned classes', 'የተመደቡ ክፍሎች');
  String get choosePhoneToCall => t('Choose number to call', 'የሚደውሉበትን ቁጥር ይምረጡ');
  String get noPhoneOnFile => t('No phone number on file', 'ስልክ ቁጥር የለም');
}

class AppLocale extends ChangeNotifier {
  AppLocale._();
  static final instance = AppLocale._();

  static const _prefsKey = 'app_language_code';

  String _code = 'en';
  String get code => _code;

  /// Flutter Material/Cupertino widgets (date pickers, etc.) — Oromo falls back to English.
  String get materialLocaleCode => _code == 'am' ? 'am' : 'en';

  AppStrings get strings => AppStrings(_code);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && ['en', 'am', 'om'].contains(saved)) {
      _code = saved;
      notifyListeners();
    }
  }

  void setLanguage(String code) {
    if (_code == code) return;
    _code = code;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefsKey, code);
    });
  }
}
