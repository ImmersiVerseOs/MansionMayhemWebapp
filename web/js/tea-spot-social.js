// The Tea Spot - Social Features
// Enhanced version with user posting, comments, reactions, notifications

// =================================================================
// CONFIGURATION & STATE
// =================================================================

const MAX_RECORDING_DURATION = 180000; // 3 minutes (180 seconds)

let currentUser = null;
let currentCastMember = null;
let currentGameId = null;
let mediaRecorder = null;
let audioChunks = [];
let recordingStartTime = null;
let recordingInterval = null;
let recordedVoiceNote = null;
let currentRecordingContext = null;
let currentFilter = 'all';
let allPosts = [];
let voiceIntros = [];

// Archetype emojis
const archetypeEmoji = {
  'queen': '👑',
  'villain': '💀',
  'wildcard': '🎲',
  'troublemaker': '🔥',
  'strategist': '🧠',
  'loyalist': '🤝',
  'underdog': '🌟'
};

// =================================================================
// INITIALIZATION
// =================================================================

document.addEventListener('DOMContentLoaded', async () => {
  try {
    // Try to get current user
    const { data: { user }, error: authError } = await sbClient.auth.getUser();

    if (user) {
      currentUser = user;

      // Get cast member info
      const { data: castMember, error: castError } = await sbClient
        .from('cast_members')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

      if (castMember) {
        currentCastMember = castMember;
        currentGameId = castMember.game_id;
        initializeUserUI();
        await loadNotifications();
      }
    }

    // Load posts (works for everyone)
    await loadPosts();

    // Load voice introductions
    await loadVoiceIntros();

    // Set up realtime subscriptions
    setupRealtimeSubscriptions();

    // Set up event listeners
    setupEventListeners();

  } catch (error) {
    console.error('Initialization error:', error);
  }
});

// =================================================================
// UI INITIALIZATION
// =================================================================

function initializeUserUI() {
  // Show post composer
  document.getElementById('postComposer').style.display = 'block';

  // Set user info
  document.getElementById('userName').textContent = currentCastMember.display_name;
  const archetype = currentCastMember.archetype || 'wildcard';
  const emoji = archetypeEmoji[archetype] || '🎭';
  document.getElementById('userArchetype').textContent = `${emoji} ${archetype}`;
  document.getElementById('userArchetype').className = `archetype-badge badge-${archetype}`;

  // Set avatar
  const avatarImg = document.getElementById('userAvatar');
  avatarImg.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(currentCastMember.display_name)}&size=48`;
}

// =================================================================
// EVENT LISTENERS
// =================================================================

function setupEventListeners() {
  // Post type selector
  document.querySelectorAll('.post-type-selector button').forEach(btn => {
    btn.addEventListener('click', (e) => {
      document.querySelectorAll('.post-type-selector button').forEach(b => b.classList.remove('active'));
      e.target.classList.add('active');
    });
  });

  // Record voice button
  document.getElementById('recordVoiceBtn')?.addEventListener('click', () => {
    currentRecordingContext = 'post';
    startVoiceRecording();
  });

  // Submit post button
  document.getElementById('submitPostBtn')?.addEventListener('click', submitPost);

  // Voice recording modal buttons
  document.getElementById('stopRecordingBtn').addEventListener('click', stopVoiceRecording);
  document.getElementById('cancelRecordingBtn').addEventListener('click', cancelVoiceRecording);

  // Notification bell
  document.getElementById('notificationBtn').addEventListener('click', toggleNotifications);

  // Close notification dropdown when clicking outside
  document.addEventListener('click', (e) => {
    const dropdown = document.getElementById('notificationDropdown');
    const bell = document.getElementById('notificationBtn');
    if (!dropdown.contains(e.target) && !bell.contains(e.target)) {
      dropdown.classList.remove('show');
    }
  });

  // Filter buttons
  document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      currentFilter = btn.dataset.filter;
      renderPosts();
    });
  });
}

// =================================================================
// POSTS - LOADING
// =================================================================

async function loadPosts() {
  try {
    const { data, error } = await sbClient
      .from('mm_tea_room_posts')
      .select(`
        *,
        cast_members!inner(
          display_name,
          archetype
        )
      `)
      .order('created_at', { ascending: false })
      .limit(50);

    if (error) throw error;

    allPosts = data || [];
    updateStats();
    renderPosts();

    console.log(`✅ Loaded ${allPosts.length} posts`);
  } catch (error) {
    console.error('Error loading posts:', error);
    document.getElementById('postsFeed').innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">❌</div>
        <h3>Error loading posts</h3>
        <p>${error.message}</p>
      </div>
    `;
  }
}

