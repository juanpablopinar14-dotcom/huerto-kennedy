// ============================================================
// Edge Function: analizar-venta
// Lee una foto de lo vendido y devuelve items {producto_id, codigo, cantidad}
// La API key queda AQUÍ (servidor), nunca en el navegador.
//
// Deploy:  supabase functions deploy analizar-venta
// Secret:  supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
// ============================================================
import { serve } from "https://deno.land/std@0.208.0/http/server.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { image, productos } = await req.json();
    const catalogo = (productos || [])
      .map((p: any) => `${p.id} | cod:${p.codigo ?? "-"} | ${p.nombre} | ${p.formato}`)
      .join("\n");

    const prompt = `Eres el sistema de caja de una verdulería. Te paso una foto de una lista/ticket de lo vendido y el catálogo de productos.
Devuelve SOLO un JSON válido, sin texto ni markdown, con esta forma:
{"items":[{"producto_id":"<id del catálogo o null>","codigo":<codigo o null>,"nombre":"<nombre leído>","cantidad":<numero>}]}
Reglas:
- Cruza cada línea con el catálogo por código o por nombre más parecido; usa el id del catálogo cuando haya match.
- "cantidad" = kg si el producto es formato Peso, o unidades si es Unidad.
- Ignora totales y encabezados.

CATÁLOGO (id | codigo | nombre | formato):
${catalogo}`;

    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: 2000,
        messages: [{
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: "image/jpeg", data: image } },
            { type: "text", text: prompt },
          ],
        }],
      }),
    });
    const data = await resp.json();
    const text = (data.content || []).filter((b: any) => b.type === "text").map((b: any) => b.text).join("");
    const clean = text.replace(/```json|```/g, "").trim();
    const parsed = JSON.parse(clean);
    return new Response(JSON.stringify(parsed), { headers: { ...CORS, "content-type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e), items: [] }), {
      status: 200, headers: { ...CORS, "content-type": "application/json" },
    });
  }
});
