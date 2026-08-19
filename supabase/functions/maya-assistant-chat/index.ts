import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    const authHeader = req.headers.get("Authorization") || "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: userData } = await userClient.auth.getUser();
    if (!userData.user) return errorResponse("Sign in required.", 401);

    const body = await req.json();
    const roleKey = String(body?.roleKey || userData.user.app_metadata?.role || "admin");
    const message = String(body?.message || "").trim();
    if (!message) return errorResponse("message required.", 400);

    const apiKey = Deno.env.get("MAYA_AI_API_KEY") || Deno.env.get("GEMINI_API_KEY") || "";
    if (!apiKey) {
      return errorResponse("Maya AI key not configured.", 412, "no_key");
    }

    const titleByRole: Record<string, string> = {
      admin: "Maya Assistant",
      teacher: "Maya Teacher Assistant",
      student: "Maya Tutor",
      parent: "Maya Family Assistant",
      driver: "Maya Route Assistant",
      platform_owner: "Maya Executive Assistant",
    };
    const title = titleByRole[roleKey] || "Maya Assistant";
    const history = Array.isArray(body?.history) ? body.history.slice(-12) : [];
    const contents: Array<{ role: string; parts: Array<{ text: string }> }> = [];
    for (const row of history) {
      const text = String(row?.text || "").trim();
      if (!text) continue;
      contents.push({
        role: row?.role === "user" ? "user" : "model",
        parts: [{ text }],
      });
    }
    contents.push({ role: "user", parts: [{ text: message }] });

    const system = [
      `You are ${title} inside MayaBela school ERP.`,
      "Be concise, practical, and safe. Help with in-app workflows only.",
      "Do not invent grades, fees, medical data, or student PII.",
      `User portal role: ${roleKey}.`,
    ].join(" ");

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents,
      }),
    });
    if (!res.ok) {
      const errText = await res.text();
      return errorResponse(`Gemini error: ${errText}`, 502);
    }
    const json = await res.json();
    const reply = json?.candidates?.[0]?.content?.parts
      ?.map((p: { text?: string }) => p.text || "")
      .join("")
      .trim();
    if (!reply) return errorResponse("Empty AI reply.", 502);
    return jsonResponse({ reply });
  } catch (e) {
    console.error(e);
    return errorResponse(String(e?.message || e), 500);
  }
});
