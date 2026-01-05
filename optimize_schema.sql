-- 0. Povolení PostGIS (pokud není)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Zjednodušení tabulky geocaches
ALTER TABLE public.geocaches
DROP COLUMN IF EXISTS name,
DROP COLUMN IF EXISTS description,
DROP COLUMN IF EXISTS hint;

-- Přidání sloupce pro 'Code' a 'Location' (PostGIS), plus chýbající 'type' a 'terrain'
ALTER TABLE public.geocaches
ADD COLUMN IF NOT EXISTS code text,
ADD COLUMN IF NOT EXISTS type text DEFAULT 'Tradiční',
ADD COLUMN IF NOT EXISTS terrain float8 DEFAULT 1.0,
ADD COLUMN IF NOT EXISTS location geography(Point, 4326);

-- 1.5 Dopočítání location ze souřadnic (pokud existují data)
UPDATE public.geocaches
SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
WHERE location IS NULL AND latitude IS NOT NULL AND longitude IS NOT NULL;

-- 2. Indexy
CREATE INDEX IF NOT EXISTS geocaches_geo_index ON public.geocaches USING gist (location);
CREATE INDEX IF NOT EXISTS geocaches_lat_lon_index ON public.geocaches (latitude, longitude);

-- 3. (Volitelné) Offline Logs tabulka (pro synchronizaci)
-- Tato tabulka je na serveru jen pro příjem, hlavní práce je v mobilu.
-- Ale musíme zajistit, že endpointy pro insert logs fungují.
-- Logika insertu do 'logs' zůstává stejná.
