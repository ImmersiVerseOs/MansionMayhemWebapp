// ============================================================================
// Supabase Edge Function: heygen-webhook
// ============================================================================
// Handles HeyGen video generation callbacks
// Updates video status and approves for publishing
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const HEYGEN_WEBHOOK_SECRET = Deno.env.get('HEYGEN_WEBHOOK_SECRET') || '';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ============================================================================
// Types
// ============================================================================

interface HeyGenWebhookPayload {
  event_type: 'video.completed' | 'video.failed' | 'video.processing';
  video_id: string;
  video_url?: string;
  thumbnail_url?: string;
  duration?: number;
  error?: string;
  created_at?: number;
}

// ============================================================================
// Helper: Verify Webhook Signature (Optional)
// ============================================================================

function verifyWebhookSignature(req: Request): boolean {
  // If webhook secret is configured, verify it
  if (!HEYGEN_WEBHOOK_SECRET) {
    return true; // Skip verification if no secret configured
  }

  const signature = req.headers.get('x-heygen-signature');
  if (!signature) {
    return false;
  }

  // TODO: Implement signature verification based on HeyGen's documentation
  // For now, just check if signature exists
  return signature === HEYGEN_WEBHOOK_SECRET;
}

// ============================================================================
// Helper: Auto-Approve Video (Optional)
// ============================================================================

async function autoApproveVideo(videoId: string): Promise<void> {
  // Auto-approve AI-generated videos
  // You can add moderation logic here if needed

  const { error } = await supabase
    .from('mm_confession_booth_videos')
    .update({
      is_approved: true,
      moderation_status: 'approved',
      published_at: new Date().toISOString(),
    })
    .eq('id', videoId);

  if (error) {
    console.error('Failed to auto-approve video:', error);
  } else {
    console.log('✅ Video auto-approved for publishing');
  }
}

// ============================================================================
// Helper: Send Notification to User (Optional)
// ============================================================================

async function notifyUser(castMemberId: string, videoId: string, status: string): Promise<void> {
  try {
    // Get cast member's user_id
    const { data: castMember } = await supabase
      .from('cast_members')
      .select('user_id')
      .eq('id', castMemberId)
      .single();

    if (!castMember?.user_id) {
      console.log('No user_id found for cast member');
      return;
    }

    // Create notification
    if (status === 'completed') {
      await supabase
        .from('notifications')
        .insert({
          user_id: castMember.user_id,
          notification_type: 'confession_ready',
          title: '🎬 Your Confession is Ready!',
          message: 'Your confession booth video has been generated and published to the gallery.',
          link_url: '/pages/confession-booth-gallery.html',
        });
    } else if (status === 'failed') {
      await supabase
        .from('notifications')
        .insert({
          user_id: castMember.user_id,
          notification_type: 'confession_failed',
          title: '❌ Confession Generation Failed',
          message: 'We couldn\'t generate your confession video. Please try again or contact support.',
          link_url: '/pages/confession-booth-create.html',
        });
    }

    console.log('📬 Notification sent to user');
  } catch (error) {
    console.error('Failed to send notification:', error);
  }
}

// ============================================================================
// Main Handler
// ============================================================================

serve(async (req) => {
  // CORS headers
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-heygen-signature, content-type',
      },
    });
  }

  try {
    console.log('📥 Received HeyGen webhook callback');

    // Verify webhook signature
    if (!verifyWebhookSignature(req)) {
      console.error('❌ Invalid webhook signature');
      return new Response('Unauthorized', { status: 401 });
    }

    // Parse webhook payload
    const payload: HeyGenWebhookPayload = await req.json();
    console.log('📦 Webhook payload:', payload);

    const { event_type, video_id, video_url, thumbnail_url, duration, error } = payload;

    // Find video record by HeyGen video ID
    const { data: videoRecord, error: findError } = await supabase
      .from('mm_confession_booth_videos')
      .select('id, cast_member_id')
      .eq('heygen_video_id', video_id)
      .single();

    if (findError || !videoRecord) {
      console.error('❌ Video record not found for HeyGen video_id:', video_id);
      return new Response('Video record not found', { status: 404 });
    }

    console.log('📹 Found video record:', videoRecord.id);

    // Handle different event types
    switch (event_type) {
      case 'video.completed':
        console.log('✅ Video completed successfully');

        // Update video record with completed status
        const { error: updateError } = await supabase
          .from('mm_confession_booth_videos')
          .update({
            video_url,
            thumbnail_url,
            heygen_status: 'completed',
            heygen_callback_received_at: new Date().toISOString(),
          })
          .eq('id', videoRecord.id);

        if (updateError) {
          console.error('Failed to update video record:', updateError);
          throw updateError;
        }

        // Auto-approve video
        await autoApproveVideo(videoRecord.id);

        // Send notification to user
        await notifyUser(videoRecord.cast_member_id, videoRecord.id, 'completed');

        break;

      case 'video.failed':
        console.error('❌ Video generation failed:', error);

        // Update video record with failed status
        await supabase
          .from('mm_confession_booth_videos')
          .update({
            heygen_status: 'failed',
            heygen_error_message: error || 'Video generation failed',
            heygen_callback_received_at: new Date().toISOString(),
          })
          .eq('id', videoRecord.id);

        // Send failure notification to user
        await notifyUser(videoRecord.cast_member_id, videoRecord.id, 'failed');

        break;

      case 'video.processing':
        console.log('⏳ Video is processing...');

        // Update video record with processing status
        await supabase
          .from('mm_confession_booth_videos')
          .update({
            heygen_status: 'processing',
          })
          .eq('id', videoRecord.id);

        break;

      default:
        console.log('ℹ️ Unknown event type:', event_type);
    }

    console.log('✅ Webhook processed successfully');

    return new Response(
      JSON.stringify({ success: true }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );

  } catch (error) {
    console.error('❌ Error processing HeyGen webhook:', error);

    return new Response(
      JSON.stringify({
        error: error.message || 'Failed to process webhook',
      }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
});