async function loadVoiceIntros() {
  try {
    // Get game ID from URL or current game
    const urlParams = new URLSearchParams(window.location.search);
    const gameId = urlParams.get('game') || currentGameId;

    if (!gameId) {
      console.log('No game ID found for voice intros');
      return;
    }

    const { data, error } = await sbClient.rpc('get_lobby_voice_intros', {
      p_game_id: gameId
    });

    if (error) throw error;

    voiceIntros = data || [];
    console.log(`✅ Loaded ${voiceIntros.length} voice introductions`);

  } catch (error) {
    console.error('Error loading voice intros:', error);
    voiceIntros = [];
  }
}

function updateStats() {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  const todayPosts = allPosts.filter(p => new Date(p.created_at) >= today);
  const voicePosts = allPosts.filter(p => p.voice_note_url);
  const uniquePlayers = new Set(allPosts.map(p => p.cast_member_id));

  document.getElementById('totalPosts').textContent = allPosts.length;
  document.getElementById('todayPosts').textContent = todayPosts.length;
  document.getElementById('voicePosts').textContent = voicePosts.length + voiceIntros.length;
  document.getElementById('activePlayers').textContent = uniquePlayers.size;
}

function renderPosts() {
  const feed = document.getElementById('postsFeed');

  // Handle Introductions filter separately
  if (currentFilter === 'introductions') {
    if (voiceIntros.length === 0) {
      feed.innerHTML = `
        <div class="empty-state">
          <div class="empty-state-icon">🎙️</div>
          <h3>No introductions yet...</h3>
          <p>Cast members can record voice introductions in the lobby!</p>
        </div>
      `;
      return;
    }

    feed.innerHTML = voiceIntros.map(intro => renderVoiceIntro(intro)).join('');
    setupIntroInteractions();
    return;
  }

  let filteredPosts = allPosts;

  // Apply filters
  if (currentFilter === 'voice') {
    filteredPosts = allPosts.filter(p => p.voice_note_url);
  } else if (currentFilter !== 'all') {
    filteredPosts = allPosts.filter(p => p.post_type === currentFilter);
  }

  if (filteredPosts.length === 0) {
    feed.innerHTML = `
      <div class="empty-state">
        <div class="empty-state-icon">☕</div>
        <h3>No drama yet...</h3>
        <p>Be the first to spill some tea!</p>
      </div>
    `;
    return;
  }

  feed.innerHTML = filteredPosts.map(post => renderPost(post)).join('');
  setupPostInteractions();
}

