-- 1. Přidání sloupce 'secret' (pokud neexistuje)
alter table public.achievements 
add column if not exists secret boolean default false;

-- 2. Vložení nových standardních achievementů
insert into public.achievements (id, name, description, icon_name, points, condition_type, secret)
values
  ('pro_hunter', 'Profi Lovec', 'Najdi 10 kešek.', 'star', 50, 'count', false),
  ('master', 'Vládce Kešek', 'Najdi 20 kešek.', 'emoji_events', 100, 'count', false),
  ('early_bird', 'Ranní Ptáče', 'Najdi kešku mezi 5:00 a 8:00 ráno.', 'wb_sunny', 30, 'time', false),
  ('lunch_break', 'Pauza na Oběd', 'Najdi kešku mezi 11:00 a 13:00.', 'restaurant', 20, 'time', false)
on conflict (id) do update 
set name = excluded.name, description = excluded.description, points = excluded.points, secret = excluded.secret;

-- 3. Vložení TAJNÝCH achievementů
insert into public.achievements (id, name, description, icon_name, points, condition_type, secret)
values
  ('deja_vu', 'Déjà Vu', 'Najdi a odemkni stejnou kešku dvakrát (po resetu).', 'replay', 50, 'action', true),
  ('weekend_warrior', 'Víkendový Bojovník', 'Najdi kešku v sobotu nebo neděli.', 'weekend', 40, 'time', true),
  ('insomniac', 'Nespavec', 'Najdi kešku mezi 02:00 a 04:00 ráno.', 'bedtime', 100, 'time', true)
on conflict (id) do update 
set name = excluded.name, description = excluded.description, points = excluded.points, secret = excluded.secret;

-- 4. Aktualizace existujících (defaultně nejsou tajné)
update public.achievements set secret = false where secret is null;

notify pgrst, 'reload config';
