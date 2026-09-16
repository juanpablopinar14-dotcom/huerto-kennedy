-- ============================================================
-- Huerto Kennedy · Esquema de base de datos (Supabase / Postgres)
-- Ejecutar completo en: Supabase > SQL Editor > New query > Run
-- ============================================================

-- Extensión para UUIDs
create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- 1. PRODUCTOS (catálogo maestro; precio_venta/compra = valor ACTUAL por defecto)
-- ------------------------------------------------------------
create table if not exists productos (
  id            uuid primary key default gen_random_uuid(),
  codigo        integer,                 -- PLU / código de barra (puede ser null)
  nombre        text not null,
  formato       text not null default 'Unidad' check (formato in ('Unidad','Peso')), -- Peso = se vende por kg
  precio_venta  integer not null default 0,   -- CLP actual
  precio_compra integer,                        -- CLP actual (costo)
  categoria     text,
  activo        boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists idx_productos_codigo on productos(codigo);
create index if not exists idx_productos_nombre on productos(lower(nombre));

-- ------------------------------------------------------------
-- 2. HISTORIAL DE PRECIOS (cada cambio de precio de lista queda registrado)
-- ------------------------------------------------------------
create table if not exists precio_historial (
  id           uuid primary key default gen_random_uuid(),
  producto_id  uuid references productos(id) on delete cascade,
  tipo         text not null check (tipo in ('venta','compra')),
  precio       integer not null,
  fecha        timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. VENTAS (cabecera + items; cada item CONGELA precio de venta y de compra)
-- ------------------------------------------------------------
create table if not exists ventas (
  id          uuid primary key default gen_random_uuid(),
  fecha       date not null default current_date,
  total       integer not null default 0,
  medio_pago  text,                                  -- efectivo / tarjeta / transferencia
  origen      text not null default 'manual' check (origen in ('manual','scan','foto')),
  nota        text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_ventas_fecha on ventas(fecha);

create table if not exists venta_items (
  id                       uuid primary key default gen_random_uuid(),
  venta_id                 uuid not null references ventas(id) on delete cascade,
  producto_id              uuid references productos(id) on delete set null,
  codigo_snapshot          integer,
  nombre_snapshot          text not null,
  formato                  text not null default 'Unidad',
  cantidad                 numeric not null default 1,    -- kg (Peso) o unidades (Unidad)
  precio_unitario          integer not null default 0,    -- CLP por kg o por unidad, congelado
  precio_compra_snapshot   integer,                        -- costo por kg/un al momento de la venta
  importe                  integer not null default 0      -- cantidad * precio_unitario
);
create index if not exists idx_venta_items_venta on venta_items(venta_id);
create index if not exists idx_venta_items_prod on venta_items(producto_id);

-- ------------------------------------------------------------
-- 4. COMPRAS (cabecera + items con conversión formato -> kg)
-- ------------------------------------------------------------
create table if not exists compras (
  id          uuid primary key default gen_random_uuid(),
  fecha       date not null default current_date,
  proveedor   text,
  total       integer not null default 0,
  nota        text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_compras_fecha on compras(fecha);

create table if not exists compra_items (
  id                uuid primary key default gen_random_uuid(),
  compra_id         uuid not null references compras(id) on delete cascade,
  producto_id       uuid references productos(id) on delete set null,
  nombre            text not null,
  formato_compra    text,             -- ej: 'saco', 'malla', 'caja'
  cantidad_bruta    numeric not null default 1,   -- ej: 5 (sacos)
  kg_por_formato    numeric,          -- ej: 20 (kg por saco) usado en la conversión
  kg_equivalente    numeric not null default 0,   -- cantidad_bruta * kg_por_formato
  costo_total       integer not null default 0,   -- CLP pagados
  costo_unitario_kg integer          -- costo_total / kg_equivalente (redondeado)
);
create index if not exists idx_compra_items_compra on compra_items(compra_id);
create index if not exists idx_compra_items_prod on compra_items(producto_id);

-- ------------------------------------------------------------
-- 5. MERMA (pérdida / desecho)
-- ------------------------------------------------------------
create table if not exists merma (
  id              uuid primary key default gen_random_uuid(),
  fecha           date not null default current_date,
  producto_id     uuid references productos(id) on delete set null,
  nombre          text not null,
  cantidad        numeric not null default 0,
  unidad          text not null default 'kg' check (unidad in ('kg','un')),
  motivo          text,
  costo_estimado  integer,            -- cantidad * precio_compra actual (estimado al registrar)
  created_at      timestamptz not null default now()
);
create index if not exists idx_merma_fecha on merma(fecha);

-- ------------------------------------------------------------
-- 6. CONVERSIONES (tabla de referencia formato -> kg, editable)
-- ------------------------------------------------------------
create table if not exists conversiones (
  id       uuid primary key default gen_random_uuid(),
  formato  text not null,     -- ej: 'saco zanahoria'
  kg       numeric not null,  -- kg aproximados
  nota     text
);

-- ------------------------------------------------------------
-- 7. VISTA de rentabilidad por producto (base del dashboard)
-- ------------------------------------------------------------
create or replace view v_rentabilidad_producto as
select
  coalesce(vi.producto_id::text, vi.nombre_snapshot)      as clave,
  max(vi.nombre_snapshot)                                  as producto,
  v.fecha                                                  as fecha,
  sum(vi.importe)                                          as ingresos,
  sum(vi.cantidad * coalesce(vi.precio_compra_snapshot,0)) as costo_ventas,
  sum(vi.importe) - sum(vi.cantidad * coalesce(vi.precio_compra_snapshot,0)) as margen,
  sum(vi.cantidad)                                         as cantidad_vendida
from venta_items vi
join ventas v on v.id = vi.venta_id
group by coalesce(vi.producto_id::text, vi.nombre_snapshot), v.fecha;

-- ------------------------------------------------------------
-- 8. RLS (seguridad). Uso interno: acceso total con la anon key.
--    OJO: esto NO es seguridad real, solo evita bloqueos. Ver README para cerrar con Auth.
-- ------------------------------------------------------------
alter table productos        enable row level security;
alter table precio_historial enable row level security;
alter table ventas           enable row level security;
alter table venta_items      enable row level security;
alter table compras          enable row level security;
alter table compra_items     enable row level security;
alter table merma            enable row level security;
alter table conversiones     enable row level security;

do $$
declare t text;
begin
  foreach t in array array['productos','precio_historial','ventas','venta_items','compras','compra_items','merma','conversiones']
  loop
    execute format('drop policy if exists p_all on %I;', t);
    execute format('create policy p_all on %I for all using (true) with check (true);', t);
  end loop;
end $$;
