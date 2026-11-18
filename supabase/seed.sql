-- =====================================================================
-- Totem Nature Park · výchozí data (číselníky a nastavení)
-- Žádná osobní data. Zaměstnance, partnery a zvířata zadáte v adminu.
-- =====================================================================

-- Nastavení provozu
insert into settings (key, value) values
  ('ticket_mode',   '"slot"'),              -- "slot" = pevné okruhy (fáze 1), "free" = volný vstup (fáze 2)
  ('slot_times',    '["09:30", "13:00"]'),
  ('slot_capacity', '40'),
  ('day_capacity',  '80'),                  -- denní kapacita ve fázi 2
  ('hold_minutes',  '15'),
  ('opening_hours', '{"open": "09:00", "close": "17:00"}'),
  ('timezone',      '"America/Santo_Domingo"'),
  ('free_cancel_hours', '24')
on conflict (key) do update set value = excluded.value;

-- Ceník vstupů (ukázkové ceny z prototypu, upravte před spuštěním)
insert into ticket_types (code, name_es, name_en, price) values
  ('adult',  'Adulto',           'Adult',   80),
  ('child',  'Niño',             'Child',   45),
  ('infant', 'Menor de 2 años',  'Under 2', 0);

-- Účty a pokladny
insert into accounts (name, kind, currency) values
  ('PayPal',            'paypal',        'USD'),
  ('Pokladna USD',      'cash',          'USD'),
  ('Pokladna DOP',      'cash',          'DOP'),
  ('Kartový terminál',  'card_terminal', 'USD'),
  ('Bankovní účet',     'bank',          'USD');

-- Druhy podle podkladů pro úřady (Guia de manejo)
insert into species (scientific_name, name_es, name_en, name_cs, care_manual) values
  ('Saimiri sciureus',     'Mono ardilla',             'Common squirrel monkey', 'Kotul veverovitý',   'Guia de manejo para Saimiri sciureus'),
  ('Ramphastidae',         'Tucanes',                  'Toucans',                'Tukanovití',         'Guia de manejo para Ramphastidae'),
  ('Psittacidae',          'Loros y guacamayos',       'Parrots and macaws',     'Papouškovití',       'Guia de manejo para Psittacidae'),
  ('Cyclura cornuta',      'Iguana rinoceronte',       'Rhinoceros iguana',      'Leguán nosorohý',    'Guia de manejo para Cyclura cornuta'),
  ('Choloepus hoffmanni',  'Perezoso de Hoffmann',     'Hoffmann''s two-toed sloth', 'Lenochod Hoffmannův', 'Guia de manejo para Choloepus hoffmanni y Choloepus dydactilus'),
  ('Choloepus didactylus', 'Perezoso de dos dedos',    'Linnaeus''s two-toed sloth', 'Lenochod dvouprstý', 'Guia de manejo para Choloepus hoffmanni y Choloepus dydactilus'),
  ('Crocodylus acutus',    'Cocodrilo americano',      'American crocodile',     'Krokodýl americký',  'Guia de manejo para Cocodrylus acutus'),
  ('Chilabothrus striatus','Boa de La Española',       'Hispaniolan boa',        null,'Guia de manejo para Chilabothrus striatus');

-- Zóny a expozice (podle webu, upravte podle plánu parku)
insert into enclosures (name, zone) values
  ('Aviario',                 'Aviario'),
  ('Vivarium',                'Vivarium'),
  ('Výběh krokodýlů',             'Vivarium'),
  ('Lenochodi',               'Jardín'),
  ('Opičí výběh (saimiri)',   'Jardín'),
  ('Karanténa',               'Zázemí');

-- Místa skladu
insert into stock_locations (name, kind) values
  ('Krmivárna',            'feed'),
  ('Veterinární lékárna',  'vet'),
  ('Hlavní sklad',         'general'),
  ('Bar a shop',           'bar'),
  ('Sklad údržby',         'maintenance')
on conflict (name) do nothing;
