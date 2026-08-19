/**
 * Majo Bridge Smart School Operating System — 2-speaker executive deck
 * Run: cd tools && node generate_majo_two_speaker_pptx.mjs
 */
import { createRequire } from 'module';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(__dirname, 'package.json'));
const pptxgen = require('pptxgenjs');

const BRAND = 'Majo Bridge';
const PRODUCT = 'Smart School Operating System';
const FULL = `${BRAND} ${PRODUCT}`;

const outPath = join(
  __dirname,
  '..',
  'docs',
  'Majo_Bridge_Smart_School_OS_Presentation.pptx',
);
const scriptPath = join(
  __dirname,
  '..',
  'docs',
  'Majo_Bridge_Smart_School_OS_Script.md',
);

const C = {
  navy: '0B3D4A',
  teal: '0F766E',
  tealSoft: 'CCFBF1',
  ink: '0F172A',
  muted: '475569',
  soft: 'F8FAFC',
  white: 'FFFFFF',
  gold: 'B45309',
  cream: 'FFFBEB',
  line: 'E2E8F0',
  blue: '1D4ED8',
  blueSoft: 'DBEAFE',
};

const pptx = new pptxgen();
pptx.author = 'MaJo-Bridge Technology PLC';
pptx.title = FULL;
pptx.subject = 'Executive briefing — CEO + Deputy Manager';
pptx.layout = 'LAYOUT_WIDE';

let page = 0;

function footer(slide) {
  page += 1;
  slide.addText(`${FULL}  ·  MaJo-Bridge Technology PLC`, {
    x: 0.35,
    y: 7.15,
    w: 11.2,
    h: 0.25,
    fontSize: 9,
    color: C.muted,
    fontFace: 'Calibri',
  });
  slide.addText(String(page), {
    x: 12.0,
    y: 7.15,
    w: 0.9,
    h: 0.25,
    fontSize: 9,
    color: C.muted,
    fontFace: 'Calibri',
    align: 'right',
  });
}

function titleBlock(slide, title, subtitle) {
  slide.addText(title, {
    x: 0.45,
    y: 0.35,
    w: 12.4,
    h: 0.5,
    fontSize: 26,
    bold: true,
    color: C.navy,
    fontFace: 'Calibri',
  });
  if (subtitle) {
    slide.addText(subtitle, {
      x: 0.45,
      y: 0.88,
      w: 12.4,
      h: 0.32,
      fontSize: 13,
      color: C.muted,
      fontFace: 'Calibri',
    });
  }
}

function accentBar(slide) {
  slide.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 0.12,
    h: 7.5,
    fill: { color: C.teal },
  });
}

function notes(slide, text) {
  slide.addNotes(text);
}

function chipGrid(slide, items, opts = {}) {
  const cols = opts.cols || 4;
  const startY = opts.y || 1.35;
  const cardH = opts.h || 1.15;
  const gap = 0.15;
  const cardW = (12.4 - gap * (cols - 1)) / cols;
  items.forEach((item, i) => {
    const col = i % cols;
    const row = Math.floor(i / cols);
    const x = 0.45 + col * (cardW + gap);
    const y = startY + row * (cardH + gap);
    slide.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y,
      w: cardW,
      h: cardH,
      fill: { color: C.soft },
      line: { color: C.line, width: 1 },
      rectRadius: 0.08,
    });
    const label = typeof item === 'string' ? item : item.t;
    const sub = typeof item === 'string' ? null : item.b;
    slide.addText(label, {
      x: x + 0.15,
      y: y + (sub ? 0.2 : 0.35),
      w: cardW - 0.3,
      h: sub ? 0.35 : 0.45,
      fontSize: opts.fontSize || 13,
      bold: true,
      color: C.navy,
      fontFace: 'Calibri',
      align: 'center',
    });
    if (sub) {
      slide.addText(sub, {
        x: x + 0.12,
        y: y + 0.58,
        w: cardW - 0.24,
        h: 0.45,
        fontSize: 11,
        color: C.muted,
        fontFace: 'Calibri',
        align: 'center',
      });
    }
  });
}

