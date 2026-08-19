/**
 * Short executive deck for school owners / top management meetings.
 * Run: cd tools && node generate_executive_meeting_pptx.mjs
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
  'MayaBela_Executive_School_Owners_Meeting.pptx',
);
const talkPath = join(
  __dirname,
  '..',
  'docs',
  'MayaBela_Executive_Meeting_Talk_Track.md',
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
  gold: 'B45309',
  cream: 'FFFBEB',
  green: '15803D',
};

const pptx = new pptxgen();
pptx.author = 'MayaBela';
pptx.title = 'MayaBela — Executive Briefing for School Owners';
pptx.subject =
  'Short convincing pitch: Digital Ethiopia, problems solved, vs other school systems';
pptx.layout = 'LAYOUT_WIDE';

let page = 0;

function footer(slide) {
  page += 1;
  slide.addText('MayaBela · Confidential · School leadership briefing', {
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

function bar(slide, title, subtitle) {
  slide.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 13.333,
    h: subtitle ? 1.05 : 0.85,
    fill: { color: C.teal },
  });
  slide.addText(title, {
    x: 0.45,
    y: 0.18,
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
      y: 0.58,
      w: 12.4,
      h: 0.32,
      fontSize: 12,
      color: C.accentSoft,
      fontFace: 'Calibri',
    });
  }
}

function notes(slide, text) {
  slide.addNotes(text);
}

// ─── 1 Title ───────────────────────────────────────────────
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 13.333,
    h: 7.5,
    fill: { color: C.tealDark },
  });
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 5.8,
    w: 13.333,
    h: 1.7,
    fill: { color: C.teal },
  });
  s.addText('MAYA BELA', {
    x: 0.7,
    y: 1.6,
    w: 12,
    h: 0.5,
    fontSize: 18,
    color: C.accentSoft,
    fontFace: 'Calibri',
    bold: true,
    charSpacing: 6,
  });
  s.addText('The school operating system\nfor Ethiopia’s digital decade', {
    x: 0.7,
    y: 2.2,
    w: 11.5,
    h: 1.6,
    fontSize: 36,
    bold: true,
    color: C.white,
    fontFace: 'Calibri',
  });
  s.addText(
    'Executive briefing for school owners & top management  ·  12 minutes',
    {
      x: 0.7,
      y: 4.2,
      w: 11.5,
      h: 0.4,
      fontSize: 16,
      color: C.accentSoft,
      fontFace: 'Calibri',
    },
  );
  s.addText(
    'Live: mayabela.pages.dev   ·   Support: +251 911 646 444',
    {
      x: 0.7,
      y: 6.25,
      w: 11.5,
      h: 0.4,
      fontSize: 14,
      color: C.white,
      fontFace: 'Calibri',
    },
  );
  notes(
    s,
    'Open warm: thank them for time. Promise: 12 minutes — problem, national context, why MayaBela is different, clear next step.',
  );
}

// ─── 2 Agenda ──────────────────────────────────────────────
{
  const s = pptx.addSlide();
  bar(s, 'Today’s agenda', 'One story — not a feature dump');
  const items = [
    ['01', 'Why this moment matters — Digital Ethiopia'],
    ['02', 'The real problems school leaders still face'],
    ['03', 'How most school apps compare (honest research)'],
    ['04', 'What MayaBela offers that changes ownership'],
    ['05', 'Quality, control & a simple decision path'],
  ];
  items.forEach((row, i) => {
    const y = 1.4 + i * 0.95;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x: 0.5,
      y,
      w: 12.3,
      h: 0.8,
      fill: { color: i % 2 === 0 ? C.soft : C.white },
      rectRadius: 0.1,
    });
    s.addText(row[0], {
      x: 0.7,
      y: y + 0.18,
      w: 1.0,
      h: 0.45,
      fontSize: 20,
      bold: true,
      color: C.teal,
      fontFace: 'Calibri',
    });
    s.addText(row[1], {
      x: 1.9,
      y: y + 0.2,
      w: 10.5,
      h: 0.45,
      fontSize: 18,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
  footer(s);
}

// ─── 3 Digital Ethiopia ────────────────────────────────────
{
  const s = pptx.addSlide();
  bar(
    s,
    'Ethiopia is choosing digital — education is on the map',
    'National direction your school can align with now',
  );
  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.45,
    y: 1.3,
    w: 12.4,
    h: 1.55,
    fill: { color: C.cream },
    rectRadius: 0.1,
  });
  s.addText(
    'Digital Ethiopia 2025 laid the foundation. Digital Ethiopia 2030 (launched Oct 2025) deepens automation, trust, and citizen services. The Ministry of Education has said the strategy will boost education quality and access — and MoE’s Digital Education Strategy prioritizes platforms, digital skills, and public–private innovation.',
    {
      x: 0.7,
      y: 1.5,
      w: 11.9,
      h: 1.25,
      fontSize: 14,
      color: C.ink,
      fontFace: 'Calibri',
    },
  );
  const cards = [
    {
      t: 'For the nation',
      b: 'Digitize services, raise trust, expand access beyond paper bureaucracy.',
    },
    {
      t: 'For private schools',
      b: 'Leaders who digitize early look modern to parents — and ready for audits & growth.',
    },
    {
      t: 'For your brand',
      b: 'A professional digital school is no longer optional; it is competitive advantage.',
    },
  ];
  cards.forEach((c, i) => {
    const x = 0.45 + i * 4.2;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y: 3.15,
      w: 4.0,
      h: 3.2,
      fill: { color: C.soft },
      rectRadius: 0.12,
    });
    s.addShape(pptx.shapes.RECTANGLE, {
      x,
      y: 3.15,
      w: 4.0,
      h: 0.12,
      fill: { color: C.teal },
    });
    s.addText(c.t, {
      x: x + 0.25,
      y: 3.5,
      w: 3.5,
      h: 0.5,
      fontSize: 16,
      bold: true,
      color: C.tealDark,
      fontFace: 'Calibri',
    });
    s.addText(c.b, {
      x: x + 0.25,
      y: 4.15,
      w: 3.5,
      h: 1.8,
      fontSize: 14,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
  footer(s);
  notes(
    s,
    'Sources to mention if asked: ENA (Jan 2026) MoE on Digital Ethiopia 2030; MoE Digital Education Strategy 2023–2028 (platforms, skills, PPP). Do not overclaim government endorsement of MayaBela — say we help schools align with the national digital direction.',
  );
}

// ─── 4 Problem ─────────────────────────────────────────────
{
  const s = pptx.addSlide();
  bar(
    s,
    'The problem is not “no software”',
    'It is fragmented control of a living school',
  );
  const probs = [
    [
      'Many truths',
      'Excel files, paper registers, and WhatsApp groups — nobody shares one official record.',
    ],
    [
      'Owner blindness',
      'You hear problems late: fee leakage, unpaid balances, weak attendance, grade disputes.',
    ],
    [
      'Weak governance',
      'Teachers publish marks with no approval chain. Roles blur. Accountability suffers.',
    ],
    [
      'Parent trust gap',
      'Families want real-time clarity — results, presence, bus safety — not rumor chains.',
    ],
    [
      'Ops beyond academics',
      'Transport, inventory, procurement, multi-campus — usually left outside “school apps”.',
    ],
    [
      'Digital image lag',
      'Competitors look modern. Your school still runs like 2015 — parents notice.',
    ],
  ];
  probs.forEach((p, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = 0.4 + col * 4.25;
    const y = 1.3 + row * 2.7;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y,
      w: 4.05,
      h: 2.45,
      fill: { color: C.white },
      line: { color: C.line, width: 1 },
      rectRadius: 0.1,
    });
    s.addText(p[0], {
      x: x + 0.25,
      y: y + 0.35,
      w: 3.55,
      h: 0.45,
      fontSize: 16,
      bold: true,
      color: C.teal,
      fontFace: 'Calibri',
    });
    s.addText(p[1], {
      x: x + 0.25,
      y: y + 0.95,
      w: 3.55,
      h: 1.2,
      fontSize: 13,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
  footer(s);
}

// ─── 5 Research method ─────────────────────────────────────
{
  const s = pptx.addSlide();
  bar(
    s,
    'What we compared (market research)',
    'Local Ethiopian school platforms + common global SIS patterns',
  );
  s.addText(
    'We reviewed publicly marketed platforms serving Ethiopian schools (including eSchool.et, MyEdu.et, Fidel.et, Dream Tech SMS) and typical international SIS patterns. Most sell the same core: students · fees · attendance · exams · parent app.',
    {
      x: 0.5,
      y: 1.25,
      w: 12.3,
      h: 0.9,
      fontSize: 14,
      color: C.ink,
      fontFace: 'Calibri',
    },
  );
  const cols = [
    {
      t: 'Manual stack',
      b: 'Paper + Excel + WhatsApp\nCheap to start.\nBreaks at scale.\nNo audit trail.',
    },
    {
      t: 'Typical school SMS',
      b: 'Cloud records + fees + portals.\nGood admin digitization.\nOften thin on leadership governance, live transport trust, and stock/procurement.',
    },
    {
      t: 'MayaBela position',
      b: 'Full school operating system:\nacademics + staff authority matrix + parent trust + transport + inventory — built for Ethiopian private-school reality.',
    },
  ];
  cols.forEach((c, i) => {
    const x = 0.4 + i * 4.25;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y: 2.35,
      w: 4.05,
      h: 4.2,
      fill: { color: i === 2 ? C.accentSoft : C.soft },
      rectRadius: 0.12,
    });
    s.addText(c.t, {
      x: x + 0.25,
      y: 2.6,
      w: 3.55,
      h: 0.55,
      fontSize: 16,
      bold: true,
      color: C.tealDark,
      fontFace: 'Calibri',
    });
    s.addText(c.b, {
      x: x + 0.25,
      y: 3.35,
      w: 3.55,
      h: 2.9,
      fontSize: 14,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
  footer(s);
  notes(
    s,
    'Be respectful of competitors. Never say they are “bad”. Say: they digitize records well; MayaBela is for owners who need control of the whole institution.',
  );
}

// ─── 6 Comparison table ────────────────────────────────────
{
  const s = pptx.addSlide();
  bar(
    s,
    'Difference that matters to owners',
    'Same “modules” on brochures — different depth in daily control',
  );

  const headers = ['Capability', 'Typical SMS', 'MayaBela'];
  const rows = [
    ['Student / fee / attendance / exams', 'Strong', 'Strong'],
    ['Parent & teacher mobile access', 'Common', 'Included'],
    ['Deep staff roles (VP, SD, HR…)', 'Basic roles', 'EDUABA permission matrix'],
    ['Grade quality gate (approve first)', 'Rare / weak', 'Approve → then parents see'],
    ['Live school bus / driver portal', 'Basic or none', 'Transport + live location'],
    ['Inventory & procurement', 'Usually separate', 'Built into the ERP'],
    ['EN + Amharic + Afaan Oromo', 'Varies', 'Built-in'],
    ['Transparent school quote', 'Custom quotes', '200–400 ETB / student + VAT'],
    ['School data isolation (cloud)', 'Shared SaaS', 'Per-school security boundary'],
  ];

  // header
  headers.forEach((h, i) => {
    const x = 0.4 + i * 4.2;
    s.addShape(pptx.shapes.RECTANGLE, {
      x,
      y: 1.2,
      w: 4.1,
      h: 0.48,
      fill: { color: C.teal },
    });
    s.addText(h, {
      x,
      y: 1.28,
      w: 4.1,
      h: 0.35,
      fontSize: 13,
      bold: true,
      color: C.white,
      fontFace: 'Calibri',
      align: 'center',
    });
  });

  rows.forEach((r, ri) => {
    const y = 1.68 + ri * 0.55;
    r.forEach((cell, ci) => {
      const x = 0.4 + ci * 4.2;
      const bg =
        ci === 2 ? C.accentSoft : ri % 2 === 0 ? C.soft : C.white;
      s.addShape(pptx.shapes.RECTANGLE, {
        x,
        y,
        w: 4.1,
        h: 0.55,
        fill: { color: bg },
      });
      s.addText(cell, {
        x: x + 0.1,
        y: y + 0.12,
        w: 3.9,
        h: 0.35,
        fontSize: 12,
        bold: ci === 0 || ci === 2,
        color: C.ink,
        fontFace: 'Calibri',
        align: ci === 0 ? 'left' : 'center',
      });
    });
  });
  footer(s);
}

// ─── 7 What we offer ───────────────────────────────────────
{
  const s = pptx.addSlide();
  bar(
    s,
    'What MayaBela offers — in one sentence',
    'One platform. Every role. Owner-level visibility.',
  );
  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.5,
    y: 1.3,
    w: 12.3,
    h: 1.3,
    fill: { color: C.cream },
    rectRadius: 0.1,
  });
  s.addText(
    'MayaBela (EduAba) is a cloud school ERP that connects owners, leadership, teachers, parents, students, and drivers — so academics, people, money signals, transport, and stores run as one system.',
    {
      x: 0.75,
      y: 1.55,
      w: 11.8,
      h: 0.9,
      fontSize: 16,
      color: C.ink,
      fontFace: 'Calibri',
    },
  );
  const offers = [
    ['Academic engine', 'Classes, sections, attendance, subjects, grade entry & publishing'],
    ['Leadership control', 'Role permissions for Owner / VP / Section Director / HR'],
    ['Family trust', 'Secure parent link, announcements, results after approval'],
    ['Campus logistics', 'Bus assignment + live location for peace of mind'],
    ['School stores', 'Inventory & procurement — not a second vendor'],
    ['Local readiness', 'Web ERP now · EN/አማርኛ/Afaan Oromo · local support'],
  ];
  offers.forEach((o, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const x = 0.5 + col * 4.2;
    const y = 2.9 + row * 1.85;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y,
      w: 4.0,
      h: 1.65,
      fill: { color: C.soft },
      rectRadius: 0.1,
    });
    s.addText(o[0], {
      x: x + 0.2,
      y: y + 0.25,
      w: 3.6,
      h: 0.4,
      fontSize: 15,
      bold: true,
      color: C.tealDark,
      fontFace: 'Calibri',
    });
    s.addText(o[1], {
      x: x + 0.2,
      y: y + 0.75,
      w: 3.6,
      h: 0.7,
      fontSize: 13,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
  footer(s);
}

// ─── 8 Quality ─────────────────────────────────────────────
{
  const s = pptx.addSlide();
  bar(
    s,
    'Quality is not a slogan — it is workflow',
    'How MayaBela protects your school’s reputation',
  );
  const q = [
    {
      n: '1',
      t: 'Authority before publication',
      b: 'Teachers enter grades. Leadership approves. Only then parents see results. Fewer disputes. Stronger academic brand.',
    },
    {
      n: '2',
      t: 'Right person, right screen',
      b: 'EDUABA-style permissions: finance, inventory, transfers, academics — separated by role, not by shared passwords.',
    },
    {
      n: '3',
      t: 'School boundary in the cloud',
      b: 'Each school’s data is isolated. Your records are not mixed with another institution’s chaos.',
    },
    {
      n: '4',
      t: 'Evidence, not opinion',
      b: 'Export reports (Excel / CSV / PDF). Decisions for board meetings start from one system of record.',
    },
  ];
  q.forEach((item, i) => {
    const y = 1.25 + i * 1.35;
    s.addShape(pptx.shapes.OVAL, {
      x: 0.55,
      y: y + 0.15,
      w: 0.7,
      h: 0.7,
      fill: { color: C.teal },
    });
    s.addText(item.n, {
      x: 0.55,
      y: y + 0.28,
      w: 0.7,
      h: 0.45,
      fontSize: 18,
      bold: true,
      color: C.white,
      fontFace: 'Calibri',
      align: 'center',
    });
    s.addText(item.t, {
      x: 1.5,
      y: y,
      w: 11,
      h: 0.4,
      fontSize: 16,
      bold: true,
      color: C.ink,
      fontFace: 'Calibri',
    });
    s.addText(item.b, {
      x: 1.5,
      y: y + 0.45,
      w: 11,
      h: 0.7,
      fontSize: 14,
      color: C.muted,
      fontFace: 'Calibri',
    });
  });
  footer(s);
}

// ─── 9 Why different ───────────────────────────────────────
{
  const s = pptx.addSlide();
  bar(
    s,
    'Why schools choose MayaBela over “another school app”',
    'Five differentiators to remember',
  );
  const diffs = [
    ['Governance-first ERP', 'Built for owners & deputies — not only registrars.'],
    ['Trust loop with parents', 'Approved grades + clear communication channels.'],
    ['Transport as a product', 'Drivers and live bus — rare in local SMS suites.'],
    ['Ops under one roof', 'Inventory & procurement with academics — fewer vendors.'],
    ['Ethiopia-ready UX', 'Languages + local support + transparent pilot pricing.'],
  ];
  diffs.forEach((d, i) => {
    const y = 1.3 + i * 1.05;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x: 0.5,
      y,
      w: 12.3,
      h: 0.9,
      fill: { color: i % 2 ? C.soft : C.white },
      line: { color: C.line, width: 1 },
      rectRadius: 0.08,
    });
    s.addText(`${i + 1}.  ${d[0]}`, {
      x: 0.8,
      y: y + 0.12,
      w: 11.7,
      h: 0.35,
      fontSize: 16,
      bold: true,
      color: C.tealDark,
      fontFace: 'Calibri',
    });
    s.addText(d[1], {
      x: 0.8,
      y: y + 0.48,
      w: 11.7,
      h: 0.3,
      fontSize: 13,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
  footer(s);
}

// ─── 10 Commercial overview ────────────────────────────────
{
  const s = pptx.addSlide();
  bar(
    s,
    'Simple commercial logic',
    'Clear per-student quote — VAT shown separately',
  );
  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.5,
    y: 1.35,
    w: 6.0,
    h: 5.1,
    fill: { color: C.soft },
    rectRadius: 0.12,
  });
  s.addText('School package rate', {
    x: 0.85,
    y: 1.65,
    w: 5.3,
    h: 0.4,
    fontSize: 18,
    bold: true,
    color: C.tealDark,
    fontFace: 'Calibri',
  });
  s.addText(
    [
      {
        text: '200 – 400 ETB',
        options: { bold: true, fontSize: 30, color: C.teal },
      },
      {
        text: '\nper student  +  15% VAT',
        options: { fontSize: 16, color: C.ink },
      },
      {
        text: '\n\nQuoted per active student for the school package.',
        options: { fontSize: 14, color: C.muted },
      },
      {
        text: '\n\nTeachers, parents, drivers & staff are not billed per seat.',
        options: { fontSize: 14, color: C.ink },
      },
      {
        text: '\n\nFinal tier depends on size, campuses & modules.',
        options: { fontSize: 14, color: C.ink },
      },
    ],
    {
      x: 0.85,
      y: 2.25,
      w: 5.3,
      h: 3.9,
      fontFace: 'Calibri',
    },
  );

  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 6.85,
    y: 1.35,
    w: 5.95,
    h: 5.1,
    fill: { color: C.accentSoft },
    rectRadius: 0.12,
  });
  s.addText('What you get', {
    x: 7.2,
    y: 1.65,
    w: 5.3,
    h: 0.4,
    fontSize: 18,
    bold: true,
    color: C.tealDark,
    fontFace: 'Calibri',
  });
  const gets = [
    'Web ERP for owners & staff (mayabela.pages.dev)',
    'Role portals for teachers, parents, students, drivers',
    'Onboarding + training support',
    'Pilot path before long commitment',
    'Local WhatsApp/phone support',
  ];
  gets.forEach((g, i) => {
    s.addText(`▸  ${g}`, {
      x: 7.2,
      y: 2.3 + i * 0.7,
      w: 5.3,
      h: 0.6,
      fontSize: 14,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
  footer(s);
}

// ─── 11 Price quote slide ──────────────────────────────────
{
  const s = pptx.addSlide();
  bar(
    s,
    'Investment quote — per student',
    '200 – 400 ETB + 15% VAT  ·  teachers & parents not charged',
  );

  const tiers = [
    {
      name: 'Essential',
      rate: '200',
      vat: '30',
      total: '230',
      for: 'Core academics · attendance · grades · parent access',
    },
    {
      name: 'Standard',
      rate: '300',
      vat: '45',
      total: '345',
      for: 'Full ERP · approvals · messaging · reports',
    },
    {
      name: 'Campus+',
      rate: '400',
      vat: '60',
      total: '460',
      for: 'Multi-campus · transport · inventory · priority support',
    },
  ];
  tiers.forEach((t, i) => {
    const x = 0.4 + i * 4.25;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y: 1.25,
      w: 4.05,
      h: 3.55,
      fill: { color: i === 1 ? C.accentSoft : C.soft },
      rectRadius: 0.12,
    });
    if (i === 1) {
      s.addText('RECOMMENDED', {
        x,
        y: 1.35,
        w: 4.05,
        h: 0.28,
        fontSize: 11,
        bold: true,
        color: C.teal,
        fontFace: 'Calibri',
        align: 'center',
      });
    }
    s.addText(t.name, {
      x: x + 0.2,
      y: 1.7,
      w: 3.65,
      h: 0.4,
      fontSize: 18,
      bold: true,
      color: C.tealDark,
      fontFace: 'Calibri',
      align: 'center',
    });
    s.addText(`${t.rate} ETB`, {
      x: x + 0.2,
      y: 2.2,
      w: 3.65,
      h: 0.45,
      fontSize: 28,
      bold: true,
      color: C.teal,
      fontFace: 'Calibri',
      align: 'center',
    });
    s.addText(`+ VAT 15% = ${t.vat} ETB`, {
      x: x + 0.2,
      y: 2.7,
      w: 3.65,
      h: 0.35,
      fontSize: 13,
      color: C.muted,
      fontFace: 'Calibri',
      align: 'center',
    });
    s.addText(`${t.total} ETB / student`, {
      x: x + 0.2,
      y: 3.15,
      w: 3.65,
      h: 0.4,
      fontSize: 16,
      bold: true,
      color: C.ink,
      fontFace: 'Calibri',
      align: 'center',
    });
    s.addText(t.for, {
      x: x + 0.3,
      y: 3.7,
      w: 3.45,
      h: 0.85,
      fontSize: 12,
      color: C.ink,
      fontFace: 'Calibri',
      align: 'center',
    });
  });

  // Example quote strip
  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.4,
    y: 5.0,
    w: 12.5,
    h: 1.85,
    fill: { color: C.cream },
    rectRadius: 0.1,
  });
  s.addText('Example school quote (Standard @ 300 ETB + VAT)', {
    x: 0.7,
    y: 5.15,
    w: 12,
    h: 0.35,
    fontSize: 14,
    bold: true,
    color: C.gold,
    fontFace: 'Calibri',
  });
  s.addText(
    '300 students × 300 ETB = 90,000 ETB   ·   VAT 15% = 13,500 ETB   ·   Total = 103,500 ETB\n' +
      '500 students × 300 ETB = 150,000 ETB  ·   VAT 15% = 22,500 ETB   ·   Total = 172,500 ETB\n' +
      'Final invoice uses active enrolled students × agreed tier. Seat count can be contracted.',
    {
      x: 0.7,
      y: 5.55,
      w: 12,
      h: 1.1,
      fontSize: 13,
      color: C.ink,
      fontFace: 'Calibri',
    },
  );
  footer(s);
  notes(
    s,
    'Quote range 200–400 + 15% VAT per student. Recommend Standard (300) unless multi-campus/transport/inventory → Campus+ (400).',
  );
}

// ─── 12 Ask / pilot ────────────────────────────────────────
{
  const s = pptx.addSlide();
  bar(
    s,
    'A clean decision for leadership',
    'Low risk. High visibility. Fast proof.',
  );
  const steps = [
    ['Week 0', 'Create your school cloud · set grades/campuses · admin login'],
    ['Week 1', 'Enroll one grade or campus · teachers live · attendance starts'],
    ['Week 2', 'Parent links · grade approval demo · transport (if used)'],
    ['Decision', 'Board sees real usage — then expand school-wide'],
  ];
  steps.forEach((st, i) => {
    const y = 1.35 + i * 1.2;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x: 0.5,
      y,
      w: 12.3,
      h: 1.05,
      fill: { color: C.soft },
      rectRadius: 0.1,
    });
    s.addShape(pptx.shapes.RECTANGLE, {
      x: 0.5,
      y,
      w: 0.18,
      h: 1.05,
      fill: { color: C.teal },
    });
    s.addText(st[0], {
      x: 1.0,
      y: y + 0.28,
      w: 2.2,
      h: 0.5,
      fontSize: 16,
      bold: true,
      color: C.teal,
      fontFace: 'Calibri',
    });
    s.addText(st[1], {
      x: 3.4,
      y: y + 0.28,
      w: 9.0,
      h: 0.5,
      fontSize: 16,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
  footer(s);
  notes(
    s,
    'Close the ask: “Give us one campus or one grade for 30–60 days. If leadership does not feel control improve, we stop. If it does — we scale.”',
  );
}


// ─── 13 Amharic one-page summary ────────────────────────────
{
  const s = pptx.addSlide();
  const am = 'Nyala';
  // Titles via Unicode escapes so file encoding never breaks Ethiopic
  const amTitle =
    '\u12A0\u132D\u122D \u121B\u1320\u1243\u1208\u12EB (\u12A0\u121B\u122D\u129B)';
  const amSub =
    '\u1208\u1275\u121D\u1205\u122D\u1275 \u1264\u1275 \u1263\u1208\u1264\u1276\u127D\u1293 \u12A8\u134D\u1270\u129B \u12A0\u1218\u122B\u122D';
  bar(s, amTitle, amSub);

  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.4,
    y: 1.2,
    w: 12.5,
    h: 1.15,
    fill: { color: C.cream },
    rectRadius: 0.1,
  });
  s.addText(
    '\u12A2\u1275\u12EE\u1335\u12EB \u1260 Digital Ethiopia 2030 \u12F2\u1302\u1273\u120D \u12A0\u1308\u120D\u130D\u120E\u1275\u1295 \u12A5\u12EB\u1320\u1293\u12A8\u1228\u127D \u1290\u12CD\u1362 \u12E8\u1275\u121D\u1205\u122D\u1275 \u121A\u1292\u1235\u1274\u122D\u121D \u12F2\u1302\u1273\u120D \u1275\u121D\u1205\u122D\u1275\u1295 \u1208\u1325\u122B\u1275\u1293 \u1270\u12F0\u122B\u123D\u1290\u1275 \u12A0\u1235\u1348\u120B\u130A \u12A0\u12F5\u122D\u130E \u12EB\u1235\u1240\u121D\u1323\u120D\u1362 \u121B\u12EB\u1264\u120B \u1275\u121D\u1205\u122D\u1275 \u1264\u1276\u127D \u12ED\u1205\u1295 \u12A0\u1245\u1323\u132B \u1260\u1270\u130D\u1263\u122D \u12A5\u1295\u12F2\u12A8\u1270\u1209 \u12E8\u121A\u1228\u12F3 \u12E8\u1275\u121D\u1205\u122D\u1275 \u1264\u1275 \u1235\u122D\u12D3\u1275 \u1290\u12CD\u1362',
    {
      x: 0.65,
      y: 1.35,
      w: 12.0,
      h: 0.9,
      fontSize: 14,
      color: C.ink,
      fontFace: am,
    },
  );

  const amCards = [
    {
      t: '\u127D\u130D\u1229',
      b: '\u12A4\u12AD\u1234\u120D\u1363 \u12C8\u1228\u1240\u1275\u1293 \u12CB\u1275\u1235\u12A0\u1355 \u2014 \u12A0\u1295\u12F5 \u12A5\u12CD\u1290\u1270\u129B \u1218\u1228\u1303 \u12E8\u1208\u121D\u1362 \u1263\u1208\u1264\u1271 \u127D\u130D\u122D\u1295 \u12D8\u130D\u12ED\u1276 \u12ED\u1230\u121B\u120D\u1362 \u12E8\u12CD\u1324\u1275 \u1325\u122B\u1275 \u1241\u1325\u1325\u122D \u12F0\u12AB\u121B \u1290\u12CD\u1362',
    },
    {
      t: '\u12A8\u120C\u120E\u127D \u1235\u122D\u12D3\u1276\u127D \u120D\u12E9\u1290\u1275',
      b: '\u1265\u12D9 \u12A0\u1355\u120A\u12AC\u123D\u1296\u127D \u1270\u121B\u122A/\u12AD\u134D\u12EB/\u1348\u1270\u1293 \u12EB\u1235\u1270\u12F3\u12F5\u122B\u1209\u1362 \u121B\u12EB\u1264\u120B \u130D\u1295 \u12A0\u1218\u122B\u122D \u1241\u1325\u1325\u122D\u1363 \u12E8\u12CD\u1324\u1275 \u121B\u133D\u12F0\u1245\u1363 \u1263\u1235 \u1275\u122B\u1295\u1235\u1356\u122D\u1275\u1363 \u12A2\u1295\u126C\u1295\u1276\u122A \u2014 \u12A0\u1295\u12F5 \u120B\u12ED \u12EB\u1240\u122D\u1263\u120D\u1362',
    },
    {
      t: '\u1325\u122B\u1275',
      b: '\u1218\u121D\u1205\u122D \u12CD\u1324\u1275 \u12EB\u1235\u1308\u1263\u120D \u2192 \u12A0\u1218\u122B\u122D \u12EB\u1338\u12F5\u1243\u120D \u2192 \u12A8\u12DA\u12EB \u12C8\u120B\u1305 \u12EB\u12EB\u120D\u1362 \u12A5\u12EB\u1295\u12F3\u1295\u12F1 \u121A\u1293 \u12E8\u122B\u1231 \u1348\u1243\u12F5 \u12A0\u1208\u12CD\u1362 \u12E8\u1275\u121D\u1205\u122D\u1275 \u1264\u1271 \u1218\u1228\u1303 \u1270\u1208\u12ED\u1276 \u12ED\u1320\u1260\u1243\u120D\u1362',
    },
    {
      t: '\u12CB\u130B (\u12AE\u1275)',
      b: '\u1208\u12A0\u1295\u12F5 \u1270\u121B\u122A \u12A8 200 \u12A5\u1235\u12A8 400 \u1265\u122D + 15% \u1270.\u12A5.\u1273\u1362 \u1218\u121D\u1205\u122B\u1295/\u12C8\u120B\u1306\u127D/\u1239\u134C\u122E\u127D \u1260\u1270\u121B\u122A \u12A0\u12ED\u12A8\u1348\u1209\u121D\u1362 \u121D\u1233\u120C\u1361 300 \u1270\u121B\u122A \u00D7 300 = 90,000 + \u1270.\u12A5.\u1273 13,500 = 103,500 \u1265\u122D\u1362',
    },
  ];
  amCards.forEach((c, i) => {
    const col = i % 2;
    const row = Math.floor(i / 2);
    const x = 0.4 + col * 6.4;
    const y = 2.55 + row * 2.15;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y,
      w: 6.15,
      h: 2.0,
      fill: { color: C.soft },
      rectRadius: 0.1,
    });
    s.addText(c.t, {
      x: x + 0.25,
      y: y + 0.2,
      w: 5.65,
      h: 0.4,
      fontSize: 16,
      bold: true,
      color: C.tealDark,
      fontFace: am,
    });
    s.addText(c.b, {
      x: x + 0.25,
      y: y + 0.7,
      w: 5.65,
      h: 1.15,
      fontSize: 13,
      color: C.ink,
      fontFace: am,
    });
  });
  footer(s);
  notes(
    s,
    'Amharic leave-behind. Emphasize 200-400 + 15% VAT and approve-before-publish grades.',
  );
}

// ─── 14 Close ──────────────────────────────────────────────
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 13.333,
    h: 7.5,
    fill: { color: C.tealDark },
  });
  s.addText('The schools that win the next decade\nwill run on data, trust, and speed.', {
    x: 0.7,
    y: 1.3,
    w: 12,
    h: 1.4,
    fontSize: 28,
    bold: true,
    color: C.white,
    fontFace: 'Calibri',
  });
  s.addText(
    'Digital Ethiopia is the national direction.\nMayaBela is how your school can execute it — tomorrow morning.',
    {
      x: 0.7,
      y: 2.9,
      w: 12,
      h: 1.1,
      fontSize: 18,
      color: C.accentSoft,
      fontFace: 'Calibri',
    },
  );
  s.addText(
    '\u12A2\u1295\u126C\u1235\u1275\u1218\u1295\u1275\u1361 200\u2013400 \u1265\u122D / \u1270\u121B\u122A + 15% \u1270.\u12A5.\u1273',
    {
      x: 0.7,
      y: 4.2,
      w: 12,
      h: 0.45,
      fontSize: 18,
      bold: true,
      color: C.white,
      fontFace: 'Nyala',
    },
  );
  s.addText(
    'Live demo: https://mayabela.pages.dev\n+251 911 646 444  ·  nabilmaya6464@gmail.com',
    {
      x: 0.7,
      y: 5.0,
      w: 12,
      h: 1.0,
      fontSize: 16,
      color: C.white,
      fontFace: 'Calibri',
    },
  );
  notes(s, 'Stop talking. Offer live walkthrough of owner dashboard + parent view.');
}

mkdirSync(dirname(outPath), { recursive: true });
await pptx.writeFile({ fileName: outPath });
console.log('Wrote', outPath);

import { writeFileSync } from 'fs';

const talk = `# MayaBela — Executive meeting talk track (≈12–14 minutes)

Use with: \`docs/MayaBela_Executive_School_Owners_Meeting.pptx\`
Amharic leave-behind: \`docs/MayaBela_Executive_Amharic_Summary.md\`

## Opening (45 sec)
Thank owners/management. Promise a short decision briefing.

**Line:** “Today is about control, trust, and aligning your school with Digital Ethiopia.”

## Digital Ethiopia (90 sec)
- Digital Ethiopia 2025 → **2030** (Oct 2025).
- MoE: digital strategy supports education quality and access.
- Do **not** claim MayaBela is a government product — say schools can **align**.

## Problems + comparison (3 min)
Local SMS tools digitize records/fees/portals.
MayaBela: governance, approve→publish grades, live transport, inventory, EN/AM/OM.

**Line:** “Most systems help the registrar. MayaBela helps the owner sleep.”

## Price quote (90 sec)
- **200 – 400 ETB per student + 15% VAT**
- Essential **200** · Standard **300** (recommend) · Campus+ **400**
- Staff/parents/drivers not billed per seat
- Example: 300 students × 300 = **90,000 + VAT 13,500 = 103,500 ETB**

## Pilot ask (90 sec)
30–60 days, one grade/campus → board decision.

## Leave-behind
- https://mayabela.pages.dev
- +251 911 646 444 · nabilmaya6464@gmail.com
- Show the **Amharic summary** slide for አማርኛ speakers
`;
writeFileSync(talkPath, talk, 'utf8');
console.log('Wrote', talkPath);

const amSummaryPath = join(
  __dirname,
  '..',
  'docs',
  'MayaBela_Executive_Amharic_Summary.md',
);

// Build Amharic markdown with escapes so the source file stays ASCII-safe
const amSummary = [
  '# ' + '\u121B\u12EB\u1264\u120B \u2014 \u12A0\u132D\u122D \u121B\u1320\u1243\u1208\u12EB \u1208\u1275\u121D\u1205\u122D\u1275 \u1264\u1275 \u1263\u1208\u1264\u1276\u127D',
  '',
  '## ' + '\u12F2\u1302\u1273\u120D \u12A2\u1275\u12EE\u1335\u12EB',
  '\u12A2\u1275\u12EE\u1335\u12EB \u1260 **Digital Ethiopia 2030** \u12F2\u1302\u1273\u120D \u12A0\u1308\u120D\u130D\u120E\u1275\u1295 \u12A5\u12EB\u1320\u1293\u12A8\u1228\u127D \u1290\u12CD\u1362 \u12E8\u1275\u121D\u1205\u122D\u1275 \u121A\u1292\u1235\u1274\u122D\u121D \u12F2\u1302\u1273\u120D \u1275\u121D\u1205\u122D\u1275\u1295 \u1208\u1325\u122B\u1275\u1293 \u1270\u12F0\u122B\u123D\u1290\u1275 \u12A0\u1235\u1348\u120B\u130A \u12A0\u12F5\u122D\u130E \u12EB\u1235\u1240\u121D\u1323\u120D\u1362 **\u121B\u12EB\u1264\u120B** \u1275\u121D\u1205\u122D\u1275 \u1264\u1276\u127D \u12ED\u1205\u1295 \u12A0\u1245\u1323\u132B \u1260\u1270\u130D\u1263\u122D \u12A5\u1295\u12F2\u12A8\u1270\u1209 \u12E8\u121A\u1228\u12F3 \u12E8\u1275\u121D\u1205\u122D\u1275 \u1264\u1275 \u1235\u122D\u12D3\u1275 \u1290\u12CD\u1362',
  '',
  '## ' + '\u127D\u130D\u1229',
  '\u12A4\u12AD\u1234\u120D\u1363 \u12C8\u1228\u1240\u1275\u1293 \u12CB\u1275\u1235\u12A0\u1355 \u2014 \u12A0\u1295\u12F5 \u12A5\u12CD\u1290\u1270\u129B \u1218\u1228\u1303 \u12E8\u1208\u121D\u1362 \u1263\u1208\u1264\u1271 \u127D\u130D\u122D\u1295 \u12D8\u130D\u12ED\u1276 \u12ED\u1230\u121B\u120D\u1362 \u12E8\u12CD\u1324\u1275 \u1325\u122B\u1275 \u1241\u1325\u1325\u122D \u12F0\u12AB\u121B \u1290\u12CD\u1362',
  '',
  '## ' + '\u12A8\u120C\u120E\u127D \u1235\u122D\u12D3\u1276\u127D \u120D\u12E9\u1290\u1275',
  '\u1265\u12D9 \u12A0\u1355\u120A\u12AC\u123D\u1296\u127D \u1270\u121B\u122A\u1363 \u12AD\u134D\u12EB\u1293 \u1348\u1270\u1293 \u12EB\u1235\u1270\u12F3\u12F5\u122B\u1209\u1362 \u121B\u12EB\u1264\u120B \u130D\u1295 **\u12A0\u1218\u122B\u122D \u1241\u1325\u1325\u122D**\u1363 **\u12E8\u12CD\u1324\u1275 \u121B\u133D\u12F0\u1245**\u1363 **\u1263\u1235 \u1275\u122B\u1295\u1235\u1356\u122D\u1275**\u1363 **\u12A2\u1295\u126C\u1295\u1276\u122A** \u2014 \u12A0\u1295\u12F5 \u120B\u12ED \u12EB\u1240\u122D\u1263\u120D\u1362',
  '',
  '## ' + '\u1325\u122B\u1275',
  '\u1218\u121D\u1205\u122D \u12CD\u1324\u1275 \u12EB\u1235\u1308\u1263\u120D \u2192 \u12A0\u1218\u122B\u122D \u12EB\u1338\u12F5\u1243\u120D \u2192 \u12A8\u12DA\u12EB \u12C8\u120B\u1305 \u12EB\u12EB\u120D\u1362 \u12A5\u12EB\u1295\u12F3\u1295\u12F1 \u121A\u1293 \u12E8\u122B\u1231 \u1348\u1243\u12F5 \u12A0\u1208\u12CD\u1362',
  '',
  '## ' + '\u12E8\u12CB\u130B \u12AE\u1275 (\u1208\u12A0\u1295\u12F5 \u1270\u121B\u122A)',
  '',
  '| ' + '\u12F0\u1228\u1303' + ' | ' + '\u12CB\u130B' + ' | ' + '\u1270.\u12A5.\u1273 15%' + ' | ' + '\u12F5\u121D\u122D / \u1270\u121B\u122A' + ' |',
  '|------|------|-----------|-------------|',
  '| Essential | 200 ' + '\u1265\u122D' + ' | 30 ' + '\u1265\u122D' + ' | **230 ' + '\u1265\u122D' + '** |',
  '| Standard | 300 ' + '\u1265\u122D' + ' | 45 ' + '\u1265\u122D' + ' | **345 ' + '\u1265\u122D' + '** |',
  '| Campus+ | 400 ' + '\u1265\u122D' + ' | 60 ' + '\u1265\u122D' + ' | **460 ' + '\u1265\u122D' + '** |',
  '',
  '- ' + '\u1218\u121D\u1205\u122B\u1295\u1363 \u12C8\u120B\u1306\u127D\u1293 \u1239\u134C\u122E\u127D \u1260\u1270\u121B\u122A \u12A0\u12ED\u12A8\u1348\u1209\u121D\u1362',
  '- ' + '\u121D\u1233\u120C (Standard): 300 \u1270\u121B\u122A \u00D7 300 = **90,000** + \u1270.\u12A5.\u1273 **13,500** = **103,500 \u1265\u122D**\u1362',
  '',
  '## ' + '\u1240\u1323\u12ED \u12A5\u122D\u121D\u1323',
  '\u1208 30\u201360 \u1240\u1293\u1275 \u12A0\u1295\u12F5 \u12AB\u121D\u1353\u1235/\u12F0\u1228\u1303 \u1353\u12ED\u1208\u1275 \u2014 \u12A8\u12DA\u12EB \u12E8\u1266\u122D\u12F5 \u12CD\u1233\u1294\u1362',
  '',
  '**Demo:** https://mayabela.pages.dev  ',
  '**Support:** +251 911 646 444 · nabilmaya6464@gmail.com',
  '',
].join('\n');

writeFileSync(amSummaryPath, amSummary, 'utf8');
console.log('Wrote', amSummaryPath);
