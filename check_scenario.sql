-- Check if scenario exists
SELECT id, title, created_at, game_id
FROM scenarios
WHERE id = '617a13bf-6b08-4d7e-8264-8372abfcd55f';

-- Check all scenarios in your game
SELECT id, title, created_at
FROM scenarios
WHERE game_id = '8f8d5946-271b-4664-91e4-5588954b0dab'
ORDER BY created_at DESC
LIMIT 5;
