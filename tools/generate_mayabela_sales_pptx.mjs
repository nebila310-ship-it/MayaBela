/**
 * MayaBela detailed sales PowerPoint — portals, roles, problem-solving.
 * Run: cd tools && node generate_mayabela_sales_pptx.mjs
 */
import { createRequire } from 'module';
import { mkdirSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(__dirname, 'package.json'));
const pptxgen = require('pptxgenjs');
const outPath = join(
  __dirname,
  '..',
  'docs',
  'MayaBela_Detailed_Sales_Presentation.pptx',
);

const C = {
  teal: '0F766E',
  tealDark: '115E59',
  ink: '0F172A',
  muted: '475569',
  soft: 'F1F5F9',
  white: 'FFFFFF',
  accentSoft: 'CCFBF1',
  line: 'CBD5E1',
  orange: 'C2410C',
  cream: 'FFF7ED',
};

const pptx = new pptxgen();
pptx.author = 'MayaBela';
pptx.title = 'MayaBela — Detailed Sales Presentation';
pptx.subject =
  'Portals, roles, and problem-solving guide for school ERP sales';
pptx.layout = 'LAYOUT_WIDE';

let TOTAL = 0; // set after slides built
const slidesMeta = [];

function addFooter(slide, page) {
  slide.addText('MayaBela · Detailed Sales Guide · EN / አማርኛ / Afaan Oromo', {
    x: 0.4,
    y: 7.15,
    w: 10.5,
    h: 0.25,
    fontSize: 9,
    color: C.muted,
    fontFace: 'Calibri',
  });
  slide.addText(String(page), {
    x: 11.8,
    y: 7.15,
    w: 1.0,
    h: 0.25,
    fontSize: 9,
    color: C.muted,
    fontFace: 'Calibri',
    align: 'right',
  });
}

function sectionBar(slide, title, subtitle) {
  slide.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 13.333,
    h: subtitle ? 1.05 : 0.85,
    fill: { color: C.teal },
  });
  slide.addText(title, {
    x: 0.45,
    y: 0.15,
    w: 12.4,
    h: 0.4,
    fontSize: 22,
    bold: true,
    color: C.white,
    fontFace: 'Calibri',
  });
  if (subtitle) {
    slide.addText(subtitle, {
      x: 0.45,
      y: 0.55,
      w: 12.4,
      h: 0.35,
      fontSize: 12,
      color: C.accentSoft,
      fontFace: 'Calibri',
    });
  }
}

function bullets(slide, items, opts) {
  const {
    x = 0.5,
    y = 1.3,
    w = 12.3,
    fontSize = 13,
    color = C.ink,
    gap = 0.38,
  } = opts || {};
  items.forEach((t, i) => {
    slide.addText('•  ' + t, {
      x,
      y: y + i * gap,
      w,
      h: gap,
      fontSize,
      color,
      fontFace: 'Calibri',
      valign: 'top',
    });
  });
}

function twoColCards(slide, left, right, y0 = 1.25) {
  const mk = (card, x) => {
    slide.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y: y0,
      w: 6.05,
      h: 5.5,
      fill: { color: C.soft },
      rectRadius: 0.08,
    });
    slide.addText(card.title, {
      x: x + 0.25,
      y: y0 + 0.2,
      w: 5.55,
      h: 0.4,
      fontSize: 15,
      bold: true,
      color: C.teal,
      fontFace: 'Calibri',
    });
    card.items.forEach((t, i) => {
      slide.addText('•  ' + t, {
        x: x + 0.25,
        y: y0 + 0.7 + i * 0.42,
        w: 5.55,
        h: 0.42,
        fontSize: 12,
        color: C.ink,
        fontFace: 'Calibri',
      });
    });
  };
  mk(left, 0.45);
  mk(right, 6.8);
}

function portalSlide(cfg) {
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, cfg.title, cfg.subtitle);
  // Who / Login strip
  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.4,
    y: 1.2,
    w: 12.5,
    h: 1.05,
    fill: { color: C.soft },
    rectRadius: 0.06,
  });
  s.addText(
    [
      { text: 'Who: ', options: { bold: true, color: C.teal } },
      { text: cfg.who + '   ', options: { color: C.ink } },
      { text: 'Login: ', options: { bold: true, color: C.teal } },
      { text: cfg.login, options: { color: C.ink } },
    ],
    {
      x: 0.6,
      y: 1.35,
      w: 12.1,
      h: 0.75,
      fontSize: 13,
      fontFace: 'Calibri',
      valign: 'middle',
    },
  );

  s.addText('What they can do', {
    x: 0.45,
    y: 2.4,
    w: 6,
    h: 0.35,
    fontSize: 14,
    bold: true,
    color: C.ink,
    fontFace: 'Calibri',
  });
  bullets(s, cfg.canDo, { x: 0.45, y: 2.8, w: 6.1, fontSize: 12, gap: 0.36 });

  s.addText('Problems it solves', {
    x: 6.9,
    y: 2.4,
    w: 6,
    h: 0.35,
    fontSize: 14,
    bold: true,
    color: C.orange,
    fontFace: 'Calibri',
  });
  bullets(s, cfg.solves, {
    x: 6.9,
    y: 2.8,
    w: 6.0,
    fontSize: 12,
    gap: 0.36,
    color: C.ink,
  });
}

