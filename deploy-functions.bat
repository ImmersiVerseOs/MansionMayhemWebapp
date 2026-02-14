@echo off
REM Deploy Edge Functions to Supabase
REM Get your access token from: https://supabase.com/dashboard/account/tokens

echo ========================================
echo Mansion Mayhem - Deploy Edge Functions
echo ========================================
echo.

REM Check if access token is provided
if "%SUPABASE_ACCESS_TOKEN%"=="" (
    echo ERROR: SUPABASE_ACCESS_TOKEN not set
    echo.
    echo To get your access token:
    echo 1. Go to: https://supabase.com/dashboard/account/tokens
    echo 2. Click "Generate new token"
    echo 3. Copy the token
    echo 4. Run: set SUPABASE_ACCESS_TOKEN=your_token_here
    echo 5. Run this script again
    echo.
    pause
    exit /b 1
)

echo ✓ Access token found
echo.

REM Link to project
echo Linking to project...
npx supabase link --project-ref fpxbhqibimekjhlumnmc
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to link project
    pause
    exit /b 1
)
echo ✓ Project linked
echo.

REM Deploy edge functions
echo Deploying ai-decision-processor...
npx supabase functions deploy ai-decision-processor
echo.

echo Deploying generate-auto-response...
npx supabase functions deploy generate-auto-response
echo.

echo Deploying generate-scenario...
npx supabase functions deploy generate-scenario
echo.

echo Deploying send-invite-email...
npx supabase functions deploy send-invite-email
echo.

echo ========================================
echo ✅ All edge functions deployed!
echo ========================================
pause
