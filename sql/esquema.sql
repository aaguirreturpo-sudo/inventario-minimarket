create table categorias (
  id bigint generated always as identity primary key,
  nombre text not null unique
);

create table productos (
  id bigint generated always as identity primary key,
  codigo text not null unique,
  nombre text not null,
  categoria_id bigint references categorias(id),
  precio_venta numeric(10,2) not null check (precio_venta >= 0),
  stock_actual integer not null default 0 check (stock_actual >= 0),
  stock_minimo integer not null default 5 check (stock_minimo >= 0),
  requiere_vencimiento boolean not null default false,
  activo boolean not null default true,
  ultima_alerta timestamptz,
  creado_en timestamptz not null default now()
);

create table lotes (
  id bigint generated always as identity primary key,
  producto_id bigint not null references productos(id) on delete cascade,
  cantidad integer not null check (cantidad >= 0),
  fecha_vencimiento date not null,
  creado_en timestamptz not null default now()
);

create table ventas (
  id bigint generated always as identity primary key,
  fecha timestamptz not null default now(),
  total numeric(10,2) not null default 0,
  usuario text
);

create table detalle_venta (
  id bigint generated always as identity primary key,
  venta_id bigint not null references ventas(id) on delete cascade,
  producto_id bigint not null references productos(id),
  cantidad integer not null check (cantidad > 0),
  precio_unitario numeric(10,2) not null check (precio_unitario >= 0)
);

create table movimientos_inventario (
  id bigint generated always as identity primary key,
  producto_id bigint not null references productos(id),
  tipo text not null check (tipo in ('venta','compra','ajuste')),
  cantidad integer not null,
  referencia text,
  fecha timestamptz not null default now()
);

create or replace function fn_descontar_stock() returns trigger
language plpgsql as $$
begin
  update productos
     set stock_actual = stock_actual - new.cantidad
   where id = new.producto_id;
  insert into movimientos_inventario (producto_id, tipo, cantidad, referencia)
  values (new.producto_id, 'venta', -new.cantidad, 'venta:' || new.venta_id);
  return new;
end;
$$;

create trigger trg_descontar_stock
after insert on detalle_venta
for each row execute function fn_descontar_stock();

create view v_productos_bajo_minimo as
select id, codigo, nombre, stock_actual, stock_minimo, ultima_alerta
from productos
where activo and stock_actual <= stock_minimo;

create view v_lotes_por_vencer as
select p.codigo, p.nombre, l.cantidad, l.fecha_vencimiento
from lotes l join productos p on p.id = l.producto_id
where l.cantidad > 0 and l.fecha_vencimiento <= current_date + 7;

alter table productos enable row level security;
alter table lotes enable row level security;
alter table ventas enable row level security;
alter table detalle_venta enable row level security;
alter table movimientos_inventario enable row level security;