function roleSlide(cfg) {
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, cfg.title, cfg.subtitle || 'EDUABA staff role template');
  s.addText(cfg.summary, {
    x: 0.5,
    y: 1.2,
    w: 12.3,
    h: 0.55,
    fontSize: 13,
    color: C.muted,
    fontFace: 'Calibri',
  });
  twoColCards(
    s,
    { title: 'Responsibilities & modules', items: cfg.does },
    { title: 'Problems this role solves', items: cfg.solves },
    1.85,
  );
}

function themeSlide(cfg) {
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, cfg.title, 'School operating problem → MayaBela solution');
  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.4,
    y: 1.3,
    w: 6.1,
    h: 5.3,
    fill: { color: 'FEF2F2' },
    rectRadius: 0.08,
  });
  s.addText('The problem today', {
    x: 0.65,
    y: 1.5,
    w: 5.6,
    h: 0.4,
    fontSize: 15,
    bold: true,
    color: C.orange,
    fontFace: 'Calibri',
  });
  bullets(s, cfg.pain, { x: 0.65, y: 2.1, w: 5.6, fontSize: 13, gap: 0.5 });

  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 6.8,
    y: 1.3,
    w: 6.1,
    h: 5.3,
    fill: { color: C.soft },
    rectRadius: 0.08,
  });
  s.addText('How MayaBela solves it', {
    x: 7.05,
    y: 1.5,
    w: 5.6,
    h: 0.4,
    fontSize: 15,
    bold: true,
    color: C.teal,
    fontFace: 'Calibri',
  });
  bullets(s, cfg.fix, { x: 7.05, y: 2.1, w: 5.6, fontSize: 13, gap: 0.5 });
}

// ========== BUILD SLIDES ==========

// 1 Cover
{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 13.333,
    h: 7.5,
    fill: { color: C.tealDark },
  });
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 0.22,
    h: 7.5,
    fill: { color: C.accentSoft },
  });
  s.addText('MayaBela', {
    x: 0.7,
    y: 1.6,
    w: 12,
    h: 0.8,
    fontSize: 44,
    bold: true,
    color: C.white,
    fontFace: 'Calibri',
  });
  s.addText('Detailed Sales Presentation', {
    x: 0.7,
    y: 2.45,
    w: 12,
    h: 0.45,
    fontSize: 24,
    color: C.accentSoft,
    fontFace: 'Calibri',
  });
  s.addText(
    'Every portal · Every role · Problems the school OS solves\n'
      + 'Built for Ethiopian schools · Web ERP + mobile · EN / አማርኛ / Afaan Oromo',
    {
      x: 0.7,
      y: 3.2,
      w: 11.5,
      h: 1.0,
      fontSize: 16,
      color: C.white,
      fontFace: 'Calibri',
    },
  );
  s.addText(
    'Live: https://mayabela.pages.dev\n'
      + 'Support: +251 911 646 444  ·  nabilmaya6464@gmail.com',
    {
      x: 0.7,
      y: 5.4,
      w: 11,
      h: 0.8,
      fontSize: 14,
      color: C.accentSoft,
      fontFace: 'Calibri',
    },
  );
}

// 2 Agenda
{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, 'Agenda — what this deck covers');
  const ag = [
    ['A', 'The school operating problem & MayaBela OS overview'],
    ['B', 'All 7 portals / channels — who, login, modules, value'],
    ['C', 'Classroom teachers (Homeroom vs Subject)'],
    ['D', 'Every EDUABA administration role — one by one'],
    ['E', 'Cross-cutting problems MayaBela solves for a school'],
    ['F', 'Pricing, included scope, go-live week, next steps'],
  ];
  ag.forEach((row, i) => {
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x: 0.6,
      y: 1.3 + i * 0.85,
      w: 12.1,
      h: 0.72,
      fill: { color: C.soft },
      rectRadius: 0.06,
    });
    s.addText(row[0], {
      x: 0.85,
      y: 1.42 + i * 0.85,
      w: 0.7,
      h: 0.5,
      fontSize: 20,
      bold: true,
      color: C.teal,
      fontFace: 'Calibri',
    });
    s.addText(row[1], {
      x: 1.7,
      y: 1.45 + i * 0.85,
      w: 10.5,
      h: 0.45,
      fontSize: 16,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
}

// 3 Problem
{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, 'Why schools need a School Operating System');
  bullets(
    s,
    [
      'Attendance lives in paper registers — late, incomplete, hard to audit',
      'Grades stay in notebooks — parents chase report cards; early leaks happen',
      'Parent communication is WhatsApp chaos — no official trail',
      'Bus boarding and location are unknown until a phone call',
      'Fee balances are opaque until conflict arises',
      'Inventory and purchases run on verbal orders and paper books',
      'Shared “admin” passwords — no least privilege across departments',
      'Multi-campus or multi-school operators juggle separate spreadsheets',
      'English-only tools shut out Amharic / Afaan Oromo users',
    ],
    { y: 1.3, gap: 0.55, fontSize: 15 },
  );
}

