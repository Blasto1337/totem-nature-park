-- =====================================================================
-- Totem Nature Park · uzávěrka pokladny → finance
-- Bar a shop: denní uzávěrka spočítá tržby podle způsobu platby,
-- porovná je s napočítanou hotovostí a zapíše příjmy do financí
-- (rozdělené na bar a shop) včetně případného rozdílu v pokladně.
-- =====================================================================

alter table cash_closings add column expected_card_usd numeric(12,2) not null default 0;
alter table cash_closings add column diff_usd numeric(12,2) generated always as (counted_usd - expected_usd) stored;
alter table cash_closings add column diff_dop numeric(14,2) generated always as (counted_dop - expected_dop) stored;

create index on pos_sales (closing_id);

create or replace function close_register(
  p_counted_usd numeric, p_counted_dop numeric, p_note text default null, p_all_cashiers boolean default false
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := current_staff_id();
  v_closing uuid;
  v_exp_usd numeric(12,2);
  v_exp_dop numeric(14,2);
  v_card numeric(12,2);
  v_rate numeric(10,4);
  r record;
begin
  if not has_role('director', 'office', 'bar') then raise exception 'NOT_ALLOWED'; end if;
  if p_all_cashiers and not has_role('director', 'office') then raise exception 'NOT_ALLOWED'; end if;

  -- otevřené účtenky (ještě v žádné uzávěrce)
  drop table if exists _open;
  create temp table _open on commit drop as
    select s.* from pos_sales s
    where s.closing_id is null and not s.voided
      and (p_all_cashiers or s.cashier_id = v_me);

  if not exists (select 1 from _open) then raise exception 'NOTHING_TO_CLOSE'; end if;

  select coalesce(sum(total_usd) filter (where payment = 'cash_usd'), 0),
         coalesce(sum(round(total_usd * coalesce(fx_rate, 0), 2)) filter (where payment = 'cash_dop'), 0),
         coalesce(sum(total_usd) filter (where payment = 'card'), 0)
    into v_exp_usd, v_exp_dop, v_card
  from _open;

  insert into cash_closings (cashier_id, expected_usd, counted_usd, expected_dop, counted_dop, card_total_usd, expected_card_usd, note)
  values (v_me, v_exp_usd, coalesce(p_counted_usd, 0), v_exp_dop, coalesce(p_counted_dop, 0), v_card, v_card, p_note)
  returning id into v_closing;

  update pos_sales set closing_id = v_closing where id in (select id from _open);

  -- příjmy do financí: podle způsobu platby a podle toho, jestli jde o bar nebo shop
  for r in
    select o.payment,
           case when i.category = 'shop' then 'shop' else 'bar' end::finance_category as cat,
           sum(si.qty * si.unit_price) as usd,
           sum(round(si.qty * si.unit_price * coalesce(o.fx_rate, 0), 2)) as dop
    from _open o
    join pos_sale_items si on si.sale_id = o.id
    join items i on i.id = si.item_id
    group by 1, 2
  loop
    insert into transactions (account_id, direction, amount, currency, amount_usd, category, description, ref_table, ref_id, created_by)
    values (
      (select id from accounts where active and kind = case r.payment when 'card' then 'card_terminal'::account_kind else 'cash'::account_kind end
         and currency = case r.payment when 'cash_dop' then 'DOP' else 'USD' end limit 1),
      'in',
      case r.payment when 'cash_dop' then r.dop else r.usd end,
      case r.payment when 'cash_dop' then 'DOP' else 'USD' end,
      r.usd, r.cat,
      'Uzávěrka ' || to_char(current_date, 'DD. MM.') || ', ' || case r.payment when 'card' then 'karta' when 'cash_usd' then 'hotově USD' else 'hotově DOP' end,
      'cash_closings', v_closing, v_me);
  end loop;

  -- rozdíl mezi napočítanou a očekávanou hotovostí
  if coalesce(p_counted_usd, 0) <> v_exp_usd then
    insert into transactions (account_id, direction, amount, currency, amount_usd, category, description, ref_table, ref_id, created_by)
    values ((select id from accounts where active and kind = 'cash' and currency = 'USD' limit 1),
            case when p_counted_usd > v_exp_usd then 'in' else 'out' end::money_direction,
            abs(p_counted_usd - v_exp_usd), 'USD', abs(p_counted_usd - v_exp_usd),
            case when p_counted_usd > v_exp_usd then 'other_income' else 'other_expense' end::finance_category,
            'Rozdíl v pokladně USD', 'cash_closings', v_closing, v_me);
  end if;
  if coalesce(p_counted_dop, 0) <> v_exp_dop then
    select usd_dop into v_rate from exchange_rates order by rate_date desc limit 1;
    insert into transactions (account_id, direction, amount, currency, amount_usd, category, description, ref_table, ref_id, created_by)
    values ((select id from accounts where active and kind = 'cash' and currency = 'DOP' limit 1),
            case when p_counted_dop > v_exp_dop then 'in' else 'out' end::money_direction,
            abs(p_counted_dop - v_exp_dop), 'DOP', round(abs(p_counted_dop - v_exp_dop) / coalesce(nullif(v_rate, 0), 60), 2),
            case when p_counted_dop > v_exp_dop then 'other_income' else 'other_expense' end::finance_category,
            'Rozdíl v pokladně DOP', 'cash_closings', v_closing, v_me);
  end if;

  -- větší rozdíl pošle upozornění řediteli
  if abs(coalesce(p_counted_usd, 0) - v_exp_usd) >= 5 then
    insert into notifications (staff_id, title, body, link)
    select s.id, 'Rozdíl v pokladně', 'Uzávěrka má rozdíl ' || (coalesce(p_counted_usd, 0) - v_exp_usd) || ' USD.', 'pokladna/uzaverky/' || v_closing
    from staff s where s.role = 'director' and s.active;
  end if;

  return v_closing;
end $$;

revoke execute on function close_register(numeric, numeric, text, boolean) from public, anon;
grant execute on function close_register(numeric, numeric, text, boolean) to authenticated;

-- přehled uzávěrek pro finance
create view cash_closing_summary with (security_invoker = on) as
select c.id, c.closed_on, s.full_name as cashier, c.expected_usd, c.counted_usd, c.diff_usd,
       c.expected_dop, c.counted_dop, c.diff_dop, c.card_total_usd,
       (select count(*) from pos_sales p where p.closing_id = c.id) as receipts,
       (select coalesce(sum(t.amount_usd), 0) from transactions t
         where t.ref_table = 'cash_closings' and t.ref_id = c.id and t.category in ('bar', 'shop')) as revenue_usd
from cash_closings c
left join staff s on s.id = c.cashier_id;
