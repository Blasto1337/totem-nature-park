-- =====================================================================
-- Totem Nature Park · databáze pro Totem Admin a online rezervace
-- Supabase (PostgreSQL 15+). Spouští se jako jedna migrace.
--
-- Moduly:
--   1  Lidé a přístupy        staff, shifts, attendance, absences, shift_swaps
--   2  Zvířata                species, enclosures, animals, animal_movements,
--                             feeding_plans, feeding_logs, vet_records,
--                             medication_administrations
--   3  Sklad                  suppliers, items, stock_batches, stock_movements
--   4  Nákupy                 purchase_requests, purchase_request_items, purchases
--   5  Bar a shop             exchange_rates, pos_sales, pos_sale_items, cash_closings
--   6  Rezervace a vstupenky  ticket_types, time_slots, customers, bookings,
--                             booking_items, tickets, payments, refunds
--   7  Partneři               partners, partner_contacts, partner_invoices
--   8  Finance                accounts, transactions, budget_lines
--   9  Provoz                 tasks, assets, asset_services, incidents, documents
--   10 Systém                 settings, audit_log, notifications
--
-- Peníze jsou v USD (numeric 12,2), pokud není uvedeno jinak.
-- Veřejný web nesahá na tabulky přímo: rezervace jdou přes funkce
-- volané z Edge Functions (service_role), dostupnost přes get_availability().
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Výčty (enumy)
-- ---------------------------------------------------------------------
create type app_role as enum ('director', 'office', 'head_keeper', 'keeper', 'vet', 'guide', 'maintenance', 'bar', 'gate');
create type department as enum ('management', 'animals', 'vet', 'guides', 'maintenance', 'bar_shop', 'office');
create type shift_kind as enum ('morning', 'afternoon', 'full', 'off');
create type request_status as enum ('pending', 'approved', 'rejected', 'returned', 'done');

create type animal_sex as enum ('male', 'female', 'unknown');
create type animal_status as enum ('active', 'quarantine', 'deceased', 'transferred');
create type movement_kind as enum ('arrival', 'birth', 'death', 'transfer_out', 'enclosure_change', 'quarantine_in', 'quarantine_out');
create type vet_record_kind as enum ('exam', 'treatment', 'vaccination', 'deworming', 'weighing', 'surgery', 'necropsy', 'other');

create type item_category as enum ('feed', 'medicine', 'maintenance', 'bar', 'shop', 'office', 'other');
create type stock_movement_kind as enum ('receipt', 'issue', 'sale', 'feeding', 'medication', 'inventory', 'writeoff', 'return');

create type pos_payment as enum ('cash_usd', 'cash_dop', 'card');

create type booking_channel as enum ('web', 'partner', 'direct', 'walk_in');
create type booking_status as enum ('held', 'paid', 'confirmed', 'checked_in', 'cancelled', 'expired', 'no_show');
create type ticket_status as enum ('valid', 'used', 'void');
create type payment_status as enum ('created', 'captured', 'failed', 'refunded', 'partially_refunded');

create type partner_kind as enum ('agency', 'dmc', 'hotel', 'transport', 'other');
create type partner_status as enum ('prospect', 'negotiating', 'active', 'paused', 'ended');
create type invoice_status as enum ('draft', 'sent', 'paid', 'overdue', 'cancelled');

create type account_kind as enum ('cash', 'bank', 'paypal', 'card_terminal');
create type money_direction as enum ('in', 'out');
create type finance_category as enum (
  'tickets', 'bar', 'shop', 'partner_payment', 'other_income',
  'feed', 'vet', 'maintenance', 'wages', 'energy', 'transport', 'marketing', 'fees', 'taxes', 'rent', 'other_expense'
);

create type task_status as enum ('todo', 'in_progress', 'done', 'cancelled');
create type recurrence as enum ('none', 'daily', 'weekly', 'monthly');
create type incident_kind as enum ('visitor_injury', 'staff_injury', 'animal_bite', 'animal_escape', 'property_damage', 'other');

-- ---------------------------------------------------------------------
-- 1  LIDÉ A PŘÍSTUPY
-- ---------------------------------------------------------------------
create table staff (
  id            uuid primary key default gen_random_uuid(),
  auth_user_id  uuid unique references auth.users (id) on delete set null,  -- přihlášení do adminu
  full_name     text not null,
  role          app_role not null,
  department    department not null,
  phone         text,
  email         text,
  lang          text not null default 'es' check (lang in ('es', 'en', 'cs', 'sk')),
  hired_on      date,
  left_on       date,
  active        boolean not null default true,
  notes         text,
  created_at    timestamptz not null default now()
);
comment on table staff is 'Zaměstnanci. auth_user_id propojuje s přihlášením (Supabase Auth).';

create table shifts (
  id          uuid primary key default gen_random_uuid(),
  staff_id    uuid not null references staff (id) on delete cascade,
  work_date   date not null,
  kind        shift_kind not null,
  starts_at   time,
  ends_at     time,
  note        text,
  unique (staff_id, work_date)
);