// 4 OS overview
{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, 'MayaBela as a School Operating System');
  s.addText(
    'One School ID. Seven channels. Role-based access. Cloud isolation between schools.',
    {
      x: 0.5,
      y: 1.15,
      w: 12.3,
      h: 0.4,
      fontSize: 15,
      color: C.muted,
      fontFace: 'Calibri',
    },
  );
  const pillars = [
    ['Govern', 'Platform Console provisions schools, pricing, seats, expiry'],
    ['Operate', 'Web ERP runs academics, people, finance view, store, transport'],
    ['Teach', 'Teachers mark attendance, enter grades, assign homework'],
    ['Engage', 'Parents & students see published truth, fees, bus, messages'],
    ['Move', 'Drivers scan boarding and share live GPS'],
    ['Secure', 'Named accounts, forced password change, RBAC, audit'],
  ];
  pillars.forEach((p, i) => {
    const x = 0.4 + (i % 3) * 4.25;
    const y = 1.8 + Math.floor(i / 3) * 2.4;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y,
      w: 4.05,
      h: 2.1,
      fill: { color: C.soft },
      rectRadius: 0.08,
    });
    s.addText(p[0], {
      x: x + 0.2,
      y: y + 0.35,
      w: 3.65,
      h: 0.45,
      fontSize: 18,
      bold: true,
      color: C.teal,
      fontFace: 'Calibri',
    });
    s.addText(p[1], {
      x: x + 0.2,
      y: y + 0.95,
      w: 3.65,
      h: 0.85,
      fontSize: 13,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
}

// 5 Portal map
{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, 'Portal map — 7 channels');
  const portals = [
    ['1', 'Platform Console', 'You (Maya owner)'],
    ['2', 'Web ERP / School Admin', 'School owner & head admin'],
    ['3', 'Administration Staff', 'Registrar, Finance, VP…'],
    ['4', 'Teacher', 'Homeroom & Subject'],
    ['5', 'Parent / Guardian', 'Families'],
    ['6', 'Student', 'Learners (portal on)'],
    ['7', 'Driver / Transport', 'Bus operators'],
  ];
  portals.forEach((p, i) => {
    const y = 1.25 + i * 0.75;
    s.addShape(pptx.shapes.OVAL, {
      x: 0.6,
      y: y + 0.05,
      w: 0.55,
      h: 0.55,
      fill: { color: C.teal },
    });
    s.addText(p[0], {
      x: 0.6,
      y: y + 0.12,
      w: 0.55,
      h: 0.4,
      fontSize: 14,
      bold: true,
      color: C.white,
      align: 'center',
      fontFace: 'Calibri',
    });
    s.addText(p[1], {
      x: 1.4,
      y: y + 0.1,
      w: 5.5,
      h: 0.45,
      fontSize: 18,
      bold: true,
      color: C.ink,
      fontFace: 'Calibri',
    });
    s.addText(p[2], {
      x: 7.2,
      y: y + 0.1,
      w: 5.5,
      h: 0.45,
      fontSize: 16,
      color: C.muted,
      fontFace: 'Calibri',
    });
  });
}

// ===== PORTALS =====
portalSlide({
  title: 'Portal 1 — Platform Console',
  subtitle: 'Multi-school control plane (not a school staff login)',
  who: 'Platform owner only (hidden gesture + PIN). Never share PIN with schools.',
  login: 'Login screen → tap logo 7× in 4s → enter owner PIN → Platform Console.',
  canDo: [
    'Create school in cloud (School ID, grades, campuses, logo)',
    'Set rate/student/month, minimum bill, contracted seats, expiry',
    'Issue school admin phone + unique temporary password',
    'Filter schools: Active / Expiring / Blocked / Needs attention',
    'Onboarding checklist: logo → admin → student → parent → active',
    'Enrollment / billable metrics and seat overage flags',
    'Bulk SMS (e.g. renewals), audit log, CSV/JSON backup export',
    'Maya Assistant for owner questions',
  ],
  solves: [
    'Stops multi-school chaos of separate spreadsheets',
    'Standardizes pricing & subscription expiry per school',
    'Gives clean admin credential handoff (not shared passwords)',
    'Shows which schools are behind on onboarding',
    'Alerts renewals before access becomes a surprise',
    'Keeps owner control separate from school ERP logins',
  ],
});

portalSlide({
  title: 'Portal 2 — Web ERP / School Admin',
  subtitle: 'Primary operating console for the school owner',
  who: 'School owner / head admin (roleKey = admin). Full ERP access.',
  login: 'School ID + phone/username + password. First login: forced password change (min 10 chars, no OTP).',
  canDo: [
    'Organization: Dashboard, School & Campus Management',
    'Academics: Academic Mgmt, Examinations & Grade Approvals, Attendance, Classroom Teachers',
    'Student Services: Students, Student Affairs, Parent Link Approvals, Transfers & Promotion',
    'Finance Branch: Finance dashboard, Inventory / Procurement / Store',
    'HR Branch: HR hub, Administration Staff Directory, Transport, Buses',
    'Learning: Library, e-Books & Materials',
    'Communication: Announcements, Events & Gallery, Calendar, Messages',
    'QA, Reports (Excel/CSV/PDF), Role Permissions, Audit Log, System Health, Settings',
  ],
  solves: [
    'Replaces paper/Excel department silos with one ERP',
    'Defines who can do what via EDUABA Role Permissions',
    'Stops grade leaks — approve → publish before parents see',
    'Structures multi-campus operations under one School ID',
    'Centralizes people onboarding (students, teachers, staff)',
    'Gives owner a single place for ops + reports',
  ],
});