// ─── 1 Opening ─────────────────────────────────────────────
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 13.333,
    h: 7.5,
    fill: { color: C.navy },
  });
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 5.95,
    w: 13.333,
    h: 1.55,
    fill: { color: C.teal },
  });
  s.addText(BRAND.toUpperCase(), {
    x: 0.7,
    y: 1.7,
    w: 12,
    h: 0.4,
    fontSize: 14,
    bold: true,
    color: C.tealSoft,
    fontFace: 'Calibri',
    charSpacing: 4,
  });
  s.addText(PRODUCT, {
    x: 0.7,
    y: 2.25,
    w: 12,
    h: 0.9,
    fontSize: 36,
    bold: true,
    color: C.white,
    fontFace: 'Calibri',
  });
  s.addText(
    'One operating system for the whole school — academics, leadership, family & transport',
    {
      x: 0.7,
      y: 3.4,
      w: 11.5,
      h: 0.5,
      fontSize: 16,
      color: C.tealSoft,
      fontFace: 'Calibri',
    },
  );
  s.addText('MaJo-Bridge Technology PLC  ·  Executive briefing', {
    x: 0.7,
    y: 6.4,
    w: 11.5,
    h: 0.4,
    fontSize: 14,
    color: C.white,
    fontFace: 'Calibri',
  });
  notes(
    s,
    'CEO opens with name/role verbally (not on slide). Introduce Majo Bridge Smart School Operating System.',
  );
}

// ─── 2 Challenge ───────────────────────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(s, 'The Challenge', 'Why schools need a smarter operating system');
  chipGrid(
    s,
    [
      { t: 'Paper-heavy work', b: 'Admin still on paper' },
      { t: 'Slow updates', b: 'Parents wait for news' },
      { t: 'Scattered data', b: 'Many files, many truths' },
      { t: 'Weak tracking', b: 'Hard to see progress' },
      { t: 'Transport gaps', b: 'Bus safety unclear' },
      { t: 'Siloed roles', b: 'GM → HR not connected' },
      { t: 'No memory hub', b: 'Photos & events lost' },
      { t: 'Our question', b: 'How do we connect it all?' },
    ],
    { cols: 4, y: 1.4, h: 2.35 },
  );
  notes(s, 'CEO: short problem list → “easier, smarter, more connected.”');
  footer(s);
}

// ─── 3 Solution ────────────────────────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(s, 'Our Solution', FULL);
  s.addText('Five connections in one platform', {
    x: 0.45,
    y: 1.3,
    w: 12.4,
    h: 0.3,
    fontSize: 14,
    color: C.muted,
    fontFace: 'Calibri',
  });
  ['School', 'Teachers', 'Students', 'Parents', 'Transport'].forEach((n, i) => {
    const x = 0.45 + i * 2.55;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y: 1.8,
      w: 2.4,
      h: 1.35,
      fill: { color: i === 4 ? C.navy : C.teal },
      rectRadius: 0.1,
    });
    s.addText(n, {
      x,
      y: 2.2,
      w: 2.4,
      h: 0.5,
      fontSize: 16,
      bold: true,
      color: C.white,
      fontFace: 'Calibri',
      align: 'center',
    });
  });
  s.addText('Leadership inside the same system', {
    x: 0.45,
    y: 3.45,
    w: 12.4,
    h: 0.3,
    fontSize: 14,
    color: C.muted,
    fontFace: 'Calibri',
  });
  chipGrid(
    s,
    [
      'General Manager',
      'Deputy Manager',
      'Section Directors',
      'Student Affairs',
      'Quality Assurance',
      'Finance',
      'Human Resources',
      'Procurement',
    ],
    { cols: 4, y: 3.85, h: 1.2, fontSize: 12 },
  );
  notes(
    s,
    'CEO: five portals + leadership roles (GM, Deputy, SD, SA, QA, Finance, HR, Procurement).',
  );
  footer(s);
}

