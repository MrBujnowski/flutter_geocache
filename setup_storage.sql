-- 1. Vytvoření Storage Bucketu 'avatars', pokud neexistuje
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- 2. Policy: Kdo může vidět avatary? Všichni (public)
create policy "Avatar images are publicly accessible."
  on storage.objects for select
  using ( bucket_id = 'avatars' );

-- 3. Policy: Kdo může nahrávat? Jen přihlášení uživatelé a jen do svého folderu (volitelně)
-- Pro zjednodušení: Přihlášený uživatel může nahrát cokoliv do 'avatars'
create policy "Anyone can upload an avatar."
  on storage.objects for insert
  with check ( bucket_id = 'avatars' and auth.role() = 'authenticated' );

-- 4. Policy: Uživatel může měnit/mazat své vlastní (podle jména souboru obsahujícího user ID, nebo prostě povolit update auth users)
create policy "Authenticated users can update avatars."
  on storage.objects for update
  using ( bucket_id = 'avatars' and auth.role() = 'authenticated' );