portalSlide({
  title: 'Portal 3 — Administration Staff',
  subtitle: 'Named department accounts with least privilege',
  who: 'Non-classroom staff with EDUABA roles (Registrar, Finance, VP, Store…)',
  login: 'School ID + phone/username + password → web ERP and/or mobile staff tiles filtered by permissions.',
  canDo: [
    'See only modules granted by their role allocation',
    'Shared chrome: dashboard, profile, settings, logout, Maya Assistant',
    'Examples when granted: students, attendance, finance, inventory, transport,',
    'grade approvals, parent approvals, HR, library, announcements, reports, audit',
    'Mobile staff home mirrors permission-gated tiles',
    'Works alongside classroom teachers without sharing owner login',
  ],
  solves: [
    'Ends “everyone uses the admin password” culture',
    'Least privilege — Finance cannot rewrite Role Permissions',
    'Department accountability with named accounts',
    'Executives can oversee without doing every data-entry task',
    'Custom roles for school-specific job titles',
  ],
});

portalSlide({
  title: 'Portal 4 — Teacher',
  subtitle: 'Classroom operations for Homeroom and Subject teachers',
  who: 'Classroom teachers (Homeroom and/or Subject assignment).',
  login: 'Role Teacher · School ID + phone/username + password · forced first password change.',
  canDo: [
    'My classroom: classes, attendance, parent approvals (homeroom), student affairs',
    'Teaching tools: homework, grades entry, timetable, learning materials, QR',
    'Homeroom extras: gallery, create announcements/calendar items, leave decisions',
    'Communication: messages, read announcements, calendar',
    'Submit grades into the approval chain (not auto-visible to parents)',
    'Maya Assistant + Settings',
  ],
  solves: [
    'Paper attendance registers → digital, auditable marks',
    'Grade notebooks → structured entry into publish workflow',
    'Homeroom becomes class–home bridge for parent links & leave',
    'QR entry/exit supports gate control workflows',
    'Homework and materials reach parents/students digitally',
  ],
});

portalSlide({
  title: 'Portal 5 — Parent / Guardian',
  subtitle: 'Official family channel — not informal WhatsApp',
  who: 'Parents and guardians linked to one or more students.',
  login: 'Role Parent · School ID + phone + password. Sign-up: register + Student ID + DOB → pending until school approves.',
  canDo: [
    'Children hub: attendance, published grades, homework, learning materials, timetable',
    'School updates: messages, announcements, calendar',
    'Services: fees view, bus live map (Bus Link), student affairs / leave requests',
    'Maya Assistant for guided help',
    'Settings / language preference',
    'See grades only after school approval & publish',
  ],
  solves: [
    '“Is my child at school?” → attendance view',
    'Report-card chase → published grades when ready',
    'Fee surprises → fees & balance visibility',
    'Bus anxiety → live map when transport is enabled',
    'Leave requests without endless phone calls',
    'Official messages instead of group-chat rumors',
  ],
});

portalSlide({
  title: 'Portal 6 — Student',
  subtitle: 'Learner portal (school-configurable)',
  who: 'Students — portal enabled by school (default minimum grade 7, configurable).',
  login: 'Role Student · School ID + username or Student ID + password (temp from school; forced change).',
  canDo: [
    'Profile, published grades, homework, learning materials',
    'Own attendance view, timetable, calendar, announcements',
    'Messages only if school enables allowStudentMessaging',
    'Optional homework upload / report download / class rank (admin knobs)',
    'Maya Assistant + Settings',
    'Admin can reset student passwords and portal settings',
  ],
  solves: [
    'Lost homework slips → digital assignments & materials',
    'Opaque progress → student sees published grades',
    'Age-appropriate access controlled by school settings',
    'Reduces “ask a friend for the notes” friction',
  ],
});

portalSlide({
  title: 'Portal 7 — Driver / Transport',
  subtitle: 'On-the-road operations for bus safety visibility',
  who: 'Bus drivers linked to a school bus (login role labeled Transport).',
  login: 'School ID + phone + password (temp issued by school). Must be linked to a bus.',
  canDo: [
    'Route view and passenger list for the assigned bus',
    'Share live GPS location while on route',
    'QR scan for onboard and pickup/discharge',
    'Messages, read announcements, report issue, calendar',
    'Maya Assistant + Settings',
    'Parents see live map when Bus Link is assigned',
  ],
  solves: [
    'Paper passenger lists → digital roster',
    '“Did they board?” → QR onboard/discharge trail',
    '“Where is the bus?” → live map for parents',
    'Incident-only phone calls → in-app issue reporting',
  ],
});

// Teacher types
{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, 'Classroom teacher types — Homeroom vs Subject');
  twoColCards(
    s,
    {
      title: 'Homeroom teacher',
      items: [
        'Owns a class section as home base',
        'Attendance for the class',
        'Parent link approvals for the class',
        'Gallery + create announcements/calendar',
        'Leave decisions & behaviour reports',
        'Full teacher dashboard tile set',
        'Bridge between school office and families',
      ],
    },
    {
      title: 'Subject teacher',
      items: [
        'Teaches assigned subjects/classes',
        'Attendance on assigned classes',
        'Homework, materials, grades for subjects',
        'QR tools where used',
        'Restricted tiles by default',
        'No gallery / announce-create / parent-approvals unless also homeroom',
        'Feeds grades into approve → publish chain',
      ],
    },
    1.25,
  );
}

