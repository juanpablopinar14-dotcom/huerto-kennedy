# 🥬 Huerto Kennedy — Inventario y Punto de Venta

App interna para vender, gestionar productos, compras, merma y ver rentabilidad por producto.
Sin servidor propio: **GitHub Pages** (sirve la página) + **Supabase** (base de datos).

## Qué hace
- **Vender** en 3 modos: seleccionar productos, escanear código de barras (cámara), o foto de lo vendido (IA).
- **Productos**: editar nombre, código, formato, precio de venta y de compra. Cada cambio de precio queda en historial.
- **Compras**: registras "5 sacos de zanahoria" y convierte a kg y calcula costo por kg. Puede actualizar el costo del producto.
- **Merma**: registro de pérdidas con costo estimado.
- **Dashboard**: margen $ y % por producto en un rango de fechas. Rojo = pierdes plata.

> Cada venta/compra **congela su precio**: el dashboard usa lo que pasó de verdad, no el precio de hoy.

---

## Puesta en marcha (15 min)

### Paso 1 — Base de datos (Supabase)
1. Crea cuenta gratis en https://supabase.com → **New project**.
2. Menú **SQL Editor** → New query → pega el contenido de `schema.sql` → **Run**.
3. Otra query → pega `seed.sql` → **Run** (carga tus 79 productos y las conversiones).
4. Menú **Settings → API**: copia **Project URL** y la **anon public key**.

### Paso 2 — Publicar la página (GitHub Pages)
1. Crea un repo en GitHub, ej. `huerto-kennedy`.
2. Sube estos archivos (`index.html`, `schema.sql`, `seed.sql`, `README.md`, carpeta `supabase/`).
   - Web: botón **Add file → Upload files**, arrastra todo, **Commit**.
   - O por consola:
     ```bash
     git init && git add . && git commit -m "inicial"
     git branch -M main
     git remote add origin https://github.com/USUARIO/huerto-kennedy.git
     git push -u origin main
     ```
3. En el repo: **Settings → Pages → Source: Deploy from a branch → main / (root) → Save**.
4. En 1–2 min queda en `https://USUARIO.github.io/huerto-kennedy/`.

### Paso 3 — Conectar la página con la base
Edita `index.html`, arriba, el bloque CONFIG:
```js
const SUPABASE_URL      = "https://xxxx.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGci...";
```
Commit. Listo: la insignia arriba dirá **"conectado a base de datos"**.

> Si dejas los valores en `PEGAR_...`, la app corre en **modo local** (guarda en el navegador). Sirve para probar, pero NO persiste entre dispositivos ni es respaldo.

### Paso 4 (opcional) — Foto de lo vendido con IA
Necesita la CLI de Supabase (`npm i -g supabase`) y una API key de Anthropic:
```bash
supabase login
supabase link --project-ref TU_REF
supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxxx
supabase functions deploy analizar-venta --no-verify-jwt
```
Desde ese momento el modo **Foto** funciona.

---

## Seguridad
El esquema deja acceso abierto con la `anon key` (uso interno detrás de una URL privada). **No es seguridad real.**
Para cerrarlo: activa **Supabase Auth** (email mágico) y cambia las policies `p_all` por `using (auth.role() = 'authenticated')`.

## Costos
- GitHub Pages: gratis. Supabase free tier: gratis (500 MB, suficiente por años para esto).
- Solo la función de Foto consume API de Anthropic (centavos por foto).

## Falta / ideas Fase 2
- Cierre de caja diario (arqueo) y cuadre contra Mercado Pago / TUU.
- Alertas de stock y sugerencia de reposición.
- Multiusuario con login por PIN.
- Exportar a Google Sheets (ya tienes skills para eso).
