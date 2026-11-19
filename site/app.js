const WA_NUMBER = "251912798279";

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
