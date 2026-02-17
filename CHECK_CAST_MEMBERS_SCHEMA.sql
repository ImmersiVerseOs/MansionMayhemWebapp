-- Check cast_members table schema
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'cast_members'
ORDER BY ordinal_position;