function renderPost(post) {
  const member = post.cast_members;
  const isAnonymous = post.is_anonymous;

  // If anonymous, use mask emoji and "Anonymous" name
  const displayName = isAnonymous ? 'Anonymous' : member.display_name;
  const archetype = isAnonymous ? 'confessional' : (member.archetype || 'wildcard');
  const emoji = isAnonymous ? '🎭' : (archetypeEmoji[archetype] || '🎭');
  const timeAgo = formatTimeAgo(post.created_at);

  return `
    <div class="post-card" data-post-id="${post.id}" data-post-type="${post.post_type}" ${isAnonymous ? 'style="border-color: rgba(156, 39, 176, 0.3);"' : ''}>
      <div class="post-header">
        <div class="post-avatar">${emoji}</div>
        <div class="post-info">
          <div class="post-name">
            ${displayName}
            ${isAnonymous ? `
              <span class="archetype-badge" style="background: rgba(156, 39, 176, 0.2); color: var(--purple);">
                🎭 anonymous
              </span>
            ` : `
              <span class="archetype-badge badge-${archetype}">
                ${emoji} ${archetype}
              </span>
            `}
          </div>
          <div class="post-meta">${timeAgo}</div>
        </div>
      </div>

      <div class="post-type-tag tag-${post.post_type}">${post.post_type}</div>

      <div class="post-text">${escapeHtml(post.post_text)}</div>

      ${post.voice_note_url ? `
        <div class="voice-player">
          <div class="voice-label">
            🎤 Voice Note ${post.voice_note_duration_seconds ? `(${post.voice_note_duration_seconds}s)` : ''}
          </div>
          <audio controls src="${post.voice_note_url}"></audio>
        </div>
      ` : ''}

      ${currentCastMember ? `
        <div class="post-interactions">
          <button class="like-btn" data-post-id="${post.id}">
            ❤️ <span class="like-count">${post.likes_count || 0}</span>
          </button>
          <button class="comment-btn" data-post-id="${post.id}">
            💬 <span class="comment-count">${post.comments_count || 0}</span>
          </button>
          <button class="voice-reply-btn" data-post-id="${post.id}">
            🎤 Voice Reply
          </button>
        </div>

        <div class="comments-section" id="comments-${post.id}" style="display: none;">
          <div class="comments-list" id="comments-list-${post.id}">
            <!-- Comments will be loaded here -->
          </div>

          <div class="comment-composer">
            <textarea placeholder="Add a comment..." id="comment-text-${post.id}"></textarea>
            <button class="voice-reply-btn-comment" data-post-id="${post.id}">🎤</button>
            <button class="submit-comment-btn" data-post-id="${post.id}">Reply</button>
          </div>
        </div>
      ` : ''}
    </div>
  `;
}

function renderVoiceIntro(intro) {
  const member = intro.cast_member;
  const archetype = member.archetype || 'wildcard';
  const emoji = archetypeEmoji[archetype] || '🎭';
  const duration = Math.floor(intro.duration);
  const playCount = intro.play_count || 0;

  return `
    <div class="post-card" data-intro-id="${intro.id}">
      <div class="post-header">
        <div class="post-avatar">${emoji}</div>
        <div class="post-info">
          <div class="post-name">
            ${member.display_name}
            <span class="archetype-badge badge-${archetype}">
              ${emoji} ${archetype}
            </span>
          </div>
          <div class="post-meta">🎙️ Introduction</div>
        </div>
      </div>

      <div class="post-type-tag" style="background: rgba(236, 72, 153, 0.2); color: var(--pink);">
        introduction
      </div>

      ${intro.caption ? `<div class="post-text">${escapeHtml(intro.caption)}</div>` : ''}

      <div class="voice-player">
        <div class="voice-label">
          🎤 Voice Introduction (${duration}s) • ${playCount} plays
        </div>
        <audio controls src="${intro.audio_url}" onplay="incrementIntroPlays('${intro.id}')">
          <source src="${intro.audio_url}" type="audio/webm">
          Your browser does not support audio playback.
        </audio>
      </div>

      ${member.personality_traits ? `
        <div style="margin-top: 1rem; padding: 0.75rem; background: var(--bg2); border-radius: 8px;">
          <div style="font-size: 0.875rem; color: var(--txt2); margin-bottom: 0.5rem;">Personality Traits:</div>
          <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
            ${member.personality_traits.slice(0, 4).map(trait => `
              <span style="padding: 0.25rem 0.75rem; background: rgba(139, 92, 246, 0.2); color: var(--purple); border-radius: 12px; font-size: 0.75rem;">
                ${trait}
              </span>
            `).join('')}
          </div>
        </div>
      ` : ''}
    </div>
  `;
}

function setupIntroInteractions() {
  // Add play tracking for voice intros
  document.querySelectorAll('audio[onplay]').forEach(audio => {
    // Already has onplay handler in HTML
  });
}

// Increment play count for voice intro
window.incrementIntroPlays = async function(introId) {
  try {
    await sbClient.rpc('increment_voice_note_plays', {
      p_voice_note_id: introId
    });
    console.log('✅ Incremented play count for intro:', introId);
  } catch (error) {
    console.error('Error incrementing plays:', error);
  }
}

