-- 1. Add role column to profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS role text DEFAULT 'player';

-- 2. Create RPC function to get caches based on role
-- Admin sees all, Player sees 5 nearest
CREATE OR REPLACE FUNCTION get_visible_caches(
  user_lat float, 
  user_lon float, 
  user_id uuid
)
RETURNS SETOF geocaches
LANGUAGE plpgsql
AS $$
DECLARE
  u_role text;
BEGIN
  -- Get user role
  SELECT role INTO u_role FROM profiles WHERE id = user_id;
  
  -- If Admin, return all
  IF u_role = 'admin' THEN
    RETURN QUERY SELECT * FROM geocaches;
  ELSE
    -- If Player, return 5 nearest
    RETURN QUERY 
    SELECT * 
    FROM geocaches
    ORDER BY location <-> ST_SetSRID(ST_MakePoint(user_lon, user_lat), 4326)
    LIMIT 5;
  END IF;
END;
$$;

-- 3. Update Policy for Deletion (Admin only)
-- Enable RLS on geocaches if not already
ALTER TABLE public.geocaches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can delete caches" ON public.geocaches
FOR DELETE
USING (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);
