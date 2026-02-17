// ============================================================================
// Supabase Edge Function: generate-confession-video
// ============================================================================
// Generates confession booth videos using HeyGen API
// Flow: Dialogue → ElevenLabs Audio → HeyGen Video → Database
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const HEYGEN_API_KEY = Deno.env.get('HEYGEN_API_KEY') || '';
const ELEVENLABS_API_KEY = Deno.env.get('ELEVENLABS_API_KEY') || '';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ============================================================================
// Types
// ============================================================================

interface RequestBody {
  cast_member_id: string;
  game_id: string;
  dialogue_text: string;
  is_anonymous?: boolean;
}

interface ElevenLabsResponse {
  audio_url: string;
  duration_seconds: number;
}

interface HeyGenResponse {
  error: null | string;
  data: {
    video_id: string;
  };
}

// ============================================================================
// Helper: Generate Audio with ElevenLabs
// ============================================================================

async function generateAudio(text: string, voiceId: string): Promise<ElevenLabsResponse> {
  console.log('📢 Generating audio with ElevenLabs...');

  const response = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
    {
      method: 'POST',
      headers: {
        'Accept': 'audio/mpeg',
        'Content-Type': 'application/json',
        'xi-api-key': ELEVENLABS_API_KEY,
      },
      body: JSON.stringify({
        text,
        model_id: 'eleven_monolingual_v1',
        voice_settings: {
          stability: 0.5,
          similarity_boost: 0.75,
        },
      }),
    }
  );

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`ElevenLabs API error: ${error}`);
  }

  // Get audio blob
  const audioBlob = await response.blob();

  // Upload to Supabase storage
  const fileName = `audio_${Date.now()}.mp3`;
  const { data: uploadData, error: uploadError } = await supabase.storage
    .from('confession-booth-videos')
    .upload(`audio/${fileName}`, audioBlob, {
      contentType: 'audio/mpeg',
      cacheControl: '3600',
    });

  if (uploadError) {
    throw new Error(`Failed to upload audio: ${uploadError.message}`);
  }

  // Get public URL
  const { data: { publicUrl } } = supabase.storage
    .from('confession-booth-videos')
    .getPublicUrl(`audio/${fileName}`);

  // Estimate duration (rough: ~150 words per minute)
  const wordCount = text.split(/\s+/).length;
  const durationSeconds = Math.ceil((wordCount / 150) * 60);

  console.log('✅ Audio generated:', publicUrl);

  return {
    audio_url: publicUrl,
    duration_seconds: durationSeconds,
  };
}

// ============================================================================
// Helper: Upload Avatar to HeyGen and Get ID
// ============================================================================