function setupPostInteractions() {
  // Like buttons
  document.querySelectorAll('.like-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      const postId = e.currentTarget.dataset.postId;
      await toggleReaction(postId);
    });
  });

  // Comment buttons
  document.querySelectorAll('.comment-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      const postId = e.currentTarget.dataset.postId;
      const commentsSection = document.getElementById(`comments-${postId}`);

      if (commentsSection.style.display === 'none') {
        commentsSection.style.display = 'block';
        await loadComments(postId);
      } else {
        commentsSection.style.display = 'none';
      }
    });
  });

  // Voice reply buttons (for posts)
  document.querySelectorAll('.voice-reply-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const postId = e.currentTarget.dataset.postId;
      currentRecordingContext = { type: 'comment', postId };
      startVoiceRecording();
    });
  });

  // Voice reply buttons (in comment composer)
  document.querySelectorAll('.voice-reply-btn-comment').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const postId = e.currentTarget.dataset.postId;
      currentRecordingContext = { type: 'comment', postId };
      startVoiceRecording();
    });
  });

  // Submit comment buttons
  document.querySelectorAll('.submit-comment-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      const postId = e.currentTarget.dataset.postId;
      await submitComment(postId);
    });
  });
}

// =================================================================
// POSTS - CREATING
// =================================================================

async function submitPost() {
  if (!currentCastMember) {
    showToast('Please log in to post');
    return;
  }

  const postText = document.getElementById('postText').value.trim();
  const postType = document.querySelector('.post-type-selector button.active').dataset.type;
  const voiceNote = recordedVoiceNote;
  const isAnonymous = document.getElementById('anonymousToggle').checked;

  if (!postText && !voiceNote) {
    showToast('Please add text or a voice note');
    return;
  }

  const submitBtn = document.getElementById('submitPostBtn');
  submitBtn.disabled = true;
  submitBtn.textContent = 'Posting...';

  try {
    const { data, error } = await sbClient
      .from('mm_tea_room_posts')
      .insert({
        game_id: currentGameId,
        cast_member_id: currentCastMember.id,
        post_text: postText || null,
        post_type: postType,
        voice_note_url: voiceNote?.url || null,
        voice_note_duration_seconds: voiceNote?.duration || null,
        is_anonymous: isAnonymous
      })
      .select()
      .single();

    if (error) throw error;

    // Clear form
    document.getElementById('postText').value = '';
    document.getElementById('anonymousToggle').checked = false;
    recordedVoiceNote = null;

    const message = isAnonymous
      ? 'Posted anonymously to The Tea Spot! 🎭'
      : 'Posted to The Tea Spot! ☕';
    showToast(message);

  } catch (error) {
    console.error('Error posting:', error);
    showToast('Failed to post. Please try again.');
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = 'Post to Tea Spot';
  }
}

// =================================================================
// VOICE RECORDING
// =================================================================

async function startVoiceRecording() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true
      }
    });

    mediaRecorder = new MediaRecorder(stream);
    audioChunks = [];

    mediaRecorder.ondataavailable = (e) => audioChunks.push(e.data);

    mediaRecorder.onstop = async () => {
      const audioBlob = new Blob(audioChunks, { type: 'audio/webm' });
      await uploadVoiceNote(audioBlob);
      stream.getTracks().forEach(track => track.stop());
    };

    mediaRecorder.start();
    recordingStartTime = Date.now();

    // Auto-stop at 3 minutes
    setTimeout(() => {
      if (mediaRecorder && mediaRecorder.state === 'recording') {
        stopVoiceRecording();
      }
    }, MAX_RECORDING_DURATION);

    // Update timer
    recordingInterval = setInterval(updateRecordingTimer, 100);

    showRecordingModal();

  } catch (error) {
    console.error('Error starting recording:', error);
    showToast('Could not access microphone');
  }
}

function stopVoiceRecording() {
  if (mediaRecorder && mediaRecorder.state === 'recording') {
    mediaRecorder.stop();
    clearInterval(recordingInterval);
    hideRecordingModal();
  }
}

function cancelVoiceRecording() {
  if (mediaRecorder && mediaRecorder.state === 'recording') {
    mediaRecorder.stop();
    clearInterval(recordingInterval);
    audioChunks = [];
    recordedVoiceNote = null;
    currentRecordingContext = null;
    hideRecordingModal();
  }
}

function updateRecordingTimer() {
  const elapsed = Date.now() - recordingStartTime;
  const seconds = Math.floor(elapsed / 1000);
  const minutes = Math.floor(seconds / 60);
  const secs = seconds % 60;

  const timerDisplay = `${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')} / 03:00`;
  document.getElementById('recordingTimer').textContent = timerDisplay;
}

