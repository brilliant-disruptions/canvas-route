-- Seed: Pokémon TCG sets (Scarlet & Violet and Mega Evolution eras). Product names are factual
-- references for the report picker. Admins extend via the admin panel.
with sets(set_name, release_date) as (values
  ('Scarlet & Violet 151',            date '2023-09-22'),
  ('Paldean Fates',                   date '2024-01-26'),
  ('Temporal Forces',                 date '2024-03-22'),
  ('Twilight Masquerade',             date '2024-05-24'),
  ('Shrouded Fable',                  date '2024-08-02'),
  ('Stellar Crown',                   date '2024-09-13'),
  ('Surging Sparks',                  date '2024-11-08'),
  ('Prismatic Evolutions',            date '2025-01-17'),
  ('Journey Together',                date '2025-03-28'),
  ('Destined Rivals',                 date '2025-05-30'),
  ('Black Bolt',                      date '2025-07-18'),
  ('White Flare',                     date '2025-07-18'),
  ('Mega Evolution',                  date '2025-09-26'),
  ('Phantasmal Flames',               date '2025-11-14'),
  ('Ascended Heroes',                 date '2026-01-30'),
  ('Perfect Order',                   date '2026-03-27'),
  ('Chaos Rising',                    date '2026-05-22'),
  ('Pitch Black',                     date '2026-07-17'),
  ('Delta Reign',                     date '2026-11-06')
),
skus(sku_type, label) as (values
  ('etb', 'Elite Trainer Box'),
  ('booster_box', 'Booster Box'),
  ('bundle', 'Booster Bundle'),
  ('blister', 'Blister Pack'),
  ('tin', 'Tin'),
  ('collection', 'Collection Box'),
  ('pack', 'Single Booster Pack')
)
insert into public.products (game, set_name, sku_type, display_name, release_date)
select 'pokemon', s.set_name, k.sku_type, s.set_name || ' — ' || k.label, s.release_date
from sets s cross join skus k
on conflict do nothing;

-- Generic buckets for other games until their catalogs are seeded.
insert into public.products (game, set_name, sku_type, display_name) values
  ('sports',    'Any', 'other', 'Sports cards — any product'),
  ('one_piece', 'Any', 'other', 'One Piece TCG — any product'),
  ('lorcana',   'Any', 'other', 'Disney Lorcana — any product'),
  ('mtg',       'Any', 'other', 'Magic: The Gathering — any product')
on conflict do nothing;
