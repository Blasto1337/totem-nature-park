-- =====================================================================
-- Totem Nature Park · rozšíření skladu
-- Místa skladu, příjemky (naskladnění), převody, výdej, odpisy a inventury.
--
-- Základní pravidlo: stav skladu se nikdy nepřepisuje. Je to vždy součet
-- pohybů (stock_movements). Příjemka i inventura se nejdřív připraví jako
-- koncept a teprve potvrzení vytvoří pohyby.
-- =====================================================================

alter type stock_movement_kind add value if not exists 'transfer';
alter type request_status add value if not exists 'received';   -- košík → schváleno → koupeno → naskladněno

-- ---------------------------------------------------------------------
-- Místa skladu
-- ---------------------------------------------------------------------
create table stock_locations (
  id      uuid primary key default gen_random_uuid(),
  name    text not null unique,
  kind    text check (kind in ('feed', 'vet', 'bar', 'maintenance', 'general')),
  active  boolean not null default true
);
comment on table stock_locations is 'Krmivárna, veterinární lékárna, bar a shop, sklad údržby...';

alter table items add column default_location_id uuid references stock_locations (id);
alter table items add column daily_use numeric(12,3);   -- průměrná denní spotřeba (krmiva), pro výpočet „vystačí na X dní“

alter table stock_movements add column location_id uuid references stock_locations (id);
create index on stock_movements (location_id);

alter table purchases add column received_at timestamptz;

-- ---------------------------------------------------------------------
-- Příjemky (naskladnění)
-- ---------------------------------------------------------------------
create table stock_receipts (
  id                  uuid primary key default gen_random_uuid(),
  purchase_request_id uuid references purchase_requests (id),
  purchase_id         uuid references purchases (id),
  supplier_id         uuid references suppliers (id),
  received_on         date not null default current_date,
  received_by         uuid references staff (id),
  delivery_note_path  text,                 -- foto dodacího listu nebo účtenky
  note                text,
  status              text not null default 'draft' check (status in ('draft', 'confirmed', 'cancelled')),
  confirmed_at        timestamptz,
  created_at          timestamptz not null default now()
);

create table stock_receipt_items (
  id           uuid primary key default gen_random_uuid(),
  receipt_id   uuid not null references stock_receipts (id) on delete cascade,
  item_id      uuid not null references items (id),
  location_id  uuid references stock_locations (id),   -- prázdné = výchozí místo položky
  ordered_qty  numeric(12,3),                          -- kolik bylo v košíku
  qty          numeric(12,3) not null check (qty > 0), -- kolik skutečně přišlo
  unit_price   numeric(12,2),
  batch_no     text,
  expires_on   date
);

-- ---------------------------------------------------------------------
-- Inventury
-- ---------------------------------------------------------------------
create table inventory_counts (
  id            uuid primary key default gen_random_uuid(),
  location_id   uuid not null references stock_locations (id),
  counted_on    date not null default current_date,
  counted_by    uuid references staff (id),
  status        text not null default 'draft' check (status in ('draft', 'confirmed')),
  note          text,
  confirmed_at  timestamptz
);

create table inventory_count_items (
  id           uuid primary key default gen_random_uuid(),
  count_id     uuid not null references inventory_counts (id) on delete cascade,
  item_id      uuid not null references items (id),
  system_qty   numeric(12,3),          -- doplní se při potvrzení
  counted_qty  numeric(12,3) not null check (counted_qty >= 0),
  note         text,
  unique (count_id, item_id)
);

-- ---------------------------------------------------------------------
-- Stav skladu po místech (nahrazuje původní pohled)
-- ---------------------------------------------------------------------
drop view if exists stock_levels;

create view stock_levels with (security_invoker = on) as
select m.item_id, i.name, i.category, i.unit, m.location_id, l.name as location,
       sum(m.qty) as on_hand
from stock_movements m
join items i on i.id = m.item_id
left join stock_locations l on l.id = m.location_id
group by m.item_id, i.name, i.category, i.unit, m.location_id, l.name
having sum(m.qty) <> 0;
comment on view stock_levels is 'Zásoba každé položky na každém místě skladu.';

create view stock_totals with (security_invoker = on) as
select i.id as item_id, i.name, i.category, i.unit, i.min_stock, i.cost_price, i.daily_use,
       coalesce(sum(m.qty), 0) as on_hand,
       coalesce(sum(m.qty), 0) <= i.min_stock as is_low,
       round(coalesce(sum(m.qty), 0) * coalesce(i.cost_price, 0), 2) as stock_value,
       case when i.daily_use > 0 then floor(coalesce(sum(m.qty), 0) / i.daily_use) end as days_left
from items i
left join stock_movements m on m.item_id = i.id
where i.active
group by i.id;
comment on view stock_totals is 'Celková zásoba, upozornění na nízký stav, hodnota skladu a na kolik dní krmivo vystačí.';

