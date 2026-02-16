-- Check mm_alliance_rooms table schema
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'mm_alliance_rooms'
ORDER BY ordinal_position;