// ─── 4 Vision ──────────────────────────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(s, 'Our Vision');
  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.45,
    y: 1.4,
    w: 12.4,
    h: 1.5,
    fill: { color: C.cream },
    rectRadius: 0.1,
  });
  s.addText(
    'Turn traditional schools into smart, connected,\ndata-driven institutions — run like a modern organization.',
    {
      x: 0.8,
      y: 1.75,
      w: 11.7,
      h: 0.9,
      fontSize: 20,
      bold: true,
      color: C.navy,
      fontFace: 'Calibri',
    },
  );
  chipGrid(
    s,
    [
      'Smart operations',
      'Clear communication',
      'Digital learning',
      'Data-driven decisions',
      'Stronger parent trust',
      'Safer transport',
    ],
    { cols: 3, y: 3.3, h: 1.4 },
  );
  notes(s, 'CEO: vision in one sentence, then six short pillars.');
  footer(s);
}

// ─── 5 Why + handoff ───────────────────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(s, `Why ${BRAND}?`, 'What makes the operating system different');
  chipGrid(
    s,
    [
      { t: 'One integrated OS', b: 'Academics → stores → bus' },
      { t: 'Web + mobile', b: 'Staff, family, drivers' },
      { t: 'Role-based control', b: 'GM → HR permissions' },
      { t: 'Approve before publish', b: 'Grades only after OK' },
      { t: 'EN · አማርኛ · Afaan Oromo', b: 'Local-ready UX' },
      { t: 'School data isolation', b: 'Each school secured' },
    ],
    { cols: 3, y: 1.35, h: 1.55 },
  );
  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.45,
    y: 5.0,
    w: 12.4,
    h: 1.7,
    fill: { color: C.blueSoft },
    rectRadius: 0.1,
  });
  s.addText('HANDOFF', {
    x: 0.75,
    y: 5.25,
    w: 11.8,
    h: 0.3,
    fontSize: 12,
    bold: true,
    color: C.blue,
    fontFace: 'Calibri',
  });
  s.addText(
    '“Now our Deputy Manager will show how the system works — portals, leadership roles, and daily school services.”',
    {
      x: 0.75,
      y: 5.7,
      w: 11.8,
      h: 0.7,
      fontSize: 15,
      color: C.ink,
      fontFace: 'Calibri',
    },
  );
  notes(s, 'CEO handoff to Deputy Manager (spoken only).');
  footer(s);
}

// ─── 6 Five portals ────────────────────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(s, 'How It Works', 'Five user portals · one operating system');
  const roles = [
    ['School Admin', 'Whole-school control · multi-campus'],
    ['Teachers', 'Attendance · timetable · grades · homework'],
    ['Students', 'Learn · submit · results · QR profile'],
    ['Parents', 'Secure link · progress · fees · bus · daily report'],
    ['Transport Handler', 'Routes · live bus · pickup / drop-off'],
  ];
  roles.forEach((r, i) => {
    const y = 1.35 + i * 1.05;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x: 0.45,
      y,
      w: 12.4,
      h: 0.9,
      fill: { color: i % 2 ? C.soft : C.white },
      line: { color: C.line, width: 1 },
      rectRadius: 0.08,
    });
    s.addText(r[0], {
      x: 0.8,
      y: y + 0.22,
      w: 4.5,
      h: 0.45,
      fontSize: 16,
      bold: true,
      color: C.navy,
      fontFace: 'Calibri',
    });
    s.addText(r[1], {
      x: 5.5,
      y: y + 0.25,
      w: 7.0,
      h: 0.4,
      fontSize: 15,
      color: C.muted,
      fontFace: 'Calibri',
    });
  });
  notes(s, 'Deputy: five portals quickly.');
  footer(s);
}

