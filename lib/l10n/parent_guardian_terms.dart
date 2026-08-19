import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/l10n/parent_guardian_terms_am.dart';
class ParentGuardianTerms {
  ParentGuardianTerms._();

  static const registrationLanguages = ['en', 'am', 'om'];

  static String bodyFor(String languageCode) {
    switch (languageCode) {
      case 'am':
        return ParentGuardianTermsAm.text;
      case 'om':
        return oromo;
      case 'en':
      default:
        return english;
    }
  }

  static String titleFor(String languageCode) {
    switch (languageCode) {
      case 'am':
        return 'የወላጅ/አሳዳጊ ደንቦች እና መመሪያዎች';
      case 'om':
        return 'Seeraa fi Dambii Warraa/Eekaa';
      case 'en':
      default:
        return 'Parent/Guardian Rules and Regulations';
    }
  }

  static String checkboxFor(String languageCode) {
    switch (languageCode) {
      case 'am':
        return 'የወላጅ/አሳዳጊ ደንቦች እና መመሪያዎችን አንብቤ እስማማለሁ';
      case 'om':
        return 'Seeraa fi dambii warraa/eekaa dubbisee nan fudhadha';
      case 'en':
      default:
        return 'I have read and agree to the Parent/Guardian Rules and Regulations';
    }
  }

  static String agreeLabelFor(String languageCode) {
    switch (languageCode) {
      case 'am':
        return 'እስማማለሁ';
      case 'om':
        return 'Nan fudhadha';
      case 'en':
      default:
        return 'I Agree';
    }
  }

  static String cancelLabelFor(String languageCode) {
    switch (languageCode) {
      case 'am':
        return 'ሰርዝ';
      case 'om':
        return 'Dhiisi';
      case 'en':
      default:
        return 'Cancel';
    }
  }

  static String readInLanguageLabelFor(String languageCode) {
    switch (languageCode) {
      case 'am':
        return 'ውሎቹን በዚህ ቋንቋ ይክሱ';
      case 'om':
        return 'Seera kana afaan kanaan dubbisaa';
      case 'en':
      default:
        return 'Read terms in';
    }
  }

  static String defaultLanguageForApp() {
    return switch (AppLocale.instance.code) {
      'am' => 'am',
      'om' => 'om',
      _ => 'en',
    };
  }

  static const english = '''
Parent/Guardian Rules and Regulations

Parent/Guardian Agreement

By registering your child on this platform and enrolling them in the school, you acknowledge that you have read, understood, and agreed to comply with the following rules and regulations.

1. Student Attendance
• Ensure your child attends school regularly and arrives on time.
• Notify the school promptly if your child will be absent or late.
• Frequent unexplained absences may affect your child's academic performance.

2. Health Information
• Provide accurate and complete medical information during registration.
• Inform the school immediately of any changes in your child's health, allergies, medications, or emergency contacts.
• Keep your child at home if they have a contagious illness until they are medically fit to return.

3. Communication
• Regularly check the school platform for announcements, homework, notices, and messages.
• Respond promptly to important communications from the school.
• Maintain respectful communication with teachers, administrators, and staff.

4. Student Conduct
• Encourage your child to follow all school rules and maintain respectful behavior.
• Support the school's disciplinary procedures when necessary.
• Parents are expected to work cooperatively with the school in resolving behavioral concerns.

5. Academic Support
• Encourage your child to complete homework, assignments, and projects on time.
• Monitor your child's academic progress through the platform.
• Attend parent meetings or conferences when requested.

6. Fees and Financial Obligations
• Pay school fees and other approved charges by the required deadlines.
• Outstanding payments may affect access to certain school services, where permitted by school policy.

7. Personal Information
• Ensure that all information provided during registration is accurate and truthful.
• Update the school immediately if your address, phone number, email address, or emergency contacts change.

8. Student Pick-Up and Transportation
• Ensure only authorized persons collect your child from school where applicable.
• Notify the school in advance if another person will collect your child.
• Follow all transportation and school bus rules if your child uses school transport.

9. School Property
• Parents are responsible for damage caused intentionally by their child to school property, subject to school policy.
• Encourage your child to respect school facilities, equipment, and learning materials.

10. Platform Usage
• Protect your login credentials and do not share your account with unauthorized persons.
• Use the platform responsibly and only for school-related purposes.
• Do not misuse messaging features or upload inappropriate content.

11. Privacy
• Respect the privacy of other students, parents, teachers, and school staff.
• Do not share confidential school information, student records, or photographs without proper authorization.

12. Emergency Situations
• Keep emergency contact information up to date at all times.
• Authorize the school to seek emergency medical assistance if a parent or guardian cannot be reached.

13. Respect for School Policies
• Follow all school policies, procedures, and future updates communicated through the platform.
• Failure to comply with school policies may result in appropriate administrative action.

14. Consent
By selecting "I Agree", you confirm that:
• You are the parent or legal guardian of the student.
• The information you have provided is true and accurate.
• You agree to comply with all school rules, policies, and regulations.
• You understand that the school may update these policies when necessary and will notify parents through the platform.
''';

