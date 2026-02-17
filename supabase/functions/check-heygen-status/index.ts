// ============================================================================
// Supabase Edge Function: check-heygen-status
// ============================================================================
// Manually checks status of stuck HeyGen videos and updates database
// Use this to fix videos stuck in "processing" state
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const HEYGEN_API_KEY = Deno.env.get('HEYGEN_API_KEY') || '';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ============================================================================
// Helper: Check HeyGen Video Status
// ============================================================================

async function checkVideoStatus(heygenVideoId: string) {
  console.log(`🔍 Checking status for HeyGen video: ${heygenVideoId}`);

  const response = await fetch(`https://api.heygen.com/v1/video_status.get?video_id=${heygenVideoId}`, {
    method: 'GET',
    headers: {
      'X-API-KEY': HEYGEN_API_KEY,
    },
  });

  if (!response.ok) {
    const error = await response.text();
    console.error(`❌ HeyGen API error for ${heygenVideoId}:`, error);
    return null;
  }

  const result = await response.json();
  console.log(`📊 Status response:`, result);

  return result;
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
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    console.log('🔄 Checking status of stuck HeyGen videos...');

    // Get all videos stuck in processing or pending
    const { data: stuckVideos, error: queryError } = await supabase
      .from('mm_confession_booth_videos')
      .select('id, heygen_video_id, heygen_status, created_at')
      .in('heygen_status', ['processing', 'pending'])
      .not('heygen_video_id', 'is', null)
      .order('created_at', { ascending: true });

    if (queryError) {
      throw queryError;
    }

    console.log(`📹 Found ${stuckVideos?.length || 0} stuck videos`);

    if (!stuckVideos || stuckVideos.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No stuck videos found',
          checked: 0,
          updated: 0,
        }),
        {
          status: 200,
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        }
      );
    }

    const results = [];

    // Check status for each video
    for (const video of stuckVideos) {
      try {
        const status = await checkVideoStatus(video.heygen_video_id);

        if (!status || !status.data) {
          console.log(`⚠️ No status data for video ${video.id}`);
          results.push({ video_id: video.id, status: 'no_data' });
          continue;
        }

        const heygenStatus = status.data.status; // 'completed', 'processing', 'failed', etc.
        const videoUrl = status.data.video_url;
        const thumbnailUrl = status.data.thumbnail_url;

        console.log(`📊 Video ${video.id}: HeyGen status = ${heygenStatus}`);

        // Update based on status
        if (heygenStatus === 'completed' && videoUrl) {
          console.log(`✅ Updating video ${video.id} with completed URL`);

          const { error: updateError } = await supabase
            .from('mm_confession_booth_videos')
            .update({
              video_url: videoUrl,
              thumbnail_url: thumbnailUrl,
              heygen_status: 'completed',
              published_at: new Date().toISOString(),
            })
            .eq('id', video.id);

          if (updateError) {
            console.error(`❌ Failed to update video ${video.id}:`, updateError);
            results.push({ video_id: video.id, status: 'update_failed', error: updateError.message });
          } else {
            results.push({ video_id: video.id, status: 'completed', video_url: videoUrl });
          }
        } else if (heygenStatus === 'failed') {
          console.log(`❌ Video ${video.id} failed in HeyGen`);

          await supabase
            .from('mm_confession_booth_videos')
            .update({
              heygen_status: 'failed',
              heygen_error_message: status.data.error || 'Video generation failed',
            })
            .eq('id', video.id);

          results.push({ video_id: video.id, status: 'failed', error: status.data.error });
        } else {
          console.log(`⏳ Video ${video.id} still processing`);
          results.push({ video_id: video.id, status: 'still_processing' });
        }

        // Small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 500));

      } catch (error) {
        console.error(`❌ Error checking video ${video.id}:`, error);
        results.push({ video_id: video.id, status: 'check_failed', error: error.message });
      }
    }

    const updated = results.filter(r => r.status === 'completed').length;
    const failed = results.filter(r => r.status === 'failed').length;
    const stillProcessing = results.filter(r => r.status === 'still_processing').length;

    console.log(`✅ Status check complete: ${updated} updated, ${failed} failed, ${stillProcessing} still processing`);

    return new Response(
      JSON.stringify({
        success: true,
        checked: stuckVideos.length,
        updated,
        failed,
        still_processing: stillProcessing,
        results,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );

  } catch (error) {
    console.error('❌ Error checking HeyGen status:', error);

    return new Response(
      JSON.stringify({
        error: error.message || 'Failed to check video status',
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