{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, 'Grade workflow — protect parents from drafts');
  s.addText('Default chain (configurable in Grade Workflow Settings)', {
    x: 0.5,
    y: 1.2,
    w: 12,
    h: 0.35,
    fontSize: 14,
    color: C.muted,
    fontFace: 'Calibri',
  });
  const steps = [
    ['1', 'Enter', 'Subject / class teacher enters marks'],
    ['2', 'Submit', 'Grades go pending — not parent-visible'],
    ['3', 'Approve', 'Section Director (or configured approver)'],
    ['4', 'Publish', 'Parents & students see results; notify'],
  ];
  steps.forEach((st, i) => {
    const x = 0.5 + i * 3.2;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y: 2.0,
      w: 3.0,
      h: 3.5,
      fill: { color: C.soft },
      rectRadius: 0.08,
    });
    s.addText(st[0], {
      x,
      y: 2.3,
      w: 3.0,
      h: 0.5,
      fontSize: 28,
      bold: true,
      color: C.teal,
      align: 'center',
      fontFace: 'Calibri',
    });
    s.addText(st[1], {
      x: x + 0.15,
      y: 3.0,
      w: 2.7,
      h: 0.5,
      fontSize: 18,
      bold: true,
      color: C.ink,
      align: 'center',
      fontFace: 'Calibri',
    });
    s.addText(st[2], {
      x: x + 0.2,
      y: 3.7,
      w: 2.6,
      h: 1.4,
      fontSize: 13,
      color: C.muted,
      align: 'center',
      fontFace: 'Calibri',
    });
  });
}

// Role section divider
{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 13.333,
    h: 7.5,
    fill: { color: C.teal },
  });
  s.addText('EDUABA Administration Roles', {
    x: 0.7,
    y: 2.6,
    w: 12,
    h: 0.7,
    fontSize: 34,
    bold: true,
    color: C.white,
    fontFace: 'Calibri',
  });
  s.addText(
    'Each role is a permission template (EN / Amharic / Afaan Oromo labels).\n'
      + 'School owner can customize modules (except Full Access). Custom roles supported.',
    {
      x: 0.7,
      y: 3.5,
      w: 11.5,
      h: 1.0,
      fontSize: 16,
      color: C.accentSoft,
      fontFace: 'Calibri',
    },
  );
}

roleSlide({
  title: 'Role — Full Access (School Owner)',
  subtitle: 'ownerOnly · all permissions · not customizable',
  summary:
    'The school’s accountable operator inside the ERP. Separate from the Platform Console PIN.',
  does: [
    'Full Web ERP including Role Permissions',
    'Hire/manage staff & classroom teachers',
    'Campuses, academics, finance, inventory, transport',
    'Grade workflow & student portal settings',
    'Institution Management points to Platform Console',
    'Audit log & system health',
    'All modules and overrides',
  ],
  solves: [
    'One owner account without sharing Platform PIN',
    'Can configure every department’s access',
    'End-to-end accountability for school data',
    'Safe place to set policy (grades, portal, campuses)',
  ],
});

roleSlide({
  title: 'Role — School Board',
  subtitle: 'Oversight · mostly read / report access',
  summary: 'Governance visibility without day-to-day editing rights.',
  does: [
    'View students, staff, grades (as allocated)',
    'View finance reports & departmental summaries',
    'Reports & analytics',
    'Audit log visibility',
    'Read-heavy academic/student modules',
  ],
  solves: [
    'Board needs insight without operational risk',
    'Avoids “give board the admin password”',
    'Supports compliance and oversight meetings',
  ],
});

roleSlide({
  title: 'Role — General Manager / Deputy GM',
  subtitle: 'Executive cross-department approvals',
  summary: 'Broad oversight plus key approvals across the school.',
  does: [
    'Wide view across departments',
    'Approve transfers, grades, purchase & issue requests',
    'Announcements & message parents',
    'Manage staff accounts',
    'Audit log (executive oversight)',
    'Support access',
  ],
  solves: [
    'Cross-department bottlenecks need an approver',
    'Staffing decisions without owning every register',
    'Executive visibility with action rights',
  ],
});

roleSlide({
  title: 'Role — Principal',
  subtitle: 'Academic leadership & school communication',
  summary: 'Leads teaching & learning without necessarily owning store/finance books.',
  does: [
    'View students, staff, grades',
    'Approve grades & transfers',
    'Manage classes, subjects, timetables',
    'Announcements & parent messaging',
    'View transport',
    'Support access',
  ],
  solves: [
    'Academic leadership needs control of structure',
    'Official parent communication channel',
    'Grade/transfer accountability at principal level',
  ],
});

roleSlide({
  title: 'Role — Vice Principal',
  subtitle: 'Operational VP hub (legacy: vice_principal)',
  summary: 'Wide operational visibility and manage rights across many modules.',
  does: [
    'View students, staff, inventory, transport, grades, finance',
    'Approve transfers, grades, purchase & issue',
    'Learning materials + material access',
    'Manage/operate: examinations, academic, student affairs,',
    'transfers, HR, classroom teachers, finance, transport,',
    'attendance, parents, inventory, library, QA, reports',
    'Announcements & parent messaging',
  ],
  solves: [
    'Daily ops need a VP who can unblock many queues',
    'Oversight of inventory + academics + parents',
    'Backup capacity when Principal is unavailable',
  ],
});

roleSlide({
  title: 'Role — Section Director',
  subtitle: 'Default grade approver · section academic ops',
  summary: 'Owns section academics and the grade publish gate by default.',
  does: [
    'Manage classes, subjects, teacher assignment, timetables',
    'View & approve grades (publish path)',
    'Manage students; create transfers',
    'Learning materials; parent link approvals',
    'Assign student transport; message parents',
    'Attendance, classroom teachers, events/calendar, library',
  ],
  solves: [
    'Stops unreviewed marks reaching parents',
    'Section-level academic coordination',
    'Parent link approvals close to the class',
  ],
});

