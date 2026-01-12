-- Přidání chybějícího sloupce updated_at, pokud tabulka už existovala z dřívějška
alter table public.profiles 
add column if not exists updated_at timestamp with time zone;

-- Pro jistotu obnovíme cache schématu (děje se automaticky, ale pro jistotu)
notify pgrst, 'reload config';
