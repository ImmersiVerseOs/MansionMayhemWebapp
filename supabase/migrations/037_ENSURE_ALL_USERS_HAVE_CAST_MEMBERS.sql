-- ============================================================================
-- ENSURE ALL USERS HAVE CAST MEMBERS
-- ============================================================================
-- Automatically creates cast_member records for all users (new and existing)
-- Required for confession booth and other features that need cast_member_id

-- ============================================================================
-- 1. Function to create cast_member for a user (if they don't have one)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.ensure_user_has_cast_member(p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cast_member_id UUID;
  v_display_name TEXT;
  v_email TEXT;
BEGIN
  -- Check if user already has a cast_member
  SELECT id INTO v_cast_member_id
  FROM public.cast_members
  WHERE user_id = p_user_id
  LIMIT 1;

  -- If they already have one, return it
  IF v_cast_member_id IS NOT NULL THEN
    RETURN v_cast_member_id;
  END IF;

  -- Get user's profile info
  SELECT display_name, email INTO v_display_name, v_email
  FROM public.profiles
  WHERE id = p_user_id;

  -- Create a display name if they don't have one
  IF v_display_name IS NULL OR v_display_name = '' THEN
    v_display_name := COALESCE(split_part(v_email, '@', 1), 'Player');
  END IF;

  -- Create new cast_member with default values
  INSERT INTO public.cast_members (
    user_id,
    full_name,
    display_name,
    archetype,
    is_ai_player,
    status,
    screen_time_score
  ) VALUES (
    p_user_id,
    v_display_name,
    v_display_name,
    'wildcard',  -- Default archetype
    false,       -- Not AI
    'active',
    'medium'
  )
  RETURNING id INTO v_cast_member_id;

  RETURN v_cast_member_id;
END;
$$;

COMMENT ON FUNCTION public.ensure_user_has_cast_member(UUID) IS
  'Creates a cast_member record for a user if they don''t have one. Returns the cast_member_id.';

-- ============================================================================
-- 2. Trigger to auto-create cast_member when profile is created
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Automatically create a cast_member for this new profile
  PERFORM public.ensure_user_has_cast_member(NEW.id);
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_profile_created ON public.profiles;

-- Create trigger
CREATE TRIGGER on_profile_created
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_profile();

COMMENT ON TRIGGER on_profile_created ON public.profiles IS
  'Automatically creates a cast_member record when a new profile is created';

-- ============================================================================
-- 3. Backfill existing users who don't have cast_members
-- ============================================================================
DO $$
DECLARE
  v_user_record RECORD;
  v_cast_member_id UUID;
  v_created_count INTEGER := 0;
BEGIN
  -- Loop through all profiles that don't have a cast_member
  FOR v_user_record IN
    SELECT p.id, p.display_name, p.email
    FROM public.profiles p
    LEFT JOIN public.cast_members cm ON cm.user_id = p.id
    WHERE cm.id IS NULL
  LOOP
    -- Create cast_member for this user
    v_cast_member_id := public.ensure_user_has_cast_member(v_user_record.id);
    v_created_count := v_created_count + 1;

    RAISE NOTICE 'Created cast_member % for user % (%)',
      v_cast_member_id,
      v_user_record.display_name,
      v_user_record.email;
  END LOOP;

  RAISE NOTICE '✅ Backfill complete: Created % cast_member records', v_created_count;
END;
$$;

-- ============================================================================
-- 4. Helper function: Get cast_member_id for a user
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_cast_member_id_for_user(p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_cast_member_id UUID;
BEGIN
  -- Try to find existing cast_member
  SELECT id INTO v_cast_member_id
  FROM public.cast_members
  WHERE user_id = p_user_id
  LIMIT 1;

  -- If not found, create one
  IF v_cast_member_id IS NULL THEN
    v_cast_member_id := public.ensure_user_has_cast_member(p_user_id);
  END IF;

  RETURN v_cast_member_id;
END;
$$;

COMMENT ON FUNCTION public.get_cast_member_id_for_user(UUID) IS
  'Gets the cast_member_id for a user. Creates one if it doesn''t exist.';