roleSlide({
  title: 'Role — Student Affairs',
  subtitle: 'Discipline, leave, welfare coordination',
  summary: 'Handles student welfare workflows and parent-facing affairs messaging.',
  does: [
    'Student Affairs module (manage)',
    'View/manage students as allocated',
    'Parent links; create transfers',
    'Announcements & message parents',
    'Discipline cases & leave coordination screens',
  ],
  solves: [
    'Behaviour cases leave sticky-note chaos',
    'Leave requests become trackable',
    'Welfare messaging without full academic rights',
  ],
});

roleSlide({
  title: 'Role — Registrar',
  subtitle: 'Enrollment, promotion, parent-link operations',
  summary: 'Keeps the student register clean and promotions accurate.',
  does: [
    'Students module with enroll/manage rights',
    'Parent link operations',
    'Create transfers; promote students',
    'Message parents; support',
    'Announcements as allocated',
  ],
  solves: [
    'Admissions backlog and messy IDs',
    'Promotion season without spreadsheet disaster',
    'Parent linking without giving full ERP access',
  ],
});

roleSlide({
  title: 'Role — Finance Manager',
  subtitle: 'Catalog key: accountant · fee & payment operations',
  summary: 'Owns fee visibility and payment recording; finance-side purchase approval.',
  does: [
    'Manage fees & record payments',
    'Finance reports & dashboard views',
    'View students for billing context',
    'Approve purchase requests (finance side)',
    'View inventory/transport where permitted',
    'Message parents / support',
  ],
  solves: [
    'Opaque balances → clear collected/outstanding/overdue',
    'Payment recording with accountability',
    'Purchase requests need finance eyes',
    'Parents can see fee status in their portal',
  ],
});

roleSlide({
  title: 'Role — Human Resource',
  subtitle: 'Staffing teachers, employees, and transport unit',
  summary: 'Named HR account for hire/deactivate and transport staffing.',
  does: [
    'Manage staff accounts',
    'HR hub & teachers directory',
    'Classroom teachers administration',
    'Manage buses/drivers & assign student transport',
    'View students; support; message parents',
  ],
  solves: [
    'Stops shared admin login for hiring',
    'Clean teacher/staff lifecycle',
    'Transport unit staffing under HR/ops',
  ],
});

roleSlide({
  title: 'Role — Librarian',
  subtitle: 'Learning materials & library access control',
  summary: 'Central curator of library catalog and e-materials access.',
  does: [
    'Library module',
    'e-Books & learning materials management',
    'Material access control for consumers',
    'Supports teachers/parents/students material flow',
  ],
  solves: [
    'Scattered PDFs and lost books',
    'Controlled access to school materials',
    'One accountable materials owner',
  ],
});

roleSlide({
  title: 'Role — Procurement Manager',
  subtitle: 'Catalog key: procurement',
  summary: 'Structures buying — requests, suppliers, purchased items — not informal store orders.',
  does: [
    'Create purchase requests',
    'Manage suppliers',
    'Enter purchased items',
    'Approve issue requests',
    'View inventory',
  ],
  solves: [
    'Verbal purchase chaos → request workflow',
    'Supplier memory → recorded suppliers',
    'Separation from pure store-keeping duties',
  ],
});

roleSlide({
  title: 'Role — Store Keeper',
  subtitle: 'Catalog key: storekeeper · stock truth',
  summary: 'Runs receive/issue/adjust stock and store request execution.',
  does: [
    'Receive, issue, and adjust stock',
    'Create issue requests',
    'Items, Stock In/Out, Student Issued, Classroom',
    'Assets, Suppliers, Maintenance, Reports',
    'Purchase Requests & Issue Requests sections',
  ],
  solves: [
    'Paper store book losses',
    'Unknown classroom/student issued items',
    'Clear stock movements with roles',
  ],
});

roleSlide({
  title: 'Role — Transport Head',
  subtitle: 'Catalog key: transport_admin',
  summary: 'Owns fleet, drivers, and student–bus linking for parent tracking.',
  does: [
    'Manage buses and drivers',
    'Assign student transport / Bus Link IDs',
    'Transport dashboard & buses module',
    'View students/transport; message parents; support',
  ],
  solves: [
    'Fleet not tracked in one place',
    'Parents cannot see bus without Bus Link setup',
    'Driver accounts tied to real buses',
  ],
});

roleSlide({
  title: 'Role — Quality Assurance',
  subtitle: 'Findings, improvement plans, compliance visibility',
  summary: 'Registers QA findings without rewriting academic grades.',
  does: [
    'Manage QA findings & plans',
    'View students/staff/grades/departments',
    'Reports & audit visibility',
    'Attendance read as allocated',
    'Support access',
  ],
  solves: [
    'Inspection findings lost in folders',
    'Improvement plans become trackable',
    'Oversight without grade-edit conflict',
  ],
});