create table attendance (
  id          uuid primary key default gen_random_uuid(),
  staff_id    uuid not null references staff (id) on delete cascade,
  clock_in    timestamptz not null default now(),
  clock_out   timestamptz,
  method      text not null default 'qr' check (method in ('qr', 'manual')),
  note        text
);
comment on table attendance is 'Docházka, píchání QR kódem u brány.';

create table absences (
  id          uuid primary key default gen_random_uuid(),
  staff_id    uuid not null references staff (id) on delete cascade,
  date_from   date not null,
  date_to     date not null,
  kind        text not null check (kind in ('vacation', 'sick', 'personal', 'other')),
  status      request_status not null default 'pending',
  decided_by  uuid references staff (id),
  note        text,
  check (date_to >= date_from)
);

create table shift_swaps (
  id            uuid primary key default gen_random_uuid(),
  from_staff_id uuid not null references staff (id) on delete cascade,
  to_staff_id   uuid not null references staff (id) on delete cascade,
  work_date     date not null,
  reason        text,
  status        request_status not null default 'pending',
  decided_by    uuid references staff (id),
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3  SKLAD (dřív než zvířata, krmení a léčiva se na něj odkazují)
-- ---------------------------------------------------------------------
create table suppliers (
  id        uuid primary key default gen_random_uuid(),
  name      text not null,
  rnc       text,                        -- daňové číslo v DR
  contact   text,
  phone     text,
  email     text,
  notes     text,
  active    boolean not null default true
);

create table items (
  id              uuid primary key default gen_random_uuid(),
  sku             text unique,
  name            text not null,
  category        item_category not null,
  unit            text not null,                     -- kg, ks, l, bal
  min_stock       numeric(12,3) not null default 0,  -- pod tímhle hlídá upozornění
  cost_price      numeric(12,2),                     -- orientační nákupní cena
  sale_price      numeric(12,2),                     -- jen bar a shop
  tax_rate        numeric(5,2) not null default 18,  -- ITBIS
  track_batches   boolean not null default false,    -- léčiva a krmiva s expirací
  supplier_id     uuid references suppliers (id),
  active          boolean not null default true,
  created_at      timestamptz not null default now()
);
comment on table items is 'Jeden katalog pro všechno: krmiva, léčiva, materiál údržby, bar, suvenýry.';

create table stock_batches (
  id          uuid primary key default gen_random_uuid(),
  item_id     uuid not null references items (id) on delete cascade,
  batch_no    text not null,
  expires_on  date,
  received_on date not null default current_date,
  unique (item_id, batch_no)
);

create table stock_movements (
  id          uuid primary key default gen_random_uuid(),
  item_id     uuid not null references items (id),
  batch_id    uuid references stock_batches (id),
  qty         numeric(12,3) not null check (qty <> 0),  -- + příjem, − výdej
  kind        stock_movement_kind not null,
  ref_table   text,                                     -- odkud pohyb vznikl
  ref_id      uuid,
  note        text,
  created_by  uuid references staff (id),
  created_at  timestamptz not null default now()
);
create index on stock_movements (item_id);
create index on stock_movements (ref_table, ref_id);

create view stock_levels with (security_invoker = on) as
select i.id as item_id, i.name, i.category, i.unit, i.min_stock,
       coalesce(sum(m.qty), 0) as on_hand,
       coalesce(sum(m.qty), 0) <= i.min_stock as is_low
from items i
left join stock_movements m on m.item_id = i.id
where i.active
group by i.id;
comment on view stock_levels is 'Aktuální zásoba každé položky a upozornění na nízký stav.';

create view expiring_batches with (security_invoker = on) as
select b.*, i.name as item_name, i.category,
       (select coalesce(sum(m.qty), 0) from stock_movements m where m.batch_id = b.id) as on_hand
from stock_batches b
join items i on i.id = b.item_id
where b.expires_on is not null and b.expires_on <= current_date + 60;

-- ---------------------------------------------------------------------
-- 2  ZVÍŘATA
-- ---------------------------------------------------------------------
create table species (
  id               uuid primary key default gen_random_uuid(),
  scientific_name  text not null unique,
  name_es          text not null,
  name_en          text,
  name_cs          text,
  cites_appendix   text check (cites_appendix in ('I', 'II', 'III')),
  care_manual      text,       -- odkaz na Guia de manejo
  notes            text
);

create table enclosures (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  zone       text,             -- Aviario, Vivarium, Jardín...
  capacity   int,
  notes      text,
  active     boolean not null default true
);

create table animals (
  id            uuid primary key default gen_random_uuid(),
  species_id    uuid not null references species (id),
  name          text,
  sex           animal_sex not null default 'unknown',
  birth_date    date,
  arrived_on    date,
  origin        text,          -- odkud zvíře přišlo
  microchip     text unique,
  ring          text,
  cites_doc     text,          -- číslo dokladu CITES
  enclosure_id  uuid references enclosures (id),
  status        animal_status not null default 'active',
  left_on       date,
  photo_path    text,
  notes         text,
  created_at    timestamptz not null default now()
);
create index on animals (species_id);
create index on animals (enclosure_id);

create table animal_movements (
  id                 uuid primary key default gen_random_uuid(),
  animal_id          uuid not null references animals (id) on delete cascade,
  kind               movement_kind not null,
  happened_on        date not null default current_date,
  from_enclosure_id  uuid references enclosures (id),
  to_enclosure_id    uuid references enclosures (id),
  counterparty       text,     -- odkud / kam (jiná zoo, úřad)
  document_path      text,
  note               text,
  created_by         uuid references staff (id),
  created_at         timestamptz not null default now()
);
comment on table animal_movements is 'Přírůstky, úhyny, přesuny a karanténa. Podklad pro hlášení úřadům.';

create table feeding_plans (
  id            uuid primary key default gen_random_uuid(),
  enclosure_id  uuid references enclosures (id),
  species_id    uuid references species (id),
  animal_id     uuid references animals (id),      -- individuální dávka, jinak null
  feed_time     time not null,
  item_id       uuid not null references items (id),
  qty           numeric(12,3) not null,           -- v jednotce položky
  with_guests   boolean not null default false,   -- krmení s návštěvníky
  assignee_role app_role not null default 'keeper',
  weekdays      int[] not null default '{1,2,3,4,5,6,7}',
  active        boolean not null default true,
  note          text,
  check (enclosure_id is not null or species_id is not null or animal_id is not null)
);

create table feeding_logs (
  id          uuid primary key default gen_random_uuid(),
  plan_id     uuid references feeding_plans (id),
  item_id     uuid not null references items (id),
  qty         numeric(12,3) not null,
  fed_at      timestamptz not null default now(),
  fed_by      uuid references staff (id),
  photo_path  text,
  note        text
);

create table vet_records (
  id            uuid primary key default gen_random_uuid(),
  animal_id     uuid not null references animals (id) on delete cascade,
  kind          vet_record_kind not null,
  recorded_on   date not null default current_date,
  findings      text,
  weight_kg     numeric(8,3),
  vet_id        uuid references staff (id),
  follow_up_on  date,
  resolved      boolean not null default true,
  attachment    text,
  created_at    timestamptz not null default now()
);
create index on vet_records (animal_id, recorded_on desc);

create table medication_administrations (
  id             uuid primary key default gen_random_uuid(),
  vet_record_id  uuid references vet_records (id) on delete set null,
  animal_id      uuid not null references animals (id),
  item_id        uuid not null references items (id),
  batch_id       uuid references stock_batches (id),
  dose           numeric(12,3) not null,          -- v jednotce položky
  route          text,                            -- p.o., i.m., s.c....
  given_at       timestamptz not null default now(),
  given_by       uuid references staff (id),
  note           text
);
comment on table medication_administrations is 'Každé podání léčiva konkrétnímu zvířeti, s šarží. Evidence léčiv pro úřady.';

-- ---------------------------------------------------------------------
-- 4  NÁKUPY
-- ---------------------------------------------------------------------
create table purchase_requests (
  id            uuid primary key default gen_random_uuid(),
  requested_by  uuid not null references staff (id),
  department    department not null,
  purpose       text not null,
  urgent        boolean not null default false,
  status        request_status not null default 'pending',
  decided_by    uuid references staff (id),
  decided_at    timestamptz,
  decision_note text,
  created_at    timestamptz not null default now()
);

create table purchase_request_items (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references purchase_requests (id) on delete cascade,
  item_id     uuid references items (id),
  description text,                                -- když položka není v katalogu
  qty         numeric(12,3) not null check (qty > 0),
  est_price   numeric(12,2),
  check (item_id is not null or description is not null)
);

create table purchases (
  id             uuid primary key default gen_random_uuid(),
  request_id     uuid references purchase_requests (id),
  supplier_id    uuid references suppliers (id),
  purchased_on   date not null default current_date,
  total          numeric(12,2) not null,
  currency       text not null default 'USD' check (currency in ('USD', 'DOP')),
  ncf            text,                             -- fiskální doklad dodavatele
  receipt_path   text,                             -- fotka účtenky
  bought_by      uuid references staff (id),
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5  BAR A SHOP
-- ---------------------------------------------------------------------
create table exchange_rates (
  rate_date  date primary key,
  usd_dop    numeric(10,4) not null
);

create table cash_closings (
  id             uuid primary key default gen_random_uuid(),
  closed_on      date not null default current_date,
  cashier_id     uuid not null references staff (id),
  expected_usd   numeric(12,2) not null default 0,
  counted_usd    numeric(12,2) not null default 0,
  expected_dop   numeric(14,2) not null default 0,
  counted_dop    numeric(14,2) not null default 0,
  card_total_usd numeric(12,2) not null default 0,
  note           text,
  created_at     timestamptz not null default now()
);

create table pos_sales (
  id          uuid primary key default gen_random_uuid(),
  sold_at     timestamptz not null default now(),
  cashier_id  uuid references staff (id),
  payment     pos_payment not null,
  total_usd   numeric(12,2) not null default 0,
  fx_rate     numeric(10,4),                     -- při platbě v DOP
  ncf         text,
  closing_id  uuid references cash_closings (id),
  voided      boolean not null default false
);

create table pos_sale_items (
  id          uuid primary key default gen_random_uuid(),
  sale_id     uuid not null references pos_sales (id) on delete cascade,
  item_id     uuid not null references items (id),
  qty         numeric(12,3) not null check (qty > 0),
  unit_price  numeric(12,2) not null,
  tax_rate    numeric(5,2) not null default 18
);

-- ---------------------------------------------------------------------
-- 7  PARTNEŘI (dřív než rezervace)
-- ---------------------------------------------------------------------
create table partners (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null unique,
  kind                  partner_kind not null,
  status                partner_status not null default 'prospect',
  margin_pct            numeric(5,2),             -- bez dopravy (např. 20)
  margin_transport_pct  numeric(5,2),             -- s dopravou (např. 35)
  billing_period        text check (billing_period in ('weekly', 'monthly')),
  rnc                   text,
  next_step             text,
  notes                 text,
  created_at            timestamptz not null default now()
);

create table partner_contacts (
  id          uuid primary key default gen_random_uuid(),
  partner_id  uuid not null references partners (id) on delete cascade,
  name        text not null,
  position    text,
  phone       text,
  email       text
);

create table partner_invoices (
  id            uuid primary key default gen_random_uuid(),
  partner_id    uuid not null references partners (id),
  period_from   date not null,
  period_to     date not null,
  gross_total   numeric(12,2) not null,
  net_total     numeric(12,2) not null,
  ncf           text,
  status        invoice_status not null default 'draft',
  due_on        date,
  paid_on       date,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 6  REZERVACE A VSTUPENKY
-- ---------------------------------------------------------------------
create table ticket_types (
  id          uuid primary key default gen_random_uuid(),
  code        text not null,                 -- adult, child, infant
  name_es     text not null,
  name_en     text not null,
  price       numeric(12,2) not null,
  counts_capacity boolean not null default true,
  valid_from  date,
  valid_to    date,
  active      boolean not null default true
);

create table time_slots (
  id            uuid primary key default gen_random_uuid(),
  slot_date     date not null,
  starts_at     time,                         -- null = volný vstup na celý den (fáze 2)
  capacity      int not null check (capacity >= 0),
  closed        boolean not null default false,
  close_reason  text
);
create unique index time_slots_date_time on time_slots (slot_date, coalesce(starts_at, '00:00'::time));

create table customers (
  id                 uuid primary key default gen_random_uuid(),
  full_name          text not null,
  email              text,
  phone              text,                    -- WhatsApp
  lang               text,
  hotel              text,
  country            text,
  marketing_consent  boolean not null default false,
  created_at         timestamptz not null default now()
);
create index on customers (lower(email));

create table bookings (
  id               uuid primary key default gen_random_uuid(),
  code             text not null unique,      -- TNP-XXXXXX, ukazuje se hostovi
  channel          booking_channel not null,
  status           booking_status not null default 'held',
  slot_id          uuid not null references time_slots (id),
  customer_id      uuid references customers (id),
  partner_id       uuid references partners (id),
  partner_ref      text,                      -- číslo voucheru agentury
  adults           int not null default 0 check (adults >= 0),
  children         int not null default 0 check (children >= 0),
  infants          int not null default 0 check (infants >= 0),
  transport        boolean not null default false,   -- dopravu zajišťuje partner
  gross_total      numeric(12,2) not null default 0,
  margin_pct       numeric(5,2) not null default 0,
  net_total        numeric(12,2) generated always as (round(gross_total * (1 - margin_pct / 100), 2)) stored,
  hold_expires_at  timestamptz,
  checked_in_at    timestamptz,
  checked_in_by    uuid references staff (id),
  note             text,
  created_by       uuid references staff (id),
  created_at       timestamptz not null default now(),
  check (adults + children + infants > 0),
  check (channel <> 'partner' or partner_id is not null)
);
create index on bookings (slot_id);
create index on bookings (status);

create table booking_items (
  id              uuid primary key default gen_random_uuid(),
  booking_id      uuid not null references bookings (id) on delete cascade,
  ticket_type_id  uuid not null references ticket_types (id),
  qty             int not null check (qty > 0),
  unit_price      numeric(12,2) not null
);

create table tickets (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references bookings (id) on delete cascade,
  qr_token    text not null unique default encode(gen_random_bytes(18), 'base64'),  -- dlouhý náhodný token v QR
  status      ticket_status not null default 'valid',
  used_at     timestamptz,
  used_by     uuid references staff (id)
);
comment on table tickets is 'Jedna vstupenka (jeden QR) na celou skupinu z rezervace.';

create table payments (
  id                   uuid primary key default gen_random_uuid(),
  booking_id           uuid references bookings (id),
  provider             text not null default 'paypal',
  provider_order_id    text unique,
  provider_capture_id  text unique,
  amount               numeric(12,2) not null,
  fee                  numeric(12,2) not null default 0,
  currency             text not null default 'USD',
  status               payment_status not null default 'created',
  raw                  jsonb,                 -- celá odpověď / webhook od PayPalu
  created_at           timestamptz not null default now()
);

create table refunds (
  id                  uuid primary key default gen_random_uuid(),
  payment_id          uuid not null references payments (id),
  amount              numeric(12,2) not null check (amount > 0),
  reason              text,
  provider_refund_id  text unique,
  created_by          uuid references staff (id),
  created_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 8  FINANCE
-- ---------------------------------------------------------------------
create table accounts (
  id        uuid primary key default gen_random_uuid(),
  name      text not null unique,
  kind      account_kind not null,
  currency  text not null default 'USD' check (currency in ('USD', 'DOP')),
  active    boolean not null default true
);

create table transactions (
  id           uuid primary key default gen_random_uuid(),
  tx_date      date not null default current_date,
  account_id   uuid references accounts (id),
  direction    money_direction not null,
  amount       numeric(14,2) not null check (amount > 0),
  currency     text not null default 'USD' check (currency in ('USD', 'DOP')),
  amount_usd   numeric(12,2) not null,           -- přepočet pro reporty
  category     finance_category not null,
  description  text,
  ncf          text,
  ref_table    text,                             -- purchases, payments, pos_sales, partner_invoices...
  ref_id       uuid,
  created_by   uuid references staff (id),
  created_at   timestamptz not null default now()
);
create index on transactions (tx_date);
create index on transactions (ref_table, ref_id);

create table budget_lines (
  id          uuid primary key default gen_random_uuid(),
  month       date not null check (extract(day from month) = 1),
  category    finance_category not null,
  planned     numeric(12,2) not null,
  unique (month, category)
);

-- ---------------------------------------------------------------------
-- 9  PROVOZ
-- ---------------------------------------------------------------------
create table tasks (
  id              uuid primary key default gen_random_uuid(),
  title           text not null,
  description     text,
  assignee_id     uuid references staff (id),
  due_on          date,
  status          task_status not null default 'todo',
  priority        boolean not null default false,
  recurrence      recurrence not null default 'none',
  requires_photo  boolean not null default false,
  photo_path      text,
  enclosure_id    uuid references enclosures (id),
  completed_at    timestamptz,
  created_by      uuid references staff (id),
  created_at      timestamptz not null default now()
);
create index on tasks (assignee_id, status);

create table assets (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  kind             text,             -- vozidlo, elektrocentrála, UV lampa, čerpadlo...
  location         text,
  serial_no        text,
  purchased_on     date,
  next_service_on  date,
  notes            text,
  active           boolean not null default true
);

create table asset_services (
  id          uuid primary key default gen_random_uuid(),
  asset_id    uuid not null references assets (id) on delete cascade,
  serviced_on date not null default current_date,
  description text not null,
  cost        numeric(12,2),
  done_by     text
);

create table incidents (
  id            uuid primary key default gen_random_uuid(),
  occurred_at   timestamptz not null,
  kind          incident_kind not null,
  location      text,
  animal_id     uuid references animals (id),
  description   text not null,
  people        text,
  actions_taken text,
  insurance_ref text,
  reported_by   uuid references staff (id),
  created_at    timestamptz not null default now()
);

create table documents (
  id                  uuid primary key default gen_random_uuid(),
  title               text not null,
  kind                text,            -- povolení, licence, smlouva, pojistka...
  entity_table        text,            -- ke kterému záznamu patří (animals, partners...)
  entity_id           uuid,
  file_path           text,            -- Supabase Storage
  issued_on           date,
  expires_on          date,
  remind_days_before  int not null default 30,
  created_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 10  SYSTÉM
-- ---------------------------------------------------------------------
create table settings (
  key    text primary key,
  value  jsonb not null
);

create table audit_log (
  id          bigint generated always as identity primary key,
  table_name  text not null,
  row_id      uuid,
  action      text not null,
  old_row     jsonb,
  new_row     jsonb,
  changed_by  uuid default auth.uid(),
  changed_at  timestamptz not null default now()
);

create table notifications (
  id          uuid primary key default gen_random_uuid(),
  staff_id    uuid not null references staff (id) on delete cascade,
  title       text not null,
  body        text,
  link        text,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

-- =====================================================================
-- FUNKCE A AUTOMATIKA
-- =====================================================================

-- Kdo je přihlášený a jakou má roli
create or replace function current_staff_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from staff where auth_user_id = auth.uid() and active
$$;

create or replace function has_role(variadic roles app_role[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from staff where auth_user_id = auth.uid() and active and role = any (roles))
$$;

-- Historie změn u citlivých tabulek
create or replace function audit_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into audit_log (table_name, row_id, action, old_row, new_row)
  values (tg_table_name,
          coalesce((case when tg_op = 'DELETE' then old.id else new.id end), null),
          tg_op,
          case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
          case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end);
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array['bookings', 'tickets', 'payments', 'refunds', 'stock_movements', 'medication_administrations',
                           'transactions', 'purchases', 'purchase_requests', 'pos_sales', 'cash_closings', 'animals', 'animal_movements']
  loop
    execute format('create trigger %I after insert or update or delete on %I for each row execute function audit_trigger()', t || '_audit', t);
  end loop;
end $$;

-- Krmení, léčiva a prodej se samy odečtou ze skladu
create or replace function stock_from_feeding() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into stock_movements (item_id, qty, kind, ref_table, ref_id, created_by)
  values (new.item_id, -new.qty, 'feeding', 'feeding_logs', new.id, new.fed_by);
  return new;
end $$;
create trigger feeding_logs_stock after insert on feeding_logs for each row execute function stock_from_feeding();

create or replace function stock_from_medication() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into stock_movements (item_id, batch_id, qty, kind, ref_table, ref_id, created_by)
  values (new.item_id, new.batch_id, -new.dose, 'medication', 'medication_administrations', new.id, new.given_by);
  return new;
end $$;
create trigger medication_stock after insert on medication_administrations for each row execute function stock_from_medication();

create or replace function stock_from_sale() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into stock_movements (item_id, qty, kind, ref_table, ref_id)
  values (new.item_id, -new.qty, 'sale', 'pos_sale_items', new.id);
  update pos_sales set total_usd = (select coalesce(sum(qty * unit_price), 0) from pos_sale_items where sale_id = new.sale_id)
  where id = new.sale_id;
  return new;
end $$;
create trigger pos_sale_items_stock after insert on pos_sale_items for each row execute function stock_from_sale();

-- Kapacita: kolik míst je obsazeno (podržené, zaplacené, potvrzené, odbavené)
create or replace function slot_booked(p_slot uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(adults + children + infants), 0)::int
  from bookings
  where slot_id = p_slot
    and (status in ('paid', 'confirmed', 'checked_in')
         or (status = 'held' and hold_expires_at > now()))
$$;

-- Veřejná dostupnost pro web (jediné, co anonymní návštěvník smí číst)
create or replace function get_availability(p_from date, p_to date)
returns table (slot_id uuid, slot_date date, starts_at time, capacity int, booked int, available int, closed boolean)
language sql stable security definer set search_path = public as $$
  select s.id, s.slot_date, s.starts_at, s.capacity, slot_booked(s.id),
         case when s.closed then 0 else greatest(s.capacity - slot_booked(s.id), 0) end,
         s.closed
  from time_slots s
  where s.slot_date between p_from and least(p_to, p_from + 62)
  order by s.slot_date, s.starts_at nulls first
$$;

create or replace function new_booking_code() returns text
language plpgsql as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text;
begin
  loop
    c := 'TNP-';
    for i in 1..6 loop
      c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from bookings where code = c);
  end loop;
  return c;
end $$;

-- Web: podrží místa na 15 minut (volá Edge Function před vytvořením PayPal objednávky)
create or replace function hold_booking(
  p_slot uuid, p_adults int, p_children int, p_infants int,
  p_name text, p_email text, p_phone text, p_lang text default 'es', p_hotel text default null
) returns table (booking_id uuid, code text, total numeric, hold_expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  s time_slots;
  v_customer uuid;
  v_booking uuid;
  v_code text;
  v_total numeric(12,2) := 0;
  v_minutes int := coalesce((select (value)::text::int from settings where key = 'hold_minutes'), 15);
  t record;
begin
  select * into s from time_slots where id = p_slot for update;   -- zámek proti přeprodání
  if not found or s.closed then raise exception 'SLOT_UNAVAILABLE'; end if;
  if p_adults + p_children + p_infants <= 0 then raise exception 'NO_GUESTS'; end if;
  if slot_booked(p_slot) + p_adults + p_children + p_infants > s.capacity then raise exception 'SLOT_FULL'; end if;

  insert into customers (full_name, email, phone, lang, hotel)
  values (p_name, p_email, p_phone, p_lang, p_hotel) returning id into v_customer;

  v_code := new_booking_code();
  insert into bookings (code, channel, status, slot_id, customer_id, adults, children, infants, hold_expires_at)
  values (v_code, 'web', 'held', p_slot, v_customer, p_adults, p_children, p_infants, now() + make_interval(mins => v_minutes))
  returning id into v_booking;

  for t in
    select tt.id, tt.code, tt.price from ticket_types tt
    where tt.active and tt.code in ('adult', 'child', 'infant')
      and (tt.valid_from is null or tt.valid_from <= s.slot_date)
      and (tt.valid_to is null or tt.valid_to >= s.slot_date)
  loop
    if t.code = 'adult' and p_adults > 0 then
      insert into booking_items (booking_id, ticket_type_id, qty, unit_price) values (v_booking, t.id, p_adults, t.price);
      v_total := v_total + p_adults * t.price;
    elsif t.code = 'child' and p_children > 0 then
      insert into booking_items (booking_id, ticket_type_id, qty, unit_price) values (v_booking, t.id, p_children, t.price);
      v_total := v_total + p_children * t.price;
    elsif t.code = 'infant' and p_infants > 0 then
      insert into booking_items (booking_id, ticket_type_id, qty, unit_price) values (v_booking, t.id, p_infants, t.price);
      v_total := v_total + p_infants * t.price;
    end if;
  end loop;

  update bookings set gross_total = v_total where id = v_booking;
  return query select v_booking, v_code, v_total, now() + make_interval(mins => v_minutes);
end $$;

-- PayPal webhook: platba prošla → rezervace zaplacená, vznikne vstupenka a příjem ve financích
create or replace function confirm_payment(
  p_code text, p_order_id text, p_capture_id text, p_amount numeric, p_fee numeric, p_raw jsonb default null
) returns table (booking_id uuid, qr_token text)
language plpgsql security definer set search_path = public as $$
declare
  b bookings;
  v_token text;
  v_account uuid;
begin
  select * into b from bookings where code = p_code for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;

  -- webhook může přijít víckrát, podruhé jen vrátíme existující vstupenku
  if b.status in ('paid', 'confirmed', 'checked_in') then
    return query select b.id, t.qr_token from tickets t where t.booking_id = b.id limit 1;
    return;
  end if;
  if p_amount < b.gross_total then raise exception 'AMOUNT_MISMATCH'; end if;
  -- prošlé podržení: platba přišla pozdě, ale pokud je místo, přijmeme ji
  if b.status = 'expired' or (b.status = 'held' and b.hold_expires_at < now()) then
    if (select slot_booked(b.slot_id)) + b.adults + b.children + b.infants > (select capacity from time_slots where id = b.slot_id) then
      raise exception 'SLOT_FULL_AFTER_EXPIRY';   -- Edge Function musí platbu vrátit
    end if;
  end if;

  insert into payments (booking_id, provider_order_id, provider_capture_id, amount, fee, status, raw)
  values (b.id, p_order_id, p_capture_id, p_amount, coalesce(p_fee, 0), 'captured', p_raw);

  update bookings set status = 'paid', hold_expires_at = null where id = b.id;
  insert into tickets (booking_id) values (b.id) returning tickets.qr_token into v_token;

  select id into v_account from accounts where kind = 'paypal' and active limit 1;
  insert into transactions (account_id, direction, amount, amount_usd, category, description, ref_table, ref_id)
  values (v_account, 'in', p_amount, p_amount, 'tickets', 'Online vstupenky ' || b.code, 'bookings', b.id);
  if coalesce(p_fee, 0) > 0 then
    insert into transactions (account_id, direction, amount, amount_usd, category, description, ref_table, ref_id)
    values (v_account, 'out', p_fee, p_fee, 'fees', 'Poplatek PayPal ' || b.code, 'bookings', b.id);
  end if;

  return query select b.id, v_token;
end $$;

-- Skener u vstupu: ověří QR a pustí skupinu dovnitř
create or replace function check_in(p_token text)
returns table (result text, booking_code text, guests int, slot_date date, starts_at time, customer text)
language plpgsql security definer set search_path = public as $$
declare
  t tickets;
  b bookings;
  s time_slots;
begin
  if not has_role('director', 'office', 'gate', 'guide', 'bar') then raise exception 'NOT_ALLOWED'; end if;

  select * into t from tickets where qr_token = p_token for update;
  if not found then return query select 'unknown'::text, null::text, null::int, null::date, null::time, null::text; return; end if;
  select * into b from bookings where id = t.booking_id;
  select * into s from time_slots where id = b.slot_id;

  if t.status = 'used' then
    return query select 'already_used', b.code, b.adults + b.children + b.infants, s.slot_date, s.starts_at, (select full_name from customers where id = b.customer_id);
    return;
  end if;
  if t.status = 'void' or b.status in ('cancelled', 'expired') then
    return query select 'void', b.code, b.adults + b.children + b.infants, s.slot_date, s.starts_at, (select full_name from customers where id = b.customer_id);
    return;
  end if;
  if s.slot_date <> (now() at time zone 'America/Santo_Domingo')::date then
    return query select 'wrong_date', b.code, b.adults + b.children + b.infants, s.slot_date, s.starts_at, (select full_name from customers where id = b.customer_id);
    return;
  end if;

  update tickets set status = 'used', used_at = now(), used_by = current_staff_id() where id = t.id;
  update bookings set status = 'checked_in', checked_in_at = now(), checked_in_by = current_staff_id() where id = b.id;
  return query select 'ok', b.code, b.adults + b.children + b.infants, s.slot_date, s.starts_at, (select full_name from customers where id = b.customer_id);
end $$;

-- Úklid: prošlá podržení (spouštět každou minutu přes pg_cron, viz README)
create or replace function expire_holds() returns int
language sql security definer set search_path = public as $$
  with x as (
    update bookings set status = 'expired'
    where status = 'held' and hold_expires_at < now()
    returning 1
  ) select count(*)::int from x
$$;

-- Vytvoří termíny na zadané období podle nastavení (pevné okruhy nebo volný vstup)
create or replace function generate_slots(p_from date, p_to date) returns int
language plpgsql security definer set search_path = public as $$
declare
  v_mode text := coalesce((select value #>> '{}' from settings where key = 'ticket_mode'), 'slot');
  v_cap int := coalesce((select (value)::text::int from settings where key = 'slot_capacity'), 40);
  v_times jsonb := coalesce((select value from settings where key = 'slot_times'), '["09:30","13:00"]'::jsonb);
  v_day_cap int := coalesce((select (value)::text::int from settings where key = 'day_capacity'), 80);
  d date;
  tm text;
  n int := 0;
begin
  for d in select generate_series(p_from, p_to, interval '1 day')::date loop
    if v_mode = 'free' then
      insert into time_slots (slot_date, starts_at, capacity) values (d, null, v_day_cap) on conflict do nothing;
      n := n + 1;
    else
      for tm in select jsonb_array_elements_text(v_times) loop
        insert into time_slots (slot_date, starts_at, capacity) values (d, tm::time, v_cap) on conflict do nothing;
        n := n + 1;
      end loop;
    end if;
  end loop;
  return n;
end $$;

-- Funkce pro web volá jen server (Edge Functions se service_role), dostupnost smí číst každý
revoke execute on function hold_booking(uuid, int, int, int, text, text, text, text, text) from public, anon, authenticated;
revoke execute on function confirm_payment(text, text, text, numeric, numeric, jsonb) from public, anon, authenticated;
revoke execute on function expire_holds() from public, anon, authenticated;
revoke execute on function generate_slots(date, date) from public, anon;
revoke execute on function check_in(text) from public, anon;
grant execute on function get_availability(date, date) to anon, authenticated;
grant execute on function check_in(text) to authenticated;
grant execute on function generate_slots(date, date) to authenticated;
grant execute on function hold_booking(uuid, int, int, int, text, text, text, text, text) to service_role;
grant execute on function confirm_payment(text, text, text, numeric, numeric, jsonb) to service_role;
grant execute on function expire_holds() to service_role;

-- =====================================================================
-- PŘÍSTUPOVÁ PRÁVA (Row Level Security)
-- Ředitel a kancelář vidí a mění všechno. Ostatní podle oddělení.
-- Anonymní návštěvník webu nevidí žádnou tabulku.
-- =====================================================================
do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy %I on %I for all to authenticated using (has_role(''director'', ''office'')) with check (has_role(''director'', ''office''))', t || '_management', t);
  end loop;
end $$;

-- čtení pro všechny přihlášené zaměstnance (provozní přehledy)
do $$
declare t text;
begin
  foreach t in array array['staff', 'shifts', 'species', 'enclosures', 'animals', 'feeding_plans', 'items', 'tasks',
                           'ticket_types', 'time_slots', 'settings', 'exchange_rates', 'assets', 'suppliers']
  loop
    execute format('create policy %I on %I for select to authenticated using (current_staff_id() is not null)', t || '_staff_read', t);
  end loop;
end $$;

-- chov a veterina
do $$
declare t text;
begin
  foreach t in array array['animals', 'animal_movements', 'feeding_logs', 'vet_records', 'medication_administrations', 'feeding_plans', 'stock_batches', 'incidents']
  loop
    execute format('create policy %I on %I for all to authenticated using (has_role(''head_keeper'', ''keeper'', ''vet'')) with check (has_role(''head_keeper'', ''keeper'', ''vet''))', t || '_animals_team', t);
  end loop;
end $$;

-- sklad: pohyby a stav vidí chov, veterina, údržba a bar
create policy stock_movements_teams on stock_movements for all to authenticated
  using (has_role('head_keeper', 'keeper', 'vet', 'maintenance', 'bar'))
  with check (has_role('head_keeper', 'keeper', 'vet', 'maintenance', 'bar'));

-- bar, shop a vstup
do $$
declare t text;
begin
  foreach t in array array['pos_sales', 'pos_sale_items', 'cash_closings']
  loop
    execute format('create policy %I on %I for all to authenticated using (has_role(''bar'')) with check (has_role(''bar''))', t || '_bar', t);
  end loop;
end $$;
create policy bookings_front on bookings for select to authenticated using (has_role('gate', 'guide', 'bar'));
create policy tickets_front on tickets for select to authenticated using (has_role('gate', 'guide', 'bar'));
create policy customers_front on customers for select to authenticated using (has_role('gate', 'guide', 'bar'));

-- vlastní věci každého zaměstnance
create policy shifts_own on shifts for select to authenticated using (staff_id = current_staff_id());
create policy attendance_own on attendance for all to authenticated
  using (staff_id = current_staff_id()) with check (staff_id = current_staff_id());
create policy absences_own on absences for all to authenticated
  using (staff_id = current_staff_id()) with check (staff_id = current_staff_id() and status = 'pending');
create policy swaps_own on shift_swaps for all to authenticated
  using (from_staff_id = current_staff_id() or to_staff_id = current_staff_id())
  with check (from_staff_id = current_staff_id() and status = 'pending');
create policy tasks_assignee_update on tasks for update to authenticated
  using (assignee_id = current_staff_id()) with check (assignee_id = current_staff_id());
create policy notifications_own on notifications for all to authenticated
  using (staff_id = current_staff_id()) with check (staff_id = current_staff_id());

-- nákupní košíky: každý zakládá a vidí své, vedoucí chovu vidí oddělení chovu
create policy purchase_requests_own on purchase_requests for all to authenticated
  using (requested_by = current_staff_id() or (has_role('head_keeper') and department = 'animals'))
  with check (requested_by = current_staff_id() and status = 'pending');
create policy purchase_request_items_own on purchase_request_items for all to authenticated
  using (exists (select 1 from purchase_requests r where r.id = request_id
                 and (r.requested_by = current_staff_id() or (has_role('head_keeper') and r.department = 'animals'))))
  with check (exists (select 1 from purchase_requests r where r.id = request_id
                      and r.requested_by = current_staff_id() and r.status = 'pending'));
