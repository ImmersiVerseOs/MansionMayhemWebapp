// Supabase Edge Function: Send Invite Email via SendGrid
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SENDGRID_API_KEY = Deno.env.get('SENDGRID_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface InviteEmailRequest {
  castMemberId: string
  gameId: string
  inviteCode: string
  message?: string
}

serve(async (req) => {
  // CORS headers
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      }
    })
  }

  try {
    const { castMemberId, gameId, inviteCode, message }: InviteEmailRequest = await req.json()

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get cast member email
    const { data: castMember, error: castError } = await supabase
      .from('cast_members')
      .select('user_id, full_name, display_name')
      .eq('id', castMemberId)
      .single()

    if (castError || !castMember) {
      throw new Error('Cast member not found')
    }

    // Get user email from auth.users
    const { data: { user }, error: userError } = await supabase.auth.admin.getUserById(castMember.user_id)

    if (userError || !user) {
      throw new Error('User email not found')
    }

    // Get game details
    const { data: game, error: gameError } = await supabase
      .from('mm_games')
      .select('title, game_code, theme, creator_id')
      .eq('id', gameId)
      .single()

    if (gameError || !game) {
      throw new Error('Game not found')
    }

    // Get creator name
    const { data: creator, error: creatorError } = await supabase
      .from('profiles')
      .select('full_name, email')
      .eq('id', game.creator_id)
      .single()

    const creatorName = creator?.full_name || creator?.email || 'A director'
    const castName = castMember.full_name || castMember.display_name

    // Build invite link
    const inviteLink = `${req.headers.get('origin') || 'https://mansionmayhem.com'}/join/${inviteCode}`

    // Send email via SendGrid
    const emailResponse = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        personalizations: [{
          to: [{ email: user.email, name: castName }],
          subject: `🎭 You're invited to join ${game.title}!`,
        }],
        from: {
          email: 'noreply@mansionmayhem.com',
          name: 'Mansion Mayhem'
        },
        content: [{
          type: 'text/html',
          value: generateEmailHTML({
            castName,
            creatorName,
            gameTitle: game.title,
            gameCode: game.game_code,
            theme: game.theme,
            inviteLink,
            customMessage: message
          })
        }]
      })
    })

    if (!emailResponse.ok) {
      const errorText = await emailResponse.text()
      throw new Error(`SendGrid error: ${errorText}`)
    }

    // Log the invitation
    await supabase
      .from('director_invites')
      .update({
        invite_email_sent: true,
        invite_email_sent_at: new Date().toISOString()
      })
      .eq('invite_code', inviteCode)

    return new Response(
      JSON.stringify({ success: true, message: 'Invite email sent successfully' }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        status: 400
      }
    )
  }
})

function generateEmailHTML(data: {
  castName: string
  creatorName: string
  gameTitle: string
  gameCode: string
  theme: string
  inviteLink: string
  customMessage?: string
}): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Game Invitation</title>
</head>
<body style="margin: 0; padding: 0; background: #0a0a0a; font-family: 'Helvetica Neue', Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #0a0a0a; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" border="0" style="background: #111111; border: 1px solid #2a2a2a; border-radius: 16px; overflow: hidden;">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #d4af37, #f4e4bc); padding: 40px 20px; text-align: center;">
              <h1 style="margin: 0; font-size: 36px; font-weight: 900; color: #0a0a0a; font-family: Georgia, serif;">
                MANSION MAYHEM
              </h1>
              <p style="margin: 8px 0 0; font-size: 12px; font-weight: 600; letter-spacing: 3px; text-transform: uppercase; color: #ad1457;">
                You're Invited
              </p>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 40px;">
              <p style="margin: 0 0 20px; font-size: 18px; color: #ffffff; line-height: 1.6;">
                Hi <strong>${data.castName}</strong>,
              </p>

              <p style="margin: 0 0 20px; font-size: 16px; color: #888888; line-height: 1.6;">
                <strong style="color: #d4af37;">${data.creatorName}</strong> has invited you to join their game as a cast member!
              </p>

              <!-- Game Details Box -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 12px; margin: 24px 0;">
                <tr>
                  <td style="padding: 24px;">
                    <h2 style="margin: 0 0 12px; font-size: 24px; color: #d4af37; font-family: Georgia, serif;">
                      ${data.gameTitle}
                    </h2>
                    <p style="margin: 0 0 8px; font-size: 13px; color: #888888;">
                      <strong style="color: #ffffff;">Game Code:</strong> ${data.gameCode}
                    </p>
                    <p style="margin: 0; font-size: 13px; color: #888888;">
                      <strong style="color: #ffffff;">Theme:</strong> ${data.theme || 'Reality Show'}
                    </p>
                  </td>
                </tr>
              </table>

              ${data.customMessage ? `
                <div style="background: #1a1a1a; border-left: 3px solid #d4af37; padding: 16px; margin: 24px 0; border-radius: 4px;">
                  <p style="margin: 0; font-size: 14px; color: #888888; font-style: italic;">
                    "${data.customMessage}"
                  </p>
                </div>
              ` : ''}

              <p style="margin: 24px 0; font-size: 16px; color: #888888; line-height: 1.6;">
                As a cast member, you'll respond to dramatic scenarios, make tough decisions, and create content that will be turned into episodes!
              </p>

              <!-- CTA Button -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin: 32px 0;">
                <tr>
                  <td align="center">
                    <a href="${data.inviteLink}"
                       style="display: inline-block; background: linear-gradient(135deg, #d4af37, #f4e4bc); color: #0a0a0a; text-decoration: none; padding: 16px 40px; border-radius: 10px; font-weight: 700; font-size: 16px;">
                      🎬 Accept Invitation
                    </a>
                  </td>
                </tr>
              </table>

              <p style="margin: 24px 0 0; font-size: 13px; color: #555555; line-height: 1.6;">
                Or copy this link: <a href="${data.inviteLink}" style="color: #d4af37; text-decoration: none;">${data.inviteLink}</a>
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background: #0d0d0d; padding: 24px; text-align: center; border-top: 1px solid #2a2a2a;">
              <p style="margin: 0 0 8px; font-size: 12px; color: #555555;">
                This invitation was sent from Mansion Mayhem
              </p>
              <p style="margin: 0; font-size: 11px; color: #555555;">
                If you didn't expect this invitation, you can safely ignore this email.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `
}