roleSlide({
  title: 'Role — Staff (lightweight) & Custom',
  subtitle: 'Baseline staff account · plus school-defined custom_* roles',
  summary: 'Staff = light directory/support. Custom = owner-defined label + module checkboxes.',
  does: [
    'Staff: view staff + support (+ baseline chrome)',
    'Custom: any module bundle the owner checks',
    'Labels can match school job titles',
    'Permissions generated from selected modules',
    'Works in web ERP + mobile staff tiles',
  ],
  solves: [
    'Need an account without operational risk',
    'School titles that don’t match EDUABA names',
    'Fast adaptation without new software builds',
  ],
});

// Problem themes divider
{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 13.333,
    h: 7.5,
    fill: { color: C.tealDark },
  });
  s.addText('Problems the School OS solves', {
    x: 0.7,
    y: 2.8,
    w: 12,
    h: 0.7,
    fontSize: 32,
    bold: true,
    color: C.white,
    fontFace: 'Calibri',
  });
  s.addText('Cross-cutting themes — pain today vs MayaBela in product', {
    x: 0.7,
    y: 3.6,
    w: 11,
    h: 0.5,
    fontSize: 16,
    color: C.accentSoft,
    fontFace: 'Calibri',
  });
}

themeSlide({
  title: 'Theme — Attendance integrity',
  pain: [
    'Paper registers go missing or get rewritten',
    'Late marks after the day ends',
    'Parents cannot verify presence',
    'Hard to produce attendance reports',
  ],
  fix: [
    'Teachers mark digital attendance by class',
    'QR entry/exit support where used',
    'Parents & students can view attendance',
    'Admin attendance reports on web',
  ],
});

themeSlide({
  title: 'Theme — Grades reach parents the right way',
  pain: [
    'Marks stuck in teacher notebooks',
    'Parents hear results through rumor',
    'Draft marks leak before review',
    'No clear approver accountability',
  ],
  fix: [
    'Enter → pending → approve/reject',
    'Parents/students see published only',
    'Default Section Director gate (configurable)',
    'Notify on publish; auditability in workflow',
  ],
});

themeSlide({
  title: 'Theme — Parent communication',
  pain: [
    'WhatsApp groups replace official channels',
    'No record of what school announced',
    'Phone trees fail for leave/fees/bus',
    'Office overloaded with repeat questions',
  ],
  fix: [
    'Announcements with role-gated create',
    'In-app messaging by role matrix',
    'Calendar / events / gallery',
    'Parent portal + Maya Assistant guidance',
  ],
});

themeSlide({
  title: 'Theme — Bus safety visibility',
  pain: [
    'Unknown boarding status',
    'Parents anxious about location',
    'Paper passenger lists',
    'Incidents only via phone',
  ],
  fix: [
    'Driver QR onboard / discharge',
    'Live GPS share on route',
    'Digital passenger roster',
    'Parent live map + Bus Link ID',
    'In-app issue reporting',
  ],
});

themeSlide({
  title: 'Theme — Fee visibility',
  pain: [
    'Balances unclear until conflict',
    'No shared view for families',
    'Hard to see overdue vs collected',
    'Finance work stuck in ledgers only',
  ],
  fix: [
    'Finance dashboard: collected / outstanding / overdue',
    'Fee status table in ETB',
    'Parent Fees view in portal',
    'Finance Manager role with payment recording',
    'Note: fee tracking — not a full accounting GL',
  ],
});

themeSlide({
  title: 'Theme — Inventory & procurement discipline',
  pain: [
    'Verbal store orders',
    'Unknown stock levels',
    'Classroom/student issues untracked',
    'No split between buyer and storekeeper',
  ],
  fix: [
    'Purchase & issue request workflows',
    'Stock in/out, items, assets, suppliers',
    'Student issued & classroom inventory',
    'Procurement vs Store Keeper roles',
    'Inventory reports',
  ],
});

themeSlide({
  title: 'Theme — Multi-campus & multi-school control',
  pain: [
    'Campuses run as separate Excel worlds',
    'Operators juggle many school tools',
    'Expiry and seats unmanaged',
    'Onboarding state unknown',
  ],
  fix: [
    'Campus Management inside the school',
    'Platform Console for many schools',
    'Rate, seats, minimum, subscription expiry',
    'Onboarding checklist & expiry filters',
    'Cloud school create so all devices see it',
  ],
});

themeSlide({
  title: 'Theme — Security, accounts & language',
  pain: [
    'Shared passwords across staff',
    'Weak or never-changed temps',
    'No audit of who changed what',
    'English-only barriers',
  ],
  fix: [
    'Named accounts + EDUABA least privilege',
    'Unique temps + forced first change (min 10)',
    'No OTP required for password change',
    'Audit logs; school isolation (RLS)',
    'UI languages: English / Amharic / Afaan Oromo',
  ],
});

// Commercial
{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, 'Commercial model (ETB)');
  s.addText(
    'Bill active/enrolled students only. Teachers, parents, drivers, and staff are not billed per seat.',
    {
      x: 0.5,
      y: 1.2,
      w: 12.3,
      h: 0.4,
      fontSize: 14,
      color: C.muted,
      fontFace: 'Calibri',
    },
  );
  s.addTable(
    [
      [
        { text: 'Item', options: { fill: { color: C.teal }, color: C.white, bold: true } },
        { text: 'Default', options: { fill: { color: C.teal }, color: C.white, bold: true } },
      ],
      ['Per active student / month', '8 ETB'],
      ['Minimum monthly bill', '500 ETB'],
      ['Formula', 'max(students × rate, minimum); 0 if no students'],
      ['Contracted seats', 'Optional cap; overage flagged in console'],
      ['Pilot / Standard / Campus+', '≤150 / ≤500 / negotiated'],
      ['Annual quote option', '10 months prepaid = 2 months courtesy'],
    ],
    {
      x: 1.2,
      y: 1.8,
      w: 10.9,
      colW: [4.5, 6.4],
      border: [
        { pt: 0.5, color: C.line },
        { pt: 0.5, color: C.line },
        { pt: 0.5, color: C.line },
        { pt: 0.5, color: C.line },
      ],
      fontFace: 'Calibri',
      fontSize: 14,
      color: C.ink,
      valign: 'middle',
    },
  );
}

