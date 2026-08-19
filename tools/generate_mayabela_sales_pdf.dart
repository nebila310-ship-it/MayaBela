// Generates docs/MayaBela_Product_Guide_Sales.pdf
// Run: dart run tools/generate_mayabela_sales_pdf.dart

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final doc = pw.Document(
    title: 'MayaBela — Product Guide (Sales)',
    author: 'MayaBela',
    subject: 'School ERP product overview for sales and onboarding',
  );

  final accent = PdfColor.fromInt(0xFF0F766E);
  final ink = PdfColor.fromInt(0xFF0F172A);
  final muted = PdfColor.fromInt(0xFF475569);
  final soft = PdfColor.fromInt(0xFFF1F5F9);
  final line = PdfColor.fromInt(0xFFCBD5E1);

  pw.Widget h1(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
      );

  pw.Widget h2(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 12.5,
            fontWeight: pw.FontWeight.bold,
            color: ink,
          ),
        ),
      );

  pw.Widget body(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 10, height: 1.35, color: muted),
        ),
      );

  pw.Widget bullet(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(left: 6, bottom: 2.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 4,
              height: 4,
              margin: const pw.EdgeInsets.only(top: 3.5, right: 6),
              decoration: pw.BoxDecoration(color: accent, shape: pw.BoxShape.circle),
            ),
            pw.Expanded(
              child: pw.Text(
                text,
                style: pw.TextStyle(fontSize: 9.8, height: 1.32, color: muted),
              ),
            ),
          ],
        ),
      );

  pw.Widget card(String title, List<String> items) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: soft,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: line, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
            pw.SizedBox(height: 4),
            ...items.map(bullet),
          ],
        ),
      );

  pw.Widget kvTable(List<List<String>> rows) => pw.TableHelper.fromTextArray(
        headers: rows.first,
        data: rows.skip(1).toList(),
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: PdfColors.white,
        ),
        headerDecoration: pw.BoxDecoration(color: accent),
        cellStyle: pw.TextStyle(fontSize: 9, color: muted),
        cellAlignment: pw.Alignment.centerLeft,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        border: pw.TableBorder.all(color: line, width: 0.4),
      );

  // Cover
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(22),
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MayaBela',
                  style: pw.TextStyle(
                    fontSize: 34,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'School ERP — Product Guide for Sales',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.white),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'From A to Z: who uses it, what each module does,\n'
                  'pricing, onboarding, and support.',
                  style: pw.TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: PdfColor.fromInt(0xFFCCFBF1),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 28),
          body(
            'MayaBela is a cloud school management system for Ethiopian schools. '
            'It combines a web ERP for school administration with role-based portals '
            'for teachers, parents, students, and bus drivers — all under one school ID, '
            'with secure multi-school isolation.',
          ),
          pw.SizedBox(height: 14),
          h2('At a glance'),
          bullet('Live web ERP: https://mayabela.pages.dev'),
          bullet('Android pilot APK for parents, teachers, drivers, and staff'),
          bullet('Languages: English, Amharic, and Oromo labels in the product'),
          bullet('Billing model: per active student / month (ETB), with a monthly minimum'),
          bullet('Platform owner console for creating and managing schools'),
          pw.SizedBox(height: 18),
          h2('Document purpose'),
          body(
            'This guide is for sales conversations, proposals, and school demos. '
            'It explains the software by audience and by functional category so a '
            'buyer can see what they are purchasing end-to-end.',
          ),
          pw.Spacer(),
          pw.Divider(color: line),
          pw.SizedBox(height: 6),
          pw.Text(
            'Support: +251 911 646 444  ·  nabilmaya6464@gmail.com\n'
            'Hours: Mon–Sat, 09:00–18:00 East Africa Time',
            style: pw.TextStyle(fontSize: 9, color: muted, height: 1.4),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated for sales use · ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
            style: pw.TextStyle(fontSize: 8, color: line),
          ),
        ],
      ),
    ),
  );

  // Who it's for + how it works
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (c) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MayaBela Product Guide',
                style: pw.TextStyle(fontSize: 8, color: accent)),
            pw.Text('Who uses the software',
                style: pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${c.pageNumber}',
          style: pw.TextStyle(fontSize: 8, color: muted),
        ),
      ),
      build: (context) => [
        h1('1. Who MayaBela is for'),
        body(
          'Every school gets its own School ID. Users sign in with that School ID '
          'plus their role credentials. Data for one school is not visible to another.',
        ),
        card('Platform owner (you / Maya)', [
          'Create and activate schools from the Platform Console',
          'Set billing rate, minimum monthly bill, contracted seats, and expiry',
          'Issue school admin phone + temporary password',
          'Track onboarding checklist and subscription health',
          'Bulk SMS, audit log, and schools CSV export',
        ]),
        card('School Admin / Owner', [
          'Full web ERP control of the school',
          'Campuses, classes, staff, students, finance views, inventory, transport',
          'Approve parent links; configure student portal and grade workflow',
          'Must change temporary password on first login',
        ]),
        card('Teachers', [
          'Homeroom and subject teachers',
          'Attendance, grade entry, homework, learning materials',
          'QR entry/exit, timetable, messaging, Maya Assistant',
          'Homeroom: parent-link related approvals where granted',
        ]),
        card('Administration staff (role-based)', [
          'Assignable templates: Principal, Vice Principal, Section Director, Registrar, Finance, HR, Librarian, Procurement, Store Keeper, Transport, QA, Board, and more',
          'Module permissions follow the EDUABA matrix (plus custom overrides)',
          'Web ERP modules appear according to grants',
        ]),
        card('Parents', [
          'Link a child with Student ID + date of birth (school approval)',
          'View attendance, published grades, homework, materials',
          'Fees view, live bus map (when transport is used), leave / student affairs',
          'Messages, calendar, timetable, Maya Assistant',
        ]),
        card('Students', [
          'School-configurable student portal',
          'Profile, grades, homework, materials, attendance, timetable, announcements',
          'Messaging only if the school enables it',
        ]),
        card('Drivers', [
          'Route and passenger list',
          'QR scan for pickup / discharge',
          'Share live GPS location for parent tracking',
          'Messages and issue reporting',
        ]),
        h1('2. How access works (simple path)'),
        bullet('Platform owner creates the school → School ID + admin login are issued'),
        bullet('School admin logs in on web → changes password → sets up structure'),
        bullet('Admin enrolls students and staff → shares each user’s temp password once'),
        bullet('Teachers mark attendance and enter grades → approvers publish grades'),
        bullet('Parents link children → see published academic and fee information'),
        bullet('Optional: buses + drivers → parents track the bus live'),
      ],
    ),
  );

  // Modules A–Z categories
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (c) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MayaBela Product Guide',
                style: pw.TextStyle(fontSize: 8, color: accent)),
            pw.Text('Modules by category',
                style: pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${c.pageNumber}',
            style: pw.TextStyle(fontSize: 8, color: muted)),
      ),
      build: (context) => [
        h1('3. Modules & functions (by category)'),
        body(
          'Below is the product broken into sales-friendly categories. '
          'Web ERP is the primary staff channel; mobile/APK is strongest for '
          'teachers, parents, students, and drivers.',
        ),
        h2('A. Academics'),
        bullet('Grade levels, classes/sections, subjects, teacher assignment'),
        bullet('Timetables and daily class activities'),
        bullet('Homework assign and view (teacher / parent / student)'),
        bullet('Learning materials and e-books'),
        bullet('Library catalog and rentals (web)'),
        bullet('School calendar, events, and gallery'),
        bullet('Quality Assurance findings and improvement plans (web)'),
        h2('B. Admissions & student records'),
        bullet('Enroll students with Student ID and date of birth (needed for parent linking)'),
        bullet('Student directory / tables on web'),
        bullet('Internal transfers, external leave, and class promotion'),
        bullet('Student Affairs: discipline cases and parent leave requests'),
        bullet('Student portal settings (what students can see/do)'),
        bullet('Admin student password reset'),
        h2('C. Attendance'),
        bullet('Teachers mark class attendance on mobile'),
        bullet('QR-based entry / exit support'),
        bullet('Admin attendance reports on web'),
        bullet('Parent and student attendance views'),
        h2('D. Grades & report cards path'),
        bullet('Teacher enters grades and submits for approval'),
        bullet('Section Director / examiners approve → publish to parents'),
        bullet('Admin grade overview and workflow settings'),
        bullet('Role-specific grade views for teacher, parent, and student'),
        h2('E. Finance & fees'),
        bullet('Web finance dashboard: collected, outstanding, today, overdue'),
        bullet('Fee status table in ETB; 7-day income snapshot'),
        bullet('Parent fees & payments view'),
        bullet('Permissions for manage fees, record payments, finance reports'),
        bullet('Positioning: school fee tracking — not a full accounting/GL package'),
        h2('F. HR & staff directory'),
        bullet('HR hub: classroom teachers, other employees, transport staff'),
        bullet('Administration staff directory'),
        bullet('Role permission editor (module checkboxes per role)'),
        bullet('Multi-role staff accounts with temporary passwords'),
        h2('G. Inventory & procurement'),
        bullet('Purchase requests and issue requests'),
        bullet('Items, stock in/out, student issued items, classroom inventory'),
        bullet('Assets, suppliers, maintenance records'),
        bullet('Inventory reports'),
        h2('H. Transport'),
        bullet('Bus registry and transport dashboard'),
        bullet('Assign students / Bus Link IDs for parent tracking'),
        bullet('Driver app: route, passengers, QR scan, live GPS'),
        bullet('Parent live bus map'),
        bullet('Transport reports export'),
      ],
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (c) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MayaBela Product Guide',
                style: pw.TextStyle(fontSize: 8, color: accent)),
            pw.Text('Modules · Platform · Pricing',
                style: pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${c.pageNumber}',
            style: pw.TextStyle(fontSize: 8, color: muted)),
      ),
      build: (context) => [
        h2('I. Communication'),
        bullet('School announcements (role-gated create)'),
        bullet('In-app messaging across admin, teacher, parent, driver (student optional)'),
        bullet('Notifications'),
        bullet('Maya Assistant helper for major roles'),
        bullet('Platform-owner bulk SMS tool'),
        h2('J. Parent portal'),
        bullet('Signup / link child → pending → school approval'),
        bullet('Children hub with attendance, grades, homework, materials'),
        bullet('Fees, bus tracking, student affairs, calendar, timetable, settings'),
        h2('K. Student portal'),
        bullet('Enabled per school; first-login and forgot-password flows'),
        bullet('Profile, grades, homework, materials, attendance, timetable, calendar'),
        bullet('Announcements; messaging only if school turns it on'),
        h2('L. Reports & exports'),
        bullet('Web report packs: Students, Attendance, Academic, Financial, Transport, Teachers, Inventory'),
        bullet('Export Excel / CSV / PDF'),
        h2('M. Platform Console (multi-school control)'),
        bullet('Create school in cloud: name, city, grades, campuses, logo'),
        bullet('Set rate/student/month, minimum monthly, seats, subscription expiry'),
        bullet('Issue admin credentials (unique temp password)'),
        bullet('Onboarding checklist: logo → admin → first student → first parent link → active'),
        bullet('Filter schools (active / blocked / expiring); reload from cloud'),
        bullet('Audit log and schools CSV export'),
        h2('N. Security & school isolation'),
        bullet('School ID required for staff/parent/driver login'),
        bullet('Forced first-login password change (minimum 10 characters; no OTP required for change)'),
        bullet('Per-school cloud isolation (RLS) and role-based permissions'),
        bullet('Web idle session timeout for admin sessions'),
        bullet('Audit logging and system health visibility'),
        h1('4. Channels: Web + Mobile'),
        kvTable([
          ['Channel', 'Best for'],
          [
            'Web ERP (mayabela.pages.dev)',
            'School admin & staff daily operations; Platform Console'
          ],
          [
            'Android APK (pilot sideload)',
            'Parents, teachers, drivers, staff on phones'
          ],
          [
            'Home-screen web shortcut',
            'Quick access when APK install is not preferred'
          ],
        ]),
        pw.SizedBox(height: 10),
        h1('5. Pricing (ETB)'),
        body(
          'Default product billing matches Platform Console fields. '
          'Teachers, parents, drivers, and staff accounts are not billed per seat — '
          'only active / enrolled students.',
        ),
        pw.SizedBox(height: 6),
        kvTable([
          ['Item', 'Amount'],
          ['Per active student / month', '8 ETB (default)'],
          ['Minimum monthly bill', '500 ETB'],
          [
            'Formula',
            'max(active students × rate, minimum); 0 if no students'
          ],
          ['Contracted seats', 'Optional capacity cap; overage flagged'],
          [
            'Annual quote option',
            '10 months prepaid = 2 months courtesy (proposal language)'
          ],
        ]),
        pw.SizedBox(height: 8),
        h2('Suggested commercial tiers'),
        kvTable([
          ['Tier', 'Seats', 'Notes'],
          ['Pilot', '≤ 150', '30–60 days; web + APK'],
          ['Standard', '≤ 500', 'Full modules'],
          ['Campus+', 'Custom', 'Multi-campus / training; negotiated rate'],
        ]),
        pw.SizedBox(height: 8),
        h2('Examples'),
        kvTable([
          ['Active students', 'Monthly bill'],
          ['0', '0 ETB'],
          ['40', '500 ETB (minimum)'],
          ['100', '800 ETB'],
          ['500', '4,000 ETB'],
        ]),
      ],
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (c) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MayaBela Product Guide',
                style: pw.TextStyle(fontSize: 8, color: accent)),
            pw.Text('Onboarding · Included · Support',
                style: pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${c.pageNumber}',
            style: pw.TextStyle(fontSize: 8, color: muted)),
      ),
      build: (context) => [
        h1('6. What is included vs not'),
        h2('Included'),
        bullet('Web ERP + mobile/pilot APK access model'),
        bullet('School isolation, roles & permissions'),
        bullet('Students, attendance, grade approve→publish, parent links'),
        bullet('Fees view, transport/live bus, inventory & procurement'),
        bullet('Reports (Excel / CSV / PDF), announcements, messaging, Maya Assistant'),
        bullet('Platform Console: create school, seats, rate, expiry, onboarding checklist'),
        bullet('Unique temp passwords with forced first-login change'),
        h2('Not included (unless separately contracted)'),
        bullet('Custom development / brand-new modules'),
        bullet('On-site hardware (biometrics, school servers)'),
        bullet('SMS / voice gateway carrier fees'),
        bullet('Google Play / App Store developer account fees'),
        bullet('Large third-party SIS migrations beyond agreed pilot scope'),
        bullet('24/7 phone SLA'),
        h1('7. Onboarding path (Day 0 → go-live)'),
        h2('A. Platform owner — Day 0'),
        bullet('Open Platform Console → Add school (cloud create)'),
        bullet('Set grades, campuses, rate, minimum, seats, expiry'),
        bullet('Issue admin phone + temp password; confirm Active status'),
        bullet('Watch checklist: logo → admin → first student → first parent → active'),
        h2('B. School admin — Day 1'),
        bullet('Login with School ID + phone + temp password'),
        bullet('Change password (min 10 characters)'),
        bullet('Create campuses / classes as needed'),
        bullet('Enroll students; add teachers and administration staff'),
        bullet('Approve first parent link requests'),
        bullet('Optional: buses + drivers + Bus Link IDs'),
        h2('C. First operational week'),
        kvTable([
          ['Day', 'Focus'],
          ['1', 'Rosters + staff logins working'],
          ['2', 'Teachers: attendance + enter grades'],
          ['3', 'Approve grades → parents can see published results'],
          ['4', 'Parents: link child + fees + bus (if used)'],
          ['5', 'Reports PDF/Excel; inventory smoke test if used'],
        ]),
        h1('8. Demo / pilot reference'),
        bullet('Demo school commonly used in product: Maya School · School ID TB-001'),
        bullet('Primary live URL for demos: https://mayabela.pages.dev'),
        bullet('After web updates, hard-refresh with Ctrl+Shift+R'),
        bullet('Android pilot APK: sideload app-release.apk (package com.mayabela.app)'),
        h1('9. Support'),
        body(
          'Give schools a clear contact path. Before calling, they should note School ID '
          'and role, hard-refresh web or reinstall APK, and confirm first-login password change.',
        ),
        pw.SizedBox(height: 6),
        kvTable([
          ['Channel', 'Detail'],
          ['Phone / WhatsApp', '+251 911 646 444'],
          ['Email', 'nabilmaya6464@gmail.com'],
          ['Web', 'https://mayabela.pages.dev'],
          ['Hours', 'Mon–Sat, 09:00–18:00 EAT (urgent: call / WhatsApp)'],
        ]),
        pw.SizedBox(height: 8),
        h2('We help with'),
        bullet('Login / password / first-time access'),
        bullet('Role access (who can see which module)'),
        bullet('Sync / data missing across devices'),
        bullet('Pilot APK install and web ERP navigation'),
        bullet('Billing fields (seats, rate, subscription expiry)'),
        pw.SizedBox(height: 16),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: accent, width: 1),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'One-sentence sales pitch',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: ink,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'MayaBela is a cloud school ERP that connects school admin, teachers, '
                'parents, students, and drivers in one secure School ID — with web for '
                'operations, mobile for daily use, and simple per-student ETB billing.',
                style: pw.TextStyle(fontSize: 10, height: 1.35, color: muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  final out = File('docs/MayaBela_Product_Guide_Sales.pdf');
  await out.parent.create(recursive: true);
  await out.writeAsBytes(await doc.save());
  stdout.writeln('Wrote ${out.path} (${await out.length()} bytes)');
}