// ─── 7 Leadership roles ────────────────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(
    s,
    'Leadership & Operations Roles',
    'Every key office has the right access — not one shared password',
  );
  chipGrid(
    s,
    [
      { t: 'General Manager', b: 'School-wide oversight' },
      { t: 'Deputy Manager', b: 'Daily executive control' },
      { t: 'Section Directors', b: 'Classes · teacher assign · grade approve' },
      { t: 'Student Affairs', b: 'Welfare · transfers · promotion' },
      { t: 'Quality Assurance', b: 'Standards · findings' },
      { t: 'Finance', b: 'Fees · money visibility' },
      { t: 'Human Resources', b: 'Staff · roles · access' },
      { t: 'Procurement', b: 'Purchasing · inventory' },
    ],
    { cols: 4, y: 1.35, h: 2.15 },
  );
  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.45,
    y: 5.85,
    w: 12.4,
    h: 0.9,
    fill: { color: C.cream },
    rectRadius: 0.08,
  });
  s.addText(
    'Quality gate: teachers enter grades → leadership approves → only then parents see results. Audit-ready role access — no shared passwords.',
    {
      x: 0.7,
      y: 6.05,
      w: 11.9,
      h: 0.55,
      fontSize: 13,
      color: C.ink,
      fontFace: 'Calibri',
    },
  );
  notes(
    s,
    'Deputy: roles + grade approve-before-publish + audit/permissions.',
  );
  footer(s);
}

// ─── 8 Core management + learning ──────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(s, 'Core School Services', 'Management · teaching · family · transport');
  const cols = [
    {
      h: 'Manage',
      items: [
        'Registration · multi-campus',
        'Attendance · timetable',
        'Grade approve → publish',
        'Transfers · promotion',
        'Inventory · library · reports',
      ],
    },
    {
      h: 'Teach & Learn',
      items: [
        'Homework both sides',
        'Assignments · quizzes',
        'eBooks · materials sell',
        'Learning materials',
        'Maya Assistant (in-app)',
      ],
    },
    {
      h: 'Family & Bus',
      items: [
        'Secure parent–child link',
        'Daily activity report',
        'Fees · announcements',
        'Live bus tracking',
        'EN / አማርኛ / Afaan Oromo',
      ],
    },
  ];
  cols.forEach((c, i) => {
    const x = 0.45 + i * 4.25;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y: 1.3,
      w: 4.05,
      h: 5.4,
      fill: { color: C.soft },
      rectRadius: 0.1,
    });
    s.addText(c.h, {
      x: x + 0.25,
      y: 1.5,
      w: 3.55,
      h: 0.4,
      fontSize: 17,
      bold: true,
      color: C.teal,
      fontFace: 'Calibri',
    });
    c.items.forEach((it, j) => {
      s.addText(`▸  ${it}`, {
        x: x + 0.25,
        y: 2.15 + j * 0.8,
        w: 3.55,
        h: 0.7,
        fontSize: 13,
        color: C.ink,
        fontFace: 'Calibri',
      });
    });
  });
  notes(
    s,
    'Deputy: cover grade approval, transfers, inventory/library/reports, parent link, languages, Maya Assistant.',
  );
  footer(s);
}

// ─── 9 Platform extras (compact) ───────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(
    s,
    'More Built Into the OS',
    'Community · learning · trust — still one system',
  );
  chipGrid(
    s,
    [
      { t: 'Photo / Video Gallery', b: 'School memories' },
      { t: 'Internal Messaging', b: 'Built-in chat' },
      { t: 'Announcements', b: 'One clear channel' },
      { t: 'Calendar & Events', b: 'School schedule' },
      { t: 'Homework Upload', b: 'Teacher ↔ Student' },
      { t: 'eBook & eLearning Sell', b: 'Digital materials' },
      { t: 'Daily Parent Report', b: 'What happened today' },
      { t: 'Student Profile + QR', b: 'Fast ID & access' },
      { t: 'Secure Parent Link', b: 'ID + DOB · approved' },
      { t: 'Exports Excel/PDF/CSV', b: 'Board-ready reports' },
      { t: 'Audit & Staff Roles', b: 'Who can do what' },
      { t: 'Cloud School Isolation', b: 'Your data stays yours' },
    ],
    { cols: 4, y: 1.3, h: 1.75 },
  );
  notes(
    s,
    'Deputy: extras + parent link, exports, audit roles, school isolation — keep brisk.',
  );
  footer(s);
}