-- pohyby bez místa (krmení, prodej) se berou z výchozího místa položky
create or replace function stock_default_location() returns trigger
language plpgsql as $$
begin
  if new.location_id is null then
    select default_location_id into new.location_id from items where id = new.item_id;
  end if;
  return new;
end $$;
create trigger stock_movements_location before insert on stock_movements
for each row execute function stock_default_location();

-- ---------------------------------------------------------------------
-- Potvrzení příjemky: pohyby, šarže, nákupní cena, stav nákupu, výdaj
-- ---------------------------------------------------------------------
create or replace function confirm_receipt(p_receipt uuid) returns int
language plpgsql security definer set search_path = public as $$
declare
  r stock_receipts;
  l stock_receipt_items;
  v_batch uuid;
  v_on_hand numeric;
  v_total numeric(12,2) := 0;
  v_lines int := 0;
  v_short int := 0;
  v_account uuid;
begin
  if not has_role('director', 'office', 'head_keeper', 'keeper', 'vet', 'maintenance', 'bar') then
    raise exception 'NOT_ALLOWED';
  end if;

  select * into r from stock_receipts where id = p_receipt for update;
  if not found then raise exception 'RECEIPT_NOT_FOUND'; end if;
  if r.status <> 'draft' then raise exception 'RECEIPT_ALREADY_%', upper(r.status); end if;

  for l in select * from stock_receipt_items where receipt_id = p_receipt loop
    v_batch := null;
    if l.batch_no is not null then
      insert into stock_batches (item_id, batch_no, expires_on, received_on)
      values (l.item_id, l.batch_no, l.expires_on, r.received_on)
      on conflict (item_id, batch_no) do update set expires_on = coalesce(excluded.expires_on, stock_batches.expires_on)
      returning id into v_batch;
    end if;

    -- vážený průměr nákupní ceny
    if l.unit_price is not null then
      select coalesce(sum(qty), 0) into v_on_hand from stock_movements where item_id = l.item_id;
      update items set cost_price = case
        when cost_price is null or v_on_hand <= 0 then l.unit_price
        else round((cost_price * v_on_hand + l.unit_price * l.qty) / (v_on_hand + l.qty), 2) end
      where id = l.item_id;
      v_total := v_total + l.unit_price * l.qty;
    end if;

    insert into stock_movements (item_id, batch_id, location_id, qty, kind, ref_table, ref_id, created_by, note)
    values (l.item_id, v_batch, l.location_id, l.qty, 'receipt', 'stock_receipts', r.id, coalesce(r.received_by, current_staff_id()), r.note);

    if l.ordered_qty is not null and l.qty < l.ordered_qty then v_short := v_short + 1; end if;
    v_lines := v_lines + 1;
  end loop;

  if v_lines = 0 then raise exception 'RECEIPT_EMPTY'; end if;

  update stock_receipts set status = 'confirmed', confirmed_at = now() where id = r.id;
  if r.purchase_request_id is not null then
    update purchase_requests set status = 'received' where id = r.purchase_request_id;
  end if;
  if r.purchase_id is not null then
    update purchases set received_at = now() where id = r.purchase_id;
  end if;

  -- výdaj do financí, jen když ho už nezapsal nákup
  if v_total > 0 and not exists (
       select 1 from transactions
       where (ref_table = 'purchases' and ref_id = r.purchase_id)
          or (ref_table = 'stock_receipts' and ref_id = r.id)) then
    select id into v_account from accounts where kind = 'cash' and currency = 'USD' and active limit 1;
    insert into transactions (account_id, direction, amount, amount_usd, category, description, ref_table, ref_id, created_by)
    values (v_account, 'out', v_total, v_total,
            coalesce((select case i.category when 'feed' then 'feed' when 'medicine' then 'vet'
                                              when 'maintenance' then 'maintenance' else 'other_expense' end::finance_category
                      from stock_receipt_items x join items i on i.id = x.item_id
                      where x.receipt_id = r.id limit 1), 'other_expense'),
            'Naskladnění ' || to_char(r.received_on, 'DD. MM.'), 'stock_receipts', r.id, current_staff_id());
  end if;

  -- upozornění řediteli, když dorazilo míň, než se objednalo
  if v_short > 0 then
    insert into notifications (staff_id, title, body, link)
    select s.id, 'Neúplná dodávka', v_short || ' položek dorazilo v menším množství, než bylo objednáno.', 'sklad/prijemky/' || r.id
    from staff s where s.role = 'director' and s.active;
  end if;

  return v_lines;
end $$;

