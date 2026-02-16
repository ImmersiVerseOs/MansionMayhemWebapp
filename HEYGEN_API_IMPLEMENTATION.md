# HeyGen API Implementation Guide
## Confession Booth Video Generation System

---

## 📊 HeyGen API Pricing (2026)

### Credit System
- **Free Plan**: 10 monthly API credits (free for all users)
- **Pro Plan**: $99/mo for 100 credits ($0.99 per credit)
- **Scale Plan**: $330/mo for 660 credits ($0.50 per credit)
- **Enterprise**: Custom pricing

### Credit Consumption
- **2 credits per minute** of video generation
- **20-second confession video** = ~0.67 credits
- **Cost per 20-sec video:**
  - Pro: ~$0.66 per video
  - Scale: ~$0.33 per video

### Important Notes
- Credits expire every 30 days
- API plans are standalone (separate from HeyGen standard plans)
- No watermarks on paid plans
- Free plan includes watermarks

**Sources:**
- [HeyGen API Pricing Plans](https://www.heygen.com/api-pricing)
- [HeyGen API/LiveAvatar Pricing Explained](https://help.heygen.com/en/articles/10060327-heygen-api-liveavatar-pricing-subscriptions-explained)

---

## 🔧 API Technical Details

### Authentication
```http
X-API-KEY: your_heygen_api_key_here
```

**Get API Key:** HeyGen Dashboard → Settings → API Keys

### Base URL
```
https://api.heygen.com/v2
```

---

## 📹 Create Talking Photo Video Endpoint

### Endpoint
```http
POST https://api.heygen.com/v2/video/generate
```

### Headers
```javascript
{
  "X-API-KEY": "your_api_key",
  "Content-Type": "application/json"
}
```

### Request Body
```json
{
  "video_inputs": [
    {
      "character": {
        "type": "talking_photo",
        "talking_photo_id": "photo_avatar_id_or_upload",
        "talking_style": "expressive",
        "expression": "default",
        "super_resolution": true,
        "scale": 1.0
      },
      "voice": {
        "type": "audio",
        "audio_url": "https://your-storage.com/audio.mp3"
      },
      "background": {
        "type": "image",
        "url": "https://your-storage.com/confession-booth-bg.jpg"
      }
    }
  ],
  "dimension": {
    "width": 1080,
    "height": 1920
  },
  "aspect_ratio": "9:16",
  "test": false,
  "title": "Confession Booth Video"
}
```

### Response
```json
{
  "error": null,
  "data": {
    "video_id": "af273759c9xa47369e05418c69drq174"
  }
}
```

---

## 🔍 Check Video Status Endpoint

### Endpoint
```http
GET https://api.heygen.com/v1/video_status.get?video_id={video_id}
```

### Response
```json
{
  "error": null,
  "data": {
    "video_id": "af273759c9xa47369e05418c69drq174",
    "status": "completed",
    "video_url": "https://resource.heygen.ai/video/completed.mp4",
    "thumbnail_url": "https://resource.heygen.ai/thumbnail.jpg",
    "duration": 20.5,
    "created_at": 1706659200,
    "callback_id": "webhook_callback_id"
  }
}
```

### Status Values
- `pending` - Video is queued
- `processing` - Video is being generated
- `completed` - Video is ready (video_url available)
- `failed` - Generation failed

---

## 🎯 Implementation Flow for Confession Booth

### Phase 1: Avatar Setup (One-Time)
```javascript
// User selects avatar source
const avatarOptions = {
  facecast_still: 'Use FaceCast Photo',
  cameo_character: 'Use Cameo Character',
  user_upload: 'Upload Photo',
  flow_generated: 'Generate AI Avatar'
};

// Upload to Supabase storage
const { data, error } = await supabase.storage
  .from('confession-booth-avatars')
  .upload(`${userId}/avatar.jpg`, file);

// Save to cast_members table
await supabase
  .from('cast_members')
  .update({
    confession_booth_avatar_url: data.publicUrl,
    confession_avatar_source: 'user_upload',
    confession_avatar_set_at: new Date().toISOString()
  })
  .eq('id', castMemberId);
```

### Phase 2: Create Confession Video
```javascript
// Step 1: Generate audio with ElevenLabs
const audioUrl = await generateElevenLabsAudio(dialogueText, voiceId);

// Step 2: Upload audio to Supabase storage
const { data: audioData } = await supabase.storage
  .from('confession-booth-videos')
  .upload(`${videoId}/audio.mp3`, audioBlob);

// Step 3: Call HeyGen API
const heygenResponse = await fetch('https://api.heygen.com/v2/video/generate', {
  method: 'POST',
  headers: {
    'X-API-KEY': process.env.HEYGEN_API_KEY,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    video_inputs: [{
      character: {
        type: 'talking_photo',
        talking_photo_id: avatarStillUrl,
        talking_style: 'expressive',
        super_resolution: true
      },
      voice: {
        type: 'audio',
        audio_url: audioData.publicUrl
      },
      background: {
        type: 'image',
        url: 'https://your-cdn.com/confession-booth-bg.jpg'
      }
    }],
    dimension: { width: 1080, height: 1920 },
    aspect_ratio: '9:16',
    title: `Confession - ${castMemberName}`
  })
});

const { video_id } = await heygenResponse.json();

// Step 4: Save to database
await supabase
  .from('mm_confession_booth_videos')
  .insert({
    game_id: gameId,
    cast_member_id: castMemberId,
    dialogue_text: dialogueText,
    audio_url: audioData.publicUrl,
    avatar_still_url: avatarStillUrl,
    heygen_video_id: video_id,
    heygen_status: 'pending'
  });

// Step 5: Poll for completion (or use webhook)
const pollInterval = setInterval(async () => {
  const statusResponse = await fetch(
    `https://api.heygen.com/v1/video_status.get?video_id=${video_id}`,
    { headers: { 'X-API-KEY': process.env.HEYGEN_API_KEY } }
  );

  const { data } = await statusResponse.json();

  if (data.status === 'completed') {
    clearInterval(pollInterval);

    // Update database with video URL
    await supabase
      .from('mm_confession_booth_videos')
      .update({
        video_url: data.video_url,
        thumbnail_url: data.thumbnail_url,
        heygen_status: 'completed',
        heygen_callback_received_at: new Date().toISOString()
      })
      .eq('heygen_video_id', video_id);
  } else if (data.status === 'failed') {
    clearInterval(pollInterval);

    // Update with error
    await supabase
      .from('mm_confession_booth_videos')
      .update({
        heygen_status: 'failed',
        heygen_error_message: data.error || 'Video generation failed'
      })
      .eq('heygen_video_id', video_id);
  }
}, 5000); // Poll every 5 seconds
```

---

## 🎬 Webhook Alternative (Recommended)

### Setup Webhook Endpoint
```javascript
// Supabase Edge Function: heygen-webhook
export async function POST(request) {
  const payload = await request.json();

  const { video_id, status, video_url, thumbnail_url, error } = payload;

  // Update database
  await supabase
    .from('mm_confession_booth_videos')
    .update({
      video_url: status === 'completed' ? video_url : null,
      thumbnail_url: status === 'completed' ? thumbnail_url : null,
      heygen_status: status,
      heygen_error_message: error,
      heygen_callback_received_at: new Date().toISOString()
    })
    .eq('heygen_video_id', video_id);

  return new Response('OK', { status: 200 });
}
```

### Register Webhook in HeyGen Dashboard
```
Webhook URL: https://your-project.supabase.co/functions/v1/heygen-webhook
Events: video.completed, video.failed
```

---

## 🔐 Environment Variables Needed

```env
HEYGEN_API_KEY=your_heygen_api_key_here
HEYGEN_WEBHOOK_SECRET=your_webhook_secret_here
ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
```

---

## 💰 Cost Estimation for Mansion Mayhem

### Scenario: 100 Active Games per Week
- 20 players per game × 100 games = 2,000 players
- Assume 30% of players create 1 confession video per week
- **600 videos per week** = 2,400 videos per month

### Monthly Cost
**Pro Plan ($0.99/credit):**
- 2,400 videos × 0.67 credits = 1,608 credits
- 1,608 credits × $0.99 = **$1,592/month**

**Scale Plan ($0.50/credit):**
- 2,400 videos × 0.67 credits = 1,608 credits
- 1,608 credits × $0.50 = **$804/month**

**Recommendation:** Start with **Scale Plan** ($330/mo for 660 credits)
- Covers ~985 videos per month
- If usage exceeds, upgrade to higher tier or buy additional credits

---

## 📚 Additional Resources

- [HeyGen API Documentation](https://docs.heygen.com/)
- [HeyGen Authentication](https://docs.heygen.com/reference/authentication)
- [API Limits and Usage Guidelines](https://docs.heygen.com/reference/limits)
- [Create Video Endpoint Reference](https://docs.heygen.com/reference/create-an-avatar-video-v2)

---

## ✅ Implementation Checklist

- [ ] Set up HeyGen API account and get API key
- [ ] Subscribe to Scale Plan ($330/mo)
- [ ] Create Supabase Edge Function: `generate-confession-video`
- [ ] Create Supabase Edge Function: `heygen-webhook`
- [ ] Upload default confession booth background to storage
- [ ] Test avatar upload flow
- [ ] Test video generation flow
- [ ] Implement polling or webhook for status updates
- [ ] Add moderation queue for videos
- [ ] Create gallery page for approved videos
- [ ] Add usage analytics to track API costs

---

**Created:** 2026-02-16
**Status:** Ready for Implementation