async function uploadVoiceNote(audioBlob) {
  try {
    const fileName = `${currentCastMember.id}/${Date.now()}.webm`;
    const duration = Math.round((Date.now() - recordingStartTime) / 1000);

    const { data, error } = await sbClient.storage
      .from('voice-notes')
      .upload(fileName, audioBlob, {
        contentType: 'audio/webm',
        cacheControl: '3600'
      });

    if (error) throw error;

    const { data: urlData } = sbClient.storage
      .from('voice-notes')
      .getPublicUrl(fileName);

    recordedVoiceNote = {
      url: urlData.publicUrl,
      duration
    };

    showToast('Voice note recorded! 🎤');

    // Auto-submit if commenting
    if (currentRecordingContext && typeof currentRecordingContext === 'object' && currentRecordingContext.type === 'comment') {
      await submitComment(currentRecordingContext.postId, null, recordedVoiceNote);
      recordedVoiceNote = null;
      currentRecordingContext = null;
    }

  } catch (error) {
    console.error('Error uploading voice note:', error);
    showToast('Failed to upload voice note');
  }
}

function showRecordingModal() {
  document.getElementById('voiceRecordModal').classList.add('show');
}

function hideRecordingModal() {
  document.getElementById('voiceRecordModal').classList.remove('show');
}

// =================================================================
// COMMENTS
// =================================================================

async function loadComments(postId) {
  try {
    const { data: comments, error } = await sbClient
      .from('mm_tea_spot_comments')
      .select(`
        *,
        cast_members!inner(display_name, archetype)
      `)
      .eq('post_id', postId)
      .is('parent_id', null)
      .order('created_at', { ascending: true });

    if (error) throw error;

    // Load replies for each comment
    for (const comment of comments) {
      comment.replies = await loadReplies(comment.id);
    }

    renderComments(postId, comments);

  } catch (error) {
    console.error('Error loading comments:', error);
  }
}

async function loadReplies(commentId) {
  try {
    const { data: replies, error } = await sbClient
      .from('mm_tea_spot_comments')
      .select(`
        *,
        cast_members!inner(display_name, archetype)
      `)
      .eq('parent_id', commentId)
      .order('created_at', { ascending: true });

    if (error) throw error;
    return replies || [];

  } catch (error) {
    console.error('Error loading replies:', error);
    return [];
  }
}

function renderComments(postId, comments) {
  const commentsList = document.getElementById(`comments-list-${postId}`);

  if (!comments || comments.length === 0) {
    commentsList.innerHTML = '<p style="color: var(--txt2); font-size: 0.9rem; padding: 1rem;">No comments yet. Be the first!</p>';
    return;
  }

  commentsList.innerHTML = comments.map(comment => renderComment(comment, postId)).join('');
  setupCommentInteractions();
}

function renderComment(comment, postId) {
  const member = comment.cast_members;
  const isAnonymous = comment.is_anonymous;

  const displayName = isAnonymous ? 'Anonymous' : member.display_name;
  const emoji = isAnonymous ? '🎭' : (archetypeEmoji[member.archetype] || '🎭');

  return `
    <div class="comment-card" data-comment-id="${comment.id}">
      <div class="comment-header">
        <div class="comment-avatar">${emoji}</div>
        <span class="comment-author">${displayName}</span>
        <span class="comment-time">${formatTimeAgo(comment.created_at)}</span>
      </div>

      ${comment.comment_text ? `<div class="comment-text">${escapeHtml(comment.comment_text)}</div>` : ''}

      ${comment.voice_note_url ? `<audio controls src="${comment.voice_note_url}"></audio>` : ''}

      <div class="comment-actions">
        <button class="like-comment-btn" data-comment-id="${comment.id}">
          ❤️ ${comment.like_count || 0}
        </button>
        <button class="reply-btn" data-comment-id="${comment.id}" data-post-id="${postId}">
          ↩️ Reply
        </button>
      </div>

      ${comment.replies && comment.replies.length > 0 ? `
        <div class="comment-replies">
          ${comment.replies.map(reply => renderReply(reply)).join('')}
        </div>
      ` : ''}
    </div>
  `;
}