async function uploadAvatarToHeyGen(avatarUrl: string): Promise<string> {
  console.log('📤 Uploading avatar to HeyGen...');

  const response = await fetch('https://api.heygen.com/v1/talking_photo', {
    method: 'POST',
    headers: {
      'X-API-KEY': HEYGEN_API_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      image_url: avatarUrl,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`HeyGen avatar upload error: ${error}`);
  }

  const result = await response.json();

  if (result.error) {
    throw new Error(`HeyGen avatar upload error: ${result.error}`);
  }

  const talkingPhotoId = result.data?.talking_photo_id || result.data?.id;

  if (!talkingPhotoId) {
    throw new Error('HeyGen did not return a talking_photo_id');
  }

  console.log('✅ Avatar uploaded to HeyGen:', talkingPhotoId);
  return talkingPhotoId;
}

// ============================================================================
// Helper: Generate Video with HeyGen
// ============================================================================

async function generateVideo(
  talkingPhotoId: string,
  audioUrl: string,
  backgroundUrl: string
): Promise<string> {
  console.log('🎬 Generating video with HeyGen...');

  const response = await fetch('https://api.heygen.com/v2/video/generate', {
    method: 'POST',
    headers: {
      'X-API-KEY': HEYGEN_API_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      video_inputs: [
        {
          character: {
            type: 'talking_photo',
            talking_photo_id: talkingPhotoId,
            talking_style: 'expressive',
            expression: 'default',
            super_resolution: true,
            scale: 1.0,
          },
          voice: {
            type: 'audio',
            audio_url: audioUrl,
          },
          background: {
            type: 'image',
            url: backgroundUrl,
          },
        },
      ],
      dimension: {
        width: 1080,
        height: 1920,
      },
      aspect_ratio: '9:16',
      test: false,
      title: 'Confession Booth Video',
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`HeyGen API error: ${error}`);
  }

  const result: HeyGenResponse = await response.json();

  if (result.error) {
    throw new Error(`HeyGen error: ${result.error}`);
  }

  console.log('✅ Video generation started:', result.data.video_id);

  return result.data.video_id;
}

// ============================================================================
// Helper: Get Default Confession Booth Background
// ============================================================================

async function getDefaultBackground(): Promise<string> {
  // Get the default confession booth background from storage
  const { data: { publicUrl } } = supabase.storage
    .from('confession-booth-backgrounds')
    .getPublicUrl('default-booth.jpg');

  return publicUrl;
}

// ============================================================================
// Helper: Clean Text for Voice Generation
// ============================================================================

function cleanTextForVoice(text: string): string {
  // Remove asterisks and actions
  let cleaned = text.replace(/\*[^*]+\*/g, '');

  // Remove visual descriptions in parentheses
  cleaned = cleaned.replace(/\([^)]+\)/g, '');

  // Remove emojis
  cleaned = cleaned.replace(/[\u{1F600}-\u{1F64F}]/gu, '');
  cleaned = cleaned.replace(/[\u{1F300}-\u{1F5FF}]/gu, '');
  cleaned = cleaned.replace(/[\u{1F680}-\u{1F6FF}]/gu, '');
  cleaned = cleaned.replace(/[\u{2600}-\u{26FF}]/gu, '');

  // Clean up whitespace
  cleaned = cleaned.replace(/\s+/g, ' ').trim();

  return cleaned;
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
    console.log('🎭 Starting confession video generation...');

    // Parse request body
    const body: RequestBody = await req.json();
    const { cast_member_id, game_id, dialogue_text, is_anonymous = false } = body;

    // Validate required fields
    if (!cast_member_id || !game_id || !dialogue_text) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Validate dialogue length
    const wordCount = dialogue_text.trim().split(/\s+/).length;
    if (wordCount < 5 || wordCount > 50) {
      return new Response(
        JSON.stringify({ error: 'Dialogue must be between 5 and 50 words' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log('📝 Dialogue:', dialogue_text);
    console.log('📊 Word count:', wordCount);

    // 1. Get cast member data
    const { data: castMember, error: castError } = await supabase
      .from('cast_members')
      .select('confession_booth_avatar_url, ai_personality_config')
      .eq('id', cast_member_id)
      .single();

    if (castError || !castMember) {
      throw new Error('Cast member not found');
    }

    if (!castMember.confession_booth_avatar_url) {
      return new Response(
        JSON.stringify({ error: 'No confession booth avatar set. Please set up your avatar first.' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // 2. Get voice ID from personality config (or use default)
    const voiceId = castMember.ai_personality_config?.voice_id || 'EXAVITQu4vr4xnSDxMaL'; // Default voice

    // 3. Clean text for voice generation
    const cleanedText = cleanTextForVoice(dialogue_text);
    console.log('🧹 Cleaned text:', cleanedText);

    // 4. Generate audio with ElevenLabs
    const { audio_url, duration_seconds } = await generateAudio(cleanedText, voiceId);

    // 5. Get default confession booth background
    const backgroundUrl = await getDefaultBackground();

    // 6. Create database record (pending status)
    const { data: videoRecord, error: insertError } = await supabase
      .from('mm_confession_booth_videos')
      .insert({
        game_id,
        cast_member_id,
        dialogue_text,
        audio_url,
        audio_duration_seconds: duration_seconds,
        avatar_still_url: castMember.confession_booth_avatar_url,
        booth_background_url: backgroundUrl,
        is_anonymous,
        heygen_status: 'pending',
        moderation_status: 'pending',
        dialogue_word_count: wordCount,
      })
      .select()
      .single();

    if (insertError) {
      throw new Error(`Failed to create video record: ${insertError.message}`);
    }

    console.log('💾 Video record created:', videoRecord.id);

    // 7. Upload avatar to HeyGen and get talking_photo_id
    const talkingPhotoId = await uploadAvatarToHeyGen(castMember.confession_booth_avatar_url);

    // 8. Generate video with HeyGen
    const heygenVideoId = await generateVideo(
      talkingPhotoId,
      audio_url,
      backgroundUrl
    );

    // 9. Update record with HeyGen video ID
    const { error: updateError } = await supabase
      .from('mm_confession_booth_videos')
      .update({
        heygen_video_id: heygenVideoId,
        heygen_status: 'processing',
      })
      .eq('id', videoRecord.id);

    if (updateError) {
      console.error('Failed to update video record:', updateError);
    }

    console.log('✅ Confession video generation initiated successfully');

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        video_id: videoRecord.id,
        heygen_video_id: heygenVideoId,
        message: 'Video generation started. You will be notified when it\'s ready!',
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
    console.error('❌ Error generating confession video:', error);

    return new Response(
      JSON.stringify({
        error: error.message || 'Failed to generate confession video',
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
