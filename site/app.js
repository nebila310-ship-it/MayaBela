const WA_NUMBER = "251912798279";

const INTROS = {
  admin: {
    kicker: "Portal",
    title: "Administration",
    body: "The school’s operating desk. Directors, finance and office staff run students, fees, HR, inventory and dashboards from one web ERP — not a stack of exercise books.",
  },
  teacher: {
    kicker: "Portal",
    title: "Teacher",
    body: "The classroom door. Teachers take attendance, set homework, enter marks, plan lessons and message parents without leaving their class list.",
  },
  parent: {
    kicker: "Portal",
    title: "Parent",
    body: "A phone the family already uses. See if a child is in class, follow fees, read notices and watch the school bus — in English, Amharic or Afaan Oromo.",
  },
  student: {
    kicker: "Portal",
    title: "Student",
    body: "The learner’s own desk. Timetable, homework, results and school notices — not a copy of the staff screens.",
  },
  driver: {
    kicker: "Portal",
    title: "Driver",
    body: "Transport in the same system. Routes, boarding and live GPS so the office and parents see the same bus.",
  },
  platform: {
    kicker: "Portal",
    title: "Platform console",
    body: "How Majo Bridge runs many schools. Modules, branding and licences are switched per campus. Your school keeps its own data.",
  },
  classroom: {
    kicker: "Module group",
    title: "Classroom",
    body: "The academic year in one place: admissions, class allocation, timetable, attendance, homework, assessment, exams, report cards and a grade audit.",
  },
  finance: {
    kicker: "Module group",
    title: "Fees & ledger",
    body: "How money moves. Fee structures, student invoices, receipts, cashboxes and a double-entry ledger the finance desk can actually close.",
  },
  hr: {
    kicker: "Module group",
    title: "HR & payroll",
    body: "People of the school: staff records, leave, roles, and Ethiopian payroll with tax and pension — next to the same student file.",
  },
  family: {
    kicker: "Module group",
    title: "Parent & student",
    body: "The family side of the OS: parent and student apps, messaging, gallery, calendar, cafeteria and library — what homes open after 3 p.m.",
  },
  campus: {
    kicker: "Module group",
    title: "Transport & ops",
    body: "The school as a place: bus routes and GPS, inventory, procurement, facilities, clinic and safeguarding. Operations, not only marks.",
  },
  languages: {
    kicker: "Module group",
    title: "Languages",
    body: "English, Amharic (አማርኛ) and Afaan Oromo on the desks families actually use. The school does not wait for a translation project.",
  },
};

function openWhatsApp(text) {
  const url = `https://wa.me/${WA_NUMBER}?text=${encodeURIComponent(text)}`;
  window.open(url, "_blank", "noopener");
}

function pricingMessage(kind) {
  const school = document.getElementById("school")?.value.trim() || "our school";
  const city = document.getElementById("city")?.value.trim() || "Ethiopia";
  return [
    "Hello Majo Bridge,",
    `I would like to discuss ${kind} for Majo Bridge OS.`,
    `School: ${school}`,
    `City / region: ${city}`,
    "Please share a proposal. Thank you.",
  ].join("\n");
}

function demoMessage(data) {
  return [
    "Hello Majo Bridge, I would like a live demo of Majo Bridge OS.",
    `Name: ${data.name}`,
    `Role: ${data.role}`,
    `School: ${data.school}`,
    `City / region: ${data.city}`,
    `Students: ${data.students || "not specified"}`,
    data.notes ? `Notes: ${data.notes}` : "",
  ]
    .filter(Boolean)
    .join("\n");
}

document.querySelectorAll("[data-wa]").forEach((el) => {
  el.addEventListener("click", (event) => {
    event.preventDefault();
    const kind = el.getAttribute("data-wa");
    if (kind === "demo") {
      openWhatsApp(
        "Hello Majo Bridge, I would like a live demo of Majo Bridge OS for our school.",
      );
      return;
    }
    if (kind === "price-school") {
      openWhatsApp(pricingMessage("pricing for one school"));
      return;
    }
    if (kind === "price-group") {
      openWhatsApp(pricingMessage("pricing for a group of schools"));
      return;
    }
    openWhatsApp("Hello Majo Bridge, I would like to talk about Majo Bridge OS.");
  });
});

const form = document.getElementById("demo-form");
if (form) {
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const data = Object.fromEntries(new FormData(form).entries());
    if (!data.name || !data.school || !data.city || !data.role) {
      form.reportValidity();
      return;
    }
    openWhatsApp(demoMessage(data));
  });
}

function fillPanel(panel, key) {
  const intro = INTROS[key];
  if (!panel || !intro) return;
  panel.hidden = false;
  panel.querySelector(".intro-kicker").textContent = intro.kicker;
  panel.querySelector("h3").textContent = intro.title;
  panel.querySelector(".intro-body").textContent = intro.body;
  panel.scrollIntoView({ behavior: "smooth", block: "nearest" });
}

document.querySelectorAll("[data-intro]").forEach((el) => {
  el.addEventListener("click", () => {
    const key = el.getAttribute("data-intro");
    const group = el.classList.contains("mod") ? "module-panel" : "intro-panel";
    const panel = document.getElementById(group);
    document.querySelectorAll(el.classList.contains("mod") ? ".mod" : ".card").forEach((n) => {
      n.classList.toggle("is-open", n === el);
    });
    fillPanel(panel, key);
  });
});

const navLinks = [...document.querySelectorAll(".nav-links a")];
function markNav() {
  const y = window.scrollY + 120;
  let current = navLinks[0];
  navLinks.forEach((link) => {
    const id = link.getAttribute("href")?.slice(1);
    const section = id && document.getElementById(id);
    if (section && section.offsetTop <= y) current = link;
  });
  navLinks.forEach((link) => link.classList.toggle("is-active", link === current));
}
window.addEventListener("scroll", markNav, { passive: true });
markNav();

const openKey = new URLSearchParams(location.search).get("open");
if (openKey) {
  const target = document.querySelector(`[data-intro="${openKey}"]`);
  if (target) {
    target.click();
    target.scrollIntoView({ behavior: "instant", block: "center" });
  }
}