// ─── 10 Benefits ───────────────────────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(s, 'Benefits for Schools');
  chipGrid(
    s,
    [
      'Less paperwork',
      'Save staff time',
      'Clearer communication',
      'Grade quality control',
      'Engage parents',
      'Safer transport',
      'Multi-campus ready',
      'Local languages',
    ],
    { cols: 4, y: 1.45, h: 2.2 },
  );
  notes(s, 'Deputy: benefits — include quality control, multi-campus, languages.');
  footer(s);
}

// ─── 11 Partnership + AI (merged) ──────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(s, 'Partnership & Intelligence', 'Business value · intelligence already in the OS');
  chipGrid(
    s,
    [
      { t: 'Digital transformation', b: 'Modern school brand' },
      { t: 'Stronger competitiveness', b: 'Win parent trust' },
      { t: 'Long-term records', b: 'Institutional memory' },
      { t: 'Pilot → scale', b: 'Start one campus / grade' },
    ],
    { cols: 4, y: 1.3, h: 1.85 },
  );
  s.addText('Intelligence', {
    x: 0.45,
    y: 3.4,
    w: 12.4,
    h: 0.3,
    fontSize: 13,
    bold: true,
    color: C.muted,
    fontFace: 'Calibri',
  });
  chipGrid(
    s,
    [
      { t: 'Maya Assistant', b: 'Live in-app' },
      { t: 'AI Tutor support', b: 'Implemented' },
      { t: 'AI for Staff / Parents', b: 'Implemented' },
      { t: 'AI Analytics', b: 'Implemented' },
    ],
    { cols: 4, y: 3.8, h: 2.0 },
  );
  notes(
    s,
    'Deputy: intelligence is implemented. Pilot path. Hand back to CEO.',
  );
  footer(s);
}

// ─── 12 Why partner (CEO) ──────────────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(s, `Why Partner With ${BRAND}?`);
  s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
    x: 0.45,
    y: 1.4,
    w: 12.4,
    h: 1.8,
    fill: { color: C.cream },
    rectRadius: 0.1,
  });
  s.addText(
    'Education’s future is connected, digital, and intelligent.\nMajo Bridge lets schools start that transformation today.',
    {
      x: 0.8,
      y: 1.8,
      w: 11.7,
      h: 1.1,
      fontSize: 18,
      bold: true,
      color: C.navy,
      fontFace: 'Calibri',
    },
  );
  ['Technology', 'Education', 'Partnership', 'Better Schools'].forEach((t, i) => {
    const x = 0.45 + i * 3.2;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x,
      y: 3.7,
      w: 3.0,
      h: 2.4,
      fill: { color: i === 3 ? C.gold : C.teal },
      rectRadius: 0.1,
    });
    s.addText(t, {
      x,
      y: 4.55,
      w: 3.0,
      h: 0.7,
      fontSize: 16,
      bold: true,
      color: C.white,
      fontFace: 'Calibri',
      align: 'center',
    });
  });
  notes(s, 'CEO: Technology + Education + Partnership = Better Schools.');
  footer(s);
}

// ─── 13 Already implemented ────────────────────────────────
{
  const s = pptx.addSlide();
  accentBar(s);
  titleBlock(s, 'Already Implemented', 'Not a future promise — live in the platform today');
  const phases = [
    ['✓ Live', 'School OS & leadership roles'],
    ['✓ Live', 'Parent, teacher & transport services'],
    ['✓ Live', 'Digital learning & eMaterials'],
    ['✓ Live', 'AI Assistant in-app (deeper AI continues)'],
    ['✓ Live', 'Ready for regional school rollout'],
  ];
  phases.forEach((p, i) => {
    const y = 1.4 + i * 1.0;
    s.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
      x: 1.2,
      y,
      w: 10.9,
      h: 0.85,
      fill: { color: C.tealSoft },
      rectRadius: 0.08,
    });
    s.addText(p[0], {
      x: 1.5,
      y: y + 0.22,
      w: 2.2,
      h: 0.4,
      fontSize: 15,
      bold: true,
      color: C.teal,
      fontFace: 'Calibri',
    });
    s.addText(p[1], {
      x: 4.0,
      y: y + 0.22,
      w: 7.8,
      h: 0.4,
      fontSize: 15,
      color: C.ink,
      fontFace: 'Calibri',
    });
  });
  notes(s, 'CEO: all major capabilities are already implemented / live.');
  footer(s);
}

