-- 1. Tabulka profilů (pokud už existuje, nic se nestane)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  updated_at timestamp with time zone,
  username text unique,
  avatar_url text,
  website text
);

-- Zapnutí Row Level Security (RLS)
alter table public.profiles enable row level security;

-- DROP a CREATE politik (aby skript prošel i když už existují)
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;
create policy "Public profiles are viewable by everyone." on public.profiles
  for select using (true);

drop policy if exists "Users can insert their own profile." on public.profiles;
create policy "Users can insert their own profile." on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "Users can update own profile." on public.profiles;
create policy "Users can update own profile." on public.profiles
  for update using (auth.uid() = id);

-- 2. Tabulka Definice Achievementů
create table if not exists public.achievements (
  id text primary key,
  name text not null,
  description text not null,
  icon_name text not null,
  points int default 10,
  condition_type text
);

alter table public.achievements enable row level security;

drop policy if exists "Achievements are viewable by everyone." on public.achievements;
create policy "Achievements are viewable by everyone." on public.achievements
  for select using (true);

-- 3. Tabulka Získaných Achievementů
create table if not exists public.user_achievements (
  user_id uuid references auth.users not null,
  achievement_id text references public.achievements not null,
  unlocked_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (user_id, achievement_id)
);

alter table public.user_achievements enable row level security;

drop policy if exists "User achievements are viewable by everyone." on public.user_achievements;
create policy "User achievements are viewable by everyone." on public.user_achievements
  for select using (true);

drop policy if exists "Server can insert achievements." on public.user_achievements;
create policy "Server can insert achievements." on public.user_achievements
  for insert with check (true);

-- 4. Trigger pro nové uživatele
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, username, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing; -- Prevence chyby pokud profil už existuje
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 5. Vložení základních achievementů
insert into public.achievements (id, name, description, icon_name, points, condition_type)
values 
  ('first_find', 'První úlovek', 'Najdi svou první kešku.', 'star', 10, 'count'),
  ('five_finds', 'Průzkumník', 'Najdi celkem 5 kešek.', 'explore', 50, 'count'),
  ('night_owl', 'Noční sova', 'Najdi kešku mezi 22:00 a 04:00.', 'dark_mode', 100, 'time')
on conflict (id) do update 
  set name = excluded.name, 
      description = excluded.description,
      icon_name = excluded.icon_name,
      points = excluded.points,
      condition_type = excluded.condition_type;
