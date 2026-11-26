-- =====================================================================
-- Totem Nature Park · organizační struktura a kontakty na tým
-- Podle Výstupu 04 (Organizační struktura a personální plán):
-- pozice s plánovanými počty pro fázi 1 a 2, kdo komu podléhá,
-- a u lidí kontakt (e-mail, telefon), pozice a kde působí.
-- V seznamu kontaktů jsou i lidé bez přístupu do adminu
-- (vedení Zoo Kontakt, externisté, rozšířený tým v DR a na Slovensku).
-- =====================================================================

create type staff_kind as enum ('staff', 'external', 'extended');

-- Pozice ve struktuře parku
create table positions (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  department    department not null,
  kind          staff_kind not null default 'staff',
  phase1_count  int check (phase1_count >= 0),   -- null = externě na smlouvu
  phase2_count  int check (phase2_count >= 0),
  reports_to    uuid references positions (id) on delete set null,
  description   text,
  sort          int not null default 0,
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);
comment on table positions is 'Organizační struktura: pozice, plánované počty pro fázi 1 a 2 a nadřízená pozice.';

-- Lidé: vazba na pozici a údaje pro adresář kontaktů
alter table staff add column position_id  uuid references positions (id) on delete set null;
alter table staff add column kind         staff_kind not null default 'staff';
alter table staff add column organization text;                                    -- např. Zoo Kontakt, GREENWEST
alter table staff add column base         text check (base in ('DR', 'SK', 'CZ'));  -- kde působí
alter table staff add column reports_to   uuid references staff (id) on delete set null;

-- Kontakt nemusí mít přístup do adminu: bez role se nepřihlásí (has_role vrátí false)
alter table staff alter column role drop not null;

create index on staff (position_id);
create index on staff (reports_to);

-- Práva: pozice čtou všichni přihlášení zaměstnanci, mění ředitel a kancelář
alter table positions enable row level security;
create policy positions_management on positions for all to authenticated
  using (has_role('director', 'office')) with check (has_role('director', 'office'));
create policy positions_staff_read on positions for select to authenticated
  using (current_staff_id() is not null);