{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, 'Included vs not included');
  twoColCards(
    s,
    {
      title: 'Included',
      items: [
        'Web ERP + mobile/pilot APK model',
        'School isolation & EDUABA RBAC',
        'Students, attendance, grade publish',
        'Parent links, fees view, transport live map',
        'Inventory & procurement',
        'Reports Excel/CSV/PDF',
        'Announcements, messaging, Maya Assistant',
        'Platform Console billing & onboarding',
        'Unique temps + forced password change',
      ],
    },
    {
      title: 'Not included (unless contracted)',
      items: [
        'Custom / brand-new modules',
        'Biometric or on-site hardware',
        'SMS/voice carrier gateway fees',
        'Play Store / App Store account fees',
        'Large SIS migrations beyond pilot',
        '24/7 phone SLA',
      ],
    },
    1.25,
  );
}

{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  sectionBar(s, 'Go-live week — from empty school to parents online');
  s.addTable(
    [
      [
        { text: 'Day', options: { fill: { color: C.teal }, color: C.white, bold: true } },
        { text: 'Focus', options: { fill: { color: C.teal }, color: C.white, bold: true } },
      ],
      ['0', 'Owner: create school in cloud · rate/seats/expiry · admin credentials'],
      ['1', 'Admin: password change · campuses/classes · enroll students & staff'],
      ['2', 'Teachers: attendance + enter grades'],
      ['3', 'Approvers: publish grades · parents can see'],
      ['4', 'Parents: link children · fees · bus (if used)'],
      ['5', 'Reports PDF/Excel · inventory smoke if used'],
    ],
    {
      x: 0.5,
      y: 1.35,
      w: 12.3,
      colW: [1.5, 10.8],
      border: [
        { pt: 0.5, color: C.line },
        { pt: 0.5, color: C.line },
        { pt: 0.5, color: C.line },
        { pt: 0.5, color: C.line },
      ],
      fontFace: 'Calibri',
      fontSize: 14,
      color: C.ink,
      valign: 'middle',
    },
  );
  s.addText(
    'Platform checklist: logo → admin credentials → first student → first parent linked → school active',
    {
      x: 0.5,
      y: 6.4,
      w: 12.3,
      h: 0.4,
      fontSize: 13,
      color: C.muted,
      fontFace: 'Calibri',
    },
  );
}

// Close
{
  const s = pptx.addSlide();
  slidesMeta.push(s);
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 13.333,
    h: 7.5,
    fill: { color: C.tealDark },
  });
  s.addText('Next step — see it live', {
    x: 0.7,
    y: 1.8,
    w: 12,
    h: 0.6,
    fontSize: 32,
    bold: true,
    color: C.white,
    fontFace: 'Calibri',
  });
  s.addText(
    'MayaBela is the school OS that connects owner, admin, every staff role,\n'
      + 'teachers, parents, students, and drivers — with publish controls,\n'
      + 'least privilege, and simple per-student ETB billing.',
    {
      x: 0.7,
      y: 2.6,
      w: 11.5,
      h: 1.3,
      fontSize: 16,
      color: C.accentSoft,
      fontFace: 'Calibri',
    },
  );
  const rows = [
    ['Web demo', 'https://mayabela.pages.dev  (hard-refresh: Ctrl+Shift+R)'],
    ['Phone / WhatsApp', '+251 911 646 444'],
    ['Email', 'nabilmaya6464@gmail.com'],
    ['Hours', 'Mon–Sat, 09:00–18:00 East Africa Time'],
    ['Also available', 'PDF guide: docs/MayaBela_Product_Guide_Sales.pdf'],
  ];
  rows.forEach((r, i) => {
    s.addText(r[0], {
      x: 0.7,
      y: 4.2 + i * 0.45,
      w: 3.0,
      h: 0.4,
      fontSize: 14,
      bold: true,
      color: C.accentSoft,
      fontFace: 'Calibri',
    });
    s.addText(r[1], {
      x: 3.8,
      y: 4.2 + i * 0.45,
      w: 8.5,
      h: 0.4,
      fontSize: 14,
      color: C.white,
      fontFace: 'Calibri',
    });
  });
}

// Number footers
TOTAL = slidesMeta.length;
slidesMeta.forEach((slide, idx) => {
  // cover + dividers still get page numbers except pure full-bleed — add to all non-first optionally
  if (idx === 0) return;
  addFooter(slide, `${idx + 1}/${TOTAL}`);
});

mkdirSync(dirname(outPath), { recursive: true });
await pptx.writeFile({ fileName: outPath });

// Also refresh the shorter filename copy for convenience
const also = join(__dirname, '..', 'docs', 'MayaBela_Product_Guide_Sales.pptx');
await pptx.writeFile({ fileName: also });
console.log('Wrote', outPath);
console.log('Also wrote', also);
console.log('Slides:', TOTAL);