function renderReply(reply) {
  const member = reply.cast_members;
  const isAnonymous = reply.is_anonymous;

  const displayName = isAnonymous ? 'Anonymous' : member.display_name;
  const emoji = isAnonymous ? '🎭' : (archetypeEmoji[member.archetype] || '🎭');

  return `
    <div class="comment-card" data-comment-id="${reply.id}">
      <div class="comment-header">
        <div class="comment-avatar">${emoji}</div>
        <span class="comment-author">${displayName}</span>
        <span class="comment-time">${formatTimeAgo(reply.created_at)}</span>
      </div>

      ${reply.comment_text ? `<div class="comment-text">${escapeHtml(reply.comment_text)}</div>` : ''}

      ${reply.voice_note_url ? `<audio controls src="${reply.voice_note_url}"></audio>` : ''}

      <div class="comment-actions">
        <button class="like-comment-btn" data-comment-id="${reply.id}">
          ❤️ ${reply.like_count || 0}
        </button>
      </div>
    </div>
  `;
}

function setupCommentInteractions() {
  // Like comment buttons
  document.querySelectorAll('.like-comment-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      const commentId = e.currentTarget.dataset.commentId;
      await toggleReaction(null, commentId);
    });
  });

  // Reply buttons
  document.querySelectorAll('.reply-btn').forEach(btn => {
    btn.addEventListener('click', async (e) => {
      const commentId = e.currentTarget.dataset.commentId;
      const postId = e.currentTarget.dataset.postId;

      const replyText = prompt('Enter your reply:');
      if (replyText && replyText.trim()) {
        await submitComment(postId, replyText.trim(), null, commentId);
      }
    });
  });
}

async function submitComment(postId, commentText = null, voiceNote = null, parentId = null, isAnonymous = false) {
  if (!currentCastMember) {
    showToast('Please log in to comment');
    return;
  }

  // Get comment text from textarea if not provided
  if (!commentText && !voiceNote) {
    commentText = document.getElementById(`comment-text-${postId}`)?.value.trim();
  }

  if (!commentText && !voiceNote) {
    showToast('Please add a comment or voice note');
    return;
  }

  try {
    const { data, error } = await sbClient
      .from('mm_tea_spot_comments')
      .insert({
        post_id: postId,
        cast_member_id: currentCastMember.id,
        parent_id: parentId,
        comment_text: commentText || null,
        voice_note_url: voiceNote?.url || null,
        voice_note_duration_seconds: voiceNote?.duration || null,
        is_anonymous: isAnonymous
      })
      .select()
      .single();

    if (error) throw error;

    // Clear comment textarea
    const textarea = document.getElementById(`comment-text-${postId}`);
    if (textarea) textarea.value = '';

    const message = isAnonymous ? 'Comment added anonymously! 🎭' : 'Comment added! 💬';
    showToast(message);

    // Reload comments
    await loadComments(postId);

  } catch (error) {
    console.error('Error submitting comment:', error);
    showToast('Failed to add comment');
  }
}

// =================================================================
// REACTIONS
// =================================================================

async function toggleReaction(postId = null, commentId = null) {
  if (!currentCastMember) {
    showToast('Please log in to react');
    return;
  }

  try {
    // Check if already reacted
    let query = sbClient
      .from('mm_tea_spot_reactions')
      .select('id')
      .eq('cast_member_id', currentCastMember.id);

    if (postId) {
      query = query.eq('post_id', postId);
    } else {
      query = query.eq('comment_id', commentId);
    }

    const { data: existing } = await query.maybeSingle();

    if (existing) {
      // Unlike
      await sbClient
        .from('mm_tea_spot_reactions')
        .delete()
        .eq('id', existing.id);
    } else {
      // Like
      await sbClient
        .from('mm_tea_spot_reactions')
        .insert({
          post_id: postId,
          comment_id: commentId,
          cast_member_id: currentCastMember.id,
          reaction_type: 'like'
        });
    }

    // Reload posts or comments
    if (postId) {
      await loadPosts();
    } else {
      const comment = await sbClient
        .from('mm_tea_spot_comments')
        .select('post_id')
        .eq('id', commentId)
        .single();

      if (comment.data) {
        await loadComments(comment.data.post_id);
      }
    }

  } catch (error) {
    console.error('Error toggling reaction:', error);
    showToast('Failed to update reaction');
  }
}