-- ---------------------------------------------------------------------
-- Výdej, odpis a převod mezi místy
-- ---------------------------------------------------------------------
create or replace function issue_stock(
  p_item uuid, p_qty numeric, p_location uuid, p_kind stock_movement_kind default 'issue',
  p_note text default null, p_task uuid default null, p_batch uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not has_role('director', 'office', 'head_keeper', 'keeper', 'vet', 'maintenance', 'bar') then raise exception 'NOT_ALLOWED'; end if;
  if p_kind not in ('issue', 'writeoff') then raise exception 'BAD_KIND'; end if;
  if p_qty <= 0 then raise exception 'BAD_QTY'; end if;
  insert into stock_movements (item_id, batch_id, location_id, qty, kind, ref_table, ref_id, note, created_by)
  values (p_item, p_batch, p_location, -p_qty, p_kind, case when p_task is not null then 'tasks' end, p_task, p_note, current_staff_id())
  returning id into v_id;
  return v_id;
end $$;

create or replace function transfer_stock(p_item uuid, p_qty numeric, p_from uuid, p_to uuid, p_note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare v_avail numeric;
begin
  if not has_role('director', 'office', 'head_keeper', 'keeper', 'vet', 'maintenance', 'bar') then raise exception 'NOT_ALLOWED'; end if;
  if p_qty <= 0 or p_from = p_to then raise exception 'BAD_TRANSFER'; end if;
  select coalesce(sum(qty), 0) into v_avail from stock_movements where item_id = p_item and location_id = p_from;
  if v_avail < p_qty then raise exception 'NOT_ENOUGH_STOCK'; end if;
  insert into stock_movements (item_id, location_id, qty, kind, note, created_by)
  values (p_item, p_from, -p_qty, 'transfer', p_note, current_staff_id()),
         (p_item, p_to,    p_qty, 'transfer', p_note, current_staff_id());
end $$;

-- ---------------------------------------------------------------------
-- Potvrzení inventury: rozdíly se zapíšou jako pohyby
-- ---------------------------------------------------------------------
create or replace function confirm_inventory(p_count uuid) returns int
language plpgsql security definer set search_path = public as $$
declare
  c inventory_counts;
  l inventory_count_items;
  v_sys numeric;
  v_diffs int := 0;
begin
  if not has_role('director', 'office', 'head_keeper', 'keeper', 'vet', 'maintenance', 'bar') then raise exception 'NOT_ALLOWED'; end if;
  select * into c from inventory_counts where id = p_count for update;
  if not found or c.status <> 'draft' then raise exception 'COUNT_NOT_DRAFT'; end if;

  for l in select * from inventory_count_items where count_id = p_count loop
    select coalesce(sum(qty), 0) into v_sys from stock_movements where item_id = l.item_id and location_id = c.location_id;
    update inventory_count_items set system_qty = v_sys where id = l.id;
    if l.counted_qty <> v_sys then
      insert into stock_movements (item_id, location_id, qty, kind, ref_table, ref_id, note, created_by)
      values (l.item_id, c.location_id, l.counted_qty - v_sys, 'inventory', 'inventory_counts', c.id, l.note, coalesce(c.counted_by, current_staff_id()));
      v_diffs := v_diffs + 1;
    end if;
  end loop;

  update inventory_counts set status = 'confirmed', confirmed_at = now() where id = c.id;
  return v_diffs;
end $$;

revoke execute on function confirm_receipt(uuid) from public, anon;
revoke execute on function issue_stock(uuid, numeric, uuid, stock_movement_kind, text, uuid, uuid) from public, anon;
revoke execute on function transfer_stock(uuid, numeric, uuid, uuid, text) from public, anon;
revoke execute on function confirm_inventory(uuid) from public, anon;
grant execute on function confirm_receipt(uuid) to authenticated;
grant execute on function issue_stock(uuid, numeric, uuid, stock_movement_kind, text, uuid, uuid) to authenticated;
grant execute on function transfer_stock(uuid, numeric, uuid, uuid, text) to authenticated;
grant execute on function confirm_inventory(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Historie změn a přístupová práva pro nové tabulky
-- ---------------------------------------------------------------------
create trigger stock_receipts_audit after insert or update or delete on stock_receipts for each row execute function audit_trigger();
create trigger inventory_counts_audit after insert or update or delete on inventory_counts for each row execute function audit_trigger();

do $$
declare t text;
begin
  foreach t in array array['stock_locations', 'stock_receipts', 'stock_receipt_items', 'inventory_counts', 'inventory_count_items'] loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy %I on %I for all to authenticated using (has_role(''director'', ''office'')) with check (has_role(''director'', ''office''))', t || '_management', t);
  end loop;
  foreach t in array array['stock_receipts', 'stock_receipt_items', 'inventory_counts', 'inventory_count_items'] loop
    execute format('create policy %I on %I for all to authenticated using (has_role(''head_keeper'', ''keeper'', ''vet'', ''maintenance'', ''bar'')) with check (has_role(''head_keeper'', ''keeper'', ''vet'', ''maintenance'', ''bar''))', t || '_teams', t);
  end loop;
end $$;
create policy stock_locations_staff_read on stock_locations for select to authenticated using (current_staff_id() is not null);
