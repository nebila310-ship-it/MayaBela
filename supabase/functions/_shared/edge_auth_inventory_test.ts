import { assertEquals, assert } from "jsr:@std/assert@1";
import { EDGE_AUTH_INVENTORY } from "./edge_auth_inventory.ts";

Deno.test("every Edge Function folder is in the auth inventory", async () => {
  const root = new URL("../", import.meta.url);
  const names = new Set<string>();
  for await (const entry of Deno.readDir(root)) {
    if (!entry.isDirectory) continue;
    if (entry.name.startsWith("_")) continue;
    try {
      await Deno.stat(new URL(`./${entry.name}/index.ts`, root));
    } catch {
      continue;
    }
    names.add(entry.name);
  }
  const catalogued = new Set(EDGE_AUTH_INVENTORY.map((e) => e.name));
  for (const name of names) {
    assert(catalogued.has(name), `uncatalogued Edge Function: ${name}`);
  }
  for (const name of catalogued) {
    assert(names.has(name), `inventory names a missing function: ${name}`);
  }
  assertEquals(names.size, catalogued.size);
});

Deno.test("no inventory entry is an ungated service-role path", () => {
  for (const row of EDGE_AUTH_INVENTORY) {
    assert(row.mode !== "user-jwt-or-service", row.name);
    assert(row.notes.length > 8, row.name);
  }
});