// ─── 14 Closing ────────────────────────────────────────────
{
  const s = pptx.addSlide();
  s.addShape(pptx.shapes.RECTANGLE, {
    x: 0,
    y: 0,
    w: 13.333,
    h: 7.5,
    fill: { color: C.navy },
  });
  s.addText(FULL, {
    x: 0.7,
    y: 1.2,
    w: 12,
    h: 0.4,
    fontSize: 15,
    bold: true,
    color: C.tealSoft,
    fontFace: 'Calibri',
  });
  s.addText('More than an app.\nA school operating system.', {
    x: 0.7,
    y: 1.75,
    w: 12,
    h: 1.2,
    fontSize: 30,
    bold: true,
    color: C.white,
    fontFace: 'Calibri',
  });
  s.addText(
    'Schools · teachers · students · parents · transport\nGM · Deputy · Section Directors · Student Affairs · QA · Finance · HR · Procurement',
    {
      x: 0.7,
      y: 3.2,
      w: 11.8,
      h: 0.9,
      fontSize: 14,
      color: C.tealSoft,
      fontFace: 'Calibri',
    },
  );
  s.addText(
    'EN / አማርኛ / Afaan Oromo   ·   Live: mayabela.pages.dev\n+251 911 646 444   ·   majobridgetech@gmail.com',
    {
      x: 0.7,
      y: 4.4,
      w: 11.8,
      h: 0.8,
      fontSize: 15,
      color: C.white,
      fontFace: 'Calibri',
    },
  );
  s.addText(
    'Smarter. More connected. More accessible. Let’s build it together.',
    {
      x: 0.7,
      y: 5.6,
      w: 11.8,
      h: 0.5,
      fontSize: 16,
      color: C.tealSoft,
      fontFace: 'Calibri',
    },
  );
  notes(s, 'CEO close: languages, live URL, support contacts, thank you, Q&A.');
}

mkdirSync(dirname(outPath), { recursive: true });
await pptx.writeFile({ fileName: outPath });
console.log('Wrote', outPath);

const script = `# ${FULL} — 2-Speaker Script

**File:** \`docs/Majo_Bridge_Smart_School_OS_Presentation.pptx\`  
**Note:** Presenter names are **not** on slides — say them verbally.

## CEO (Slides 1–5)
1. Opening — introduce ${FULL}
2. Challenge
3. Solution — 5 portals + leadership roles (GM, Deputy, SD, SA, QA, Finance, HR, Procurement)
4. Vision
5. Why ${BRAND}? → handoff to Deputy

## Deputy (Slides 6–11)
6. Five portals (multi-campus, parent secure link, QR, bus)
7. Leadership roles + **grade approve → publish** + audit access
8. Core services — also: transfers, inventory, library, reports, Maya Assistant, languages
9. More OS — gallery, messaging, announcements, calendar, homework, eBooks, daily report, QR, **parent link, Excel/PDF exports, audit roles, cloud isolation**
10. Benefits (quality control · multi-campus · languages)
11. Partnership + intelligence **implemented** · pilot path → CEO

## CEO (Slides 12–14)
12. Why partner
13. Already implemented (not future roadmap)
14. Closing · majobridgetech@gmail.com

**Timing:** ~12–14 minutes + Q&A
`;

writeFileSync(scriptPath, script, 'utf8');
console.log('Wrote', scriptPath);