  static const oromo = '''
Seeraa fi Dambii Warraa/Eekaa

Waliigaltee Warraa/Eekaa

Ijoollee keessan waltajjii kana irratti galmeessuu fi mana barumsaa irratti galchuu keessatti seeraa fi dambiiwwan armaan gadii dubbisuu, hubachuu fi hordofuu irratti walii galtee qabdu.

1. Argama Barataa
• Ijoolleen keessan yeroo hunda mana barumsaa akka argamu fi yeroo isaa akka gahan mirkaneessaa.
• Ijoolleen keessan yoo hin argamne ykn yoo turee ta'e mana barumsaa battalatti beeksisa.
• Hin argamne sababa hin ibsamne yoo yeroo hedduu ta'e raawwii barnoota ijoollee keessan ni dhiphisa.

2. Odeeffannoo Fayyaa
• Yeroo galmeessuu odeeffannoo fayyaa sirrii fi guutuu kennaa.
• Fayyaa, alerjii, qorichoota ykn qunnamtii yeroo balaa ijoollee keessan jijjiiramuu yoo qaba battalatti mana barumsaa beeksisa.
• Dhukkuba namatti babal'atu yoo qabaattee hanga fayyaan deebi'utti mana keessatti qabaa.

3. Qunnamtii
• Beeksisa, hojii manaa, yaadannoo fi ergaa waltajjii mana barumsaa yeroo hunda ilaalaa.
• Qunnamtii barbaachisaa mana barumsaa irraa battalatti deebisaa.
• Barsiisota, bulchitoota fi hojjettoota waliin kabajaan qunnamaa.

4. Amala Barataa
• Ijoolleen keessan seera mana barumsaa hordofuu fi kabajaan akka hojjetu jajjabeessaa.
• Yeroo barbaachisaa taa'aa sirna ajajaa mana barumsaa deeggaraa.
• Warrri muddama amala ilmaan isaanii furuuf mana barumsaa waliin hojjechuu qabu.

5. Deeggarsa Barnootaa
• Ijoolleen keessan hojii manaa, hojii fi pirojektoota yeroo isaanii akka xumuran jajjabeessaa.
• Guddina barnoota ijoollee keessan waltajjii irratti hordofaa.
• Walga'ii warraa ykn konfaransii yoo gaafatamtan hirmaadhaa.

6. Kaffaltii fi Itti Gaafatamummaa Qabeenyaa
• Kaffaltii mana barumsaa fi kaffaltiiwwan hayyamame yeroo isaanii kaffalaa.
• Kaffaltii hin kaffalamne tajaajila tokko tokko akka hin arganne gochuu danda'a, akkasuma imaammata mana barumsaa malle.

7. Odeeffannoo Dhuunfaa
• Odeeffannoon galmeessuu keessatti kennitan sirrii fi dhugaa ta'uu isaa mirkaneessaa.
• Teessoo, bilbila, imeelii ykn qunnamtii yeroo balaa yoo jijjiiramte battalatti haaromsaa.

8. Fudhachuu Ijoollee fi Geejjibaa
• Namoonni hayyamame qofa ijoollee keessan mana barumsaa irraa akka fudhan isaan mirkaneessaa.
• Namni biraa ijoollee keessan fudhachuuf yoo jira dursee mana barumsaa beeksisa.
• Ijoolleen keessan geejjibaa mana barumsaa yoo fayyadaman seera geejjibaa hordofaa.

9. Qabeenya Mana Barumsaa
• Warri ijoollee isaanii fedhii qabuun qabeenya mana barumsaa miidhan yoo uumani itti gaafatamummaa qabu, akkasuma imaammata mana barumsaa malle.
• Ijoolleen keessan bakka barnootaa, meeshaalee fi qabeenya barnootaa kabajuu jajjabeessaa.

10. Fayyadama Waltajjii
• Jecha iccitii keessan eegaa fi akkaawuntii keessan namoota hin hayyamneef hin qoodinaa.
• Waltajjii fayyadamuun itti gaafatamummaa qabuun hojii mana barumsaa qofaaf.
• Amaloota ergaa dogoggoraan hin fayyadaminaa, qabiyyee sirrii hin taane hin ol kaa'inaa.

11. Iccitii
• Iccitii barattoota, warra, barsiisotaa fi hojjettoota biroo kabajaa.
• Odeeffannoo iccitii mana barumsaa, galmee barataa ykn suuraa hayyama malee hin qoodinaa.

12. Haala Balaa
• Odeeffannoo qunnamtii yeroo balaa yeroo hunda haaromsaa.
• Warri/eekni argamuu yoo dide mana barumsaa gargaarsa fayyaa yeroo balaa argachuuf hayyama.

13. Kabaja Imaammata Mana Barumsaa
• Imaammata, tartiiba fi haaromsa waltajjii irratti beeksisame hunda hordofaa.
• Imaammata hin hordofne tarkaanfii bulchiinsaa sirrii fudhachuu danda'a.

14. Hayyama
"I Agree" ykn "Nan fudhadha" filachuun mirkaneessitu:
• Barataa sana warra ykn eeka seera qabeessa ta'uu kee.
• Odeeffannoon kennite dhugaa fi sirrii ta'uu isaa.
• Seera, imaammata fi dambiiwwan mana barumsaa hunda hordofuu irratti walii galtee qabdu.
• Mana barumsaa yeroo barbaachisaa imaammata haaromsuu fi warra waltajjii irratti beeksisu akka hubattu.
''';
}
