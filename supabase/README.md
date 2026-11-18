# Databáze Totem Admin (Supabase)

Jedna databáze pro celý park: lidé, zvířata, sklad, nákupy, bar a shop, rezervace, partneři, finance a provoz.

- `migrations/20261118120000_totem_admin_schema.sql` tabulky, vazby, automatika a přístupová práva
- `migrations/20261119090000_sklad.sql` sklad: místa skladu, příjemky, převody, výdej, odpisy, inventury
- `migrations/20261119100000_pokladna_finance.sql` uzávěrka pokladny baru a shopu do financí
- `seed.sql` výchozí nastavení, ceník vstupů (ukázkové ceny), účty, druhy zvířat a expozice

## Jak to nahrát

**Přes web Supabase:** v projektu otevři SQL Editor, vlož celý soubor s migrací a spusť. Potom stejně `seed.sql`.

**Přes Supabase CLI:**

```bash
supabase link --project-ref <ref-projektu>
supabase db push
psql "$DATABASE_URL" -f supabase/seed.sql
```

Pak vytvoř termíny na pár měsíců dopředu:

```sql
select generate_slots(current_date, current_date + 90);
```

A zapni automatický úklid nezaplacených rezervací (rozšíření pg_cron v Database › Extensions):

```sql
select cron.schedule('expire-holds', '* * * * *', 'select expire_holds()');
```

## Jak to drží pohromadě

| Co se stane | Co udělá databáze sama |
|---|---|
| Někdo potvrdí příjemku (naskladnění) | navýší zásoby i se šarží a expirací, přepočítá nákupní cenu, nákup označí jako naskladněný, zapíše výdaj a při neúplné dodávce upozorní ředitele |
| Někdo potvrdí inventuru | rozdíly proti systému zapíše jako pohyby, nic se nepřepisuje |
| Ošetřovatel zapíše krmení | odečte krmivo ze skladu |
| Veterinář zapíše podání léku | odečte lék i se šarží ze skladu, zůstane v historii zvířete |
| Ana namarkuje prodej na baru | odečte zboží ze skladu a spočítá účtenku |
| Ana uzavře den (`close_register`) | spočítá tržby podle způsobu platby, zapíše příjmy do financí rozdělené na bar a shop, rozdíl v pokladně zvlášť a při rozdílu od 5 USD upozorní ředitele |
| Host zaplatí na webu | rezervace se přepne na zaplaceno, vznikne vstupenka s QR a příjem i poplatek PayPalu ve financích |
| Obsluha naskenuje QR | ověří platnost, datum a že vstupenka ještě nebyla použita |
| Kdokoliv změní peníze, sklad, léčiva nebo zvířata | zapíše se do historie změn (`audit_log`) |

## Přístupy

- **Ředitel a kancelář** (`director`, `office`) vidí a mění všechno.
- **Chov a veterina** (`head_keeper`, `keeper`, `vet`) zvířata, krmení, veterinu, šarže a incidenty.
- **Bar a vstup** (`bar`, `gate`, `guide`) pokladnu, rezervace a skener.
- **Každý** svoje směny, docházku, dovolené, úkoly, upozornění a nákupní košíky.
- **Návštěvník webu** nevidí žádnou tabulku, jen volné kapacity přes `get_availability()`.

Zaměstnanec se do adminu přihlásí účtem v Supabase Auth, který se propojí přes `staff.auth_user_id`.

## Co ještě chybí pro ostrý provoz

1. **Edge Functions pro web:** vytvořit rezervaci (`hold_booking`) a PayPal objednávku, přijmout PayPal webhook (`confirm_payment`), poslat e‑mail a WhatsApp s QR.
2. **Napojit admin a web** na tuhle databázi místo ukázkových dat v prohlížeči (`demo-store.js`).
3. **Úložiště souborů** (Supabase Storage) pro fotky účtenek, úkolů, zvířat a dokumenty.
4. **Fiskální doklady (NCF / e‑CF):** probrat s místní účetní, pole pro ně v databázi už jsou.