// =================================================================
// NOTIFICATIONS
// =================================================================

async function loadNotifications() {
  if (!currentCastMember) return;

  try {
    const { data: notifications, error } = await sbClient
      .from('mm_tea_spot_notifications')
      .select(`
        *,
        from_cast_member:cast_members!from_cast_member_id(display_name)
      `)
      .eq('cast_member_id', currentCastMember.id)
      .order('created_at', { ascending: false })
      .limit(20);

    if (error) throw error;

    const unreadCount = notifications.filter(n => !n.is_read).length;
    const badge = document.getElementById('unreadCount');

    if (unreadCount > 0) {
      badge.textContent = unreadCount;
      badge.classList.remove('hidden');
    } else {
      badge.classList.add('hidden');
    }

    renderNotifications(notifications);

  } catch (error) {
    console.error('Error loading notifications:', error);
  }
}

function renderNotifications(notifications) {
  const dropdown = document.getElementById('notificationDropdown');

  if (!notifications || notifications.length === 0) {
    dropdown.innerHTML = '<div style="padding: 1.5rem; text-align: center; color: var(--txt2);">No notifications</div>';
    return;
  }

  dropdown.innerHTML = notifications.map(notif => {
    const fromMember = notif.from_cast_member;

    return `
      <div class="notification-item ${notif.is_read ? '' : 'unread'}" data-notification-id="${notif.id}" data-action-url="${notif.action_url || ''}">
        <div style="width: 40px; height: 40px; background: linear-gradient(135deg, var(--purple), var(--pink)); border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 1.2rem;">
          ${archetypeEmoji[fromMember?.archetype] || '👤'}
        </div>
        <div class="notification-content">
          <strong>${fromMember?.display_name || 'Someone'}</strong> ${notif.message}
          <span class="notification-time">${formatTimeAgo(notif.created_at)}</span>
        </div>
      </div>
    `;
  }).join('');

  // Add click handlers
  dropdown.querySelectorAll('.notification-item').forEach(item => {
    item.addEventListener('click', async (e) => {
      const notifId = e.currentTarget.dataset.notificationId;
      await markNotificationRead(notifId);
      dropdown.classList.remove('show');
      // Reload page to show highlighted post
      location.reload();
    });
  });
}

async function markNotificationRead(notificationId) {
  try {
    await sbClient
      .from('mm_tea_spot_notifications')
      .update({ is_read: true })
      .eq('id', notificationId);

    await loadNotifications();

  } catch (error) {
    console.error('Error marking notification as read:', error);
  }
}

function toggleNotifications() {
  const dropdown = document.getElementById('notificationDropdown');
  dropdown.classList.toggle('show');
}

// =================================================================
// REALTIME SUBSCRIPTIONS
// =================================================================

function setupRealtimeSubscriptions() {
  // Subscribe to new posts
  sbClient
    .channel('tea-spot-posts')
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'mm_tea_room_posts'
    }, async (payload) => {
      console.log('🔥 New post!', payload);

      // Fetch full post with cast member info
      const { data } = await sbClient
        .from('mm_tea_room_posts')
        .select(`
          *,
          cast_members!inner(
            display_name,
            archetype
          )
        `)
        .eq('id', payload.new.id)
        .single();

      if (data) {
        allPosts.unshift(data);
        updateStats();
        renderPosts();
      }
    })
    .subscribe();

  // Subscribe to notifications (if logged in)
  if (currentCastMember) {
    sbClient
      .channel('tea-spot-notifications')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'mm_tea_spot_notifications',
        filter: `cast_member_id=eq.${currentCastMember.id}`
      }, (payload) => {
        console.log('🔔 New notification!', payload);
        loadNotifications();
        showToast(`${payload.new.message} 🔔`);
      })
      .subscribe();
  }
}

// =================================================================
// UTILITIES
// =================================================================

function formatTimeAgo(timestamp) {
  const now = new Date();
  const date = new Date(timestamp);
  const seconds = Math.floor((now - date) / 1000);

  if (seconds < 60) return 'just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`;
  return date.toLocaleDateString();
}

function escapeHtml(text) {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function showToast(message) {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 3000);
}

// Auto-refresh every 30 seconds
setInterval(loadPosts, 30000);
