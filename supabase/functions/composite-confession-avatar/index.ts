// ============================================================================
// Supabase Edge Function: composite-confession-avatar
// ============================================================================
// Composites user photo into confession booth background using Stability AI
// Creates realistic talking photo for HeyGen video generation
// ============================================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const STABILITY_API_KEY = Deno.env.get('STABILITY_API_KEY') || '';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// ============================================================================
// Types
// ============================================================================

interface RequestBody {
  cast_member_id: string;
  uploaded_photo_url: string;
}

// ============================================================================
// Helper: Remove Background from Photo
// ============================================================================

async function removeBackground(imageUrl: string): Promise<Blob> {
  console.log('🎨 Removing background from photo...');

  // Download the image first
  const imageResponse = await fetch(imageUrl);
  const imageBlob = await imageResponse.blob();

  // Create form data for Stability AI
  const formData = new FormData();
  formData.append('image', imageBlob);
  formData.append('output_format', 'png');

  const response = await fetch(
    'https://api.stability.ai/v2beta/stable-image/edit/remove-background',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${STABILITY_API_KEY}`,
        'Accept': 'image/*',
      },
      body: formData,
    }
  );

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Stability AI background removal failed: ${error}`);
  }

  const resultBlob = await response.blob();
  console.log('✅ Background removed');

  return resultBlob;
}

// ============================================================================
// Helper: Composite Person into Confession Booth Background
// ============================================================================

async function compositeIntoBoothBackground(
  personNoBackgroundBlob: Blob,
  boothBackgroundUrl: string
): Promise<Blob> {
  console.log('🎬 Compositing person into confession booth...');

  // Download booth background
  const bgResponse = await fetch(boothBackgroundUrl);
  const bgBlob = await bgResponse.blob();

  // Use Stability AI Image-to-Image with ControlNet for realistic composition
  const formData = new FormData();
  formData.append('image', bgBlob); // Background as base
  formData.append('control_image', personNoBackgroundBlob); // Person to composite
  formData.append('control_strength', '0.8'); // How much to preserve person
  formData.append('prompt', 'A person sitting in a confession booth, realistic lighting, photorealistic, professional photography, natural shadows, ambient lighting from confession booth');
  formData.append('negative_prompt', 'blurry, low quality, distorted, unrealistic, cartoon, artificial, fake lighting, cut out, pasted');
  formData.append('output_format', 'jpeg');
  formData.append('seed', '0');
  formData.append('style_preset', 'photographic');

  const response = await fetch(
    'https://api.stability.ai/v2beta/stable-image/control/structure',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${STABILITY_API_KEY}`,
        'Accept': 'image/*',
      },
      body: formData,
    }
  );

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Stability AI composition failed: ${error}`);
  }

  const compositeBlob = await response.blob();
  console.log('✅ Person composited into booth background');

  return compositeBlob;
}

// ============================================================================
// Helper: Upload Composite to Storage
// ============================================================================

async function uploadCompositeToStorage(
  compositeBlob: Blob,
  castMemberId: string
): Promise<string> {
  console.log('💾 Uploading composite to storage...');

  const fileName = `confession-avatar-${castMemberId}-${Date.now()}.jpg`;

  const { data, error } = await supabase.storage
    .from('confession-booth-avatars')
    .upload(fileName, compositeBlob, {
      contentType: 'image/jpeg',
      cacheControl: '3600',
      upsert: true,
    });

  if (error) {
    throw new Error(`Failed to upload composite: ${error.message}`);
  }

  // Get public URL
  const { data: { publicUrl } } = supabase.storage
    .from('confession-booth-avatars')
    .getPublicUrl(fileName);

  console.log('✅ Composite uploaded:', publicUrl);

  return publicUrl;
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
    console.log('🎭 Starting confession avatar composition...');

    // Parse request body
    const body: RequestBody = await req.json();
    const { cast_member_id, uploaded_photo_url } = body;

    // Validate required fields
    if (!cast_member_id || !uploaded_photo_url) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log('📸 Processing photo for cast member:', cast_member_id);

    // Get confession booth background URL
    const { data: { publicUrl: boothBackgroundUrl } } = supabase.storage
      .from('confession-booth-backgrounds')
      .getPublicUrl('default-booth.jpg');

    console.log('🏠 Using booth background:', boothBackgroundUrl);

    // Step 1: Remove background from person photo
    const personNoBackground = await removeBackground(uploaded_photo_url);

    // Step 2: Composite person into confession booth background
    const composite = await compositeIntoBoothBackground(
      personNoBackground,
      boothBackgroundUrl
    );

    // Step 3: Upload composite to storage
    const compositeUrl = await uploadCompositeToStorage(composite, cast_member_id);

    // Step 4: Update cast member with composite URL
    const { error: updateError } = await supabase
      .from('cast_members')
      .update({
        confession_booth_avatar_url: compositeUrl,
      })
      .eq('id', cast_member_id);

    if (updateError) {
      throw new Error(`Failed to update cast member: ${updateError.message}`);
    }

    console.log('✅ Confession avatar composition complete!');

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        composite_url: compositeUrl,
        message: 'Avatar composited successfully into confession booth!',
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
    console.error('❌ Error compositing confession avatar:', error);

    return new Response(
      JSON.stringify({
        error: error.message || 'Failed to composite avatar',
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
