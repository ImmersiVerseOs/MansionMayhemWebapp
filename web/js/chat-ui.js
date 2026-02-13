/**
 * LIVE CHAT UI COMPONENT
 * =======================
 * Real-time chat interface for cast members within a game
 */

class ChatUI {
  constructor(realtimeManager, gameId, castMemberId, castMemberName) {
    this.realtime = realtimeManager;
    this.gameId = gameId;
    this.castMemberId = castMemberId;
    this.castMemberName = castMemberName;
    this.messages = [];
    this.isOpen = false;
    this.onlineUsers = new Map();

    this.init();
  }

  async init() {
    // Create chat UI
    this.createChatWidget();
    this.addStyles();

    // Load chat history
    await this.loadHistory();

    // Subscribe to real-time messages
    this.realtime.subscribeToChat(this.gameId, (update) => {
      this.handleChatUpdate(update);
    });

    // Subscribe to presence (who's online)
    this.realtime.subscribeToPresence(
      this.gameId,
      this.castMemberId,
      this.castMemberName,
      (presence) => {
        this.handlePresenceUpdate(presence);
      }
    );
  }

  // ============================================================
  // UI CREATION
  // ============================================================

  createChatWidget() {
    const widgetHTML = `
      <!-- Chat Toggle Button -->
      <div class="chat-toggle" id="chatToggle">
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
        </svg>
        <span class="chat-unread-badge" id="chatUnreadBadge" style="display:none;">0</span>
      </div>

      <!-- Chat Panel -->
      <div class="chat-panel" id="chatPanel">
        <div class="chat-header">
          <div class="chat-header-left">
            <h3>💬 Cast Chat</h3>
            <div class="chat-online-status" id="chatOnlineStatus">
              <span class="online-dot"></span>
              <span id="chatOnlineCount">0</span> online
            </div>
          </div>
          <button class="chat-close" id="chatClose">×</button>
        </div>

        <div class="chat-online-users" id="chatOnlineUsers"></div>

        <div class="chat-messages" id="chatMessages">
          <div class="chat-loading">Loading messages...</div>
        </div>

        <div class="chat-input-container">
          <textarea
            class="chat-input"
            id="chatInput"
            placeholder="Type a message..."
            rows="1"
          ></textarea>
          <button class="chat-send" id="chatSend">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="22" y1="2" x2="11" y2="13"></line>
              <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
            </svg>
          </button>
        </div>
      </div>
    `;

    document.body.insertAdjacentHTML('beforeend', widgetHTML);

    // Event listeners
    document.getElementById('chatToggle').addEventListener('click', () => this.toggleChat());
    document.getElementById('chatClose').addEventListener('click', () => this.closeChat());
    document.getElementById('chatSend').addEventListener('click', () => this.sendMessage());
    document.getElementById('chatInput').addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        this.sendMessage();
      }
    });

    // Auto-resize textarea
    const input = document.getElementById('chatInput');
    input.addEventListener('input', () => {
      input.style.height = 'auto';
      input.style.height = Math.min(input.scrollHeight, 120) + 'px';
    });
  }

  // ============================================================
  // CHAT OPERATIONS
  // ============================================================

  async loadHistory() {
    this.messages = await this.realtime.getChatHistory(this.gameId, 100);
    this.renderMessages();
  }

  handleChatUpdate(update) {
    if (update.type === 'new') {
      this.messages.push(update.message);
      this.renderMessages();
      this.scrollToBottom();

      // Show unread badge if chat is closed
      if (!this.isOpen) {
        this.incrementUnreadBadge();
      }

      // Play sound if message is from someone else
      if (update.message.sender_cast_member_id !== this.castMemberId) {
        this.playMessageSound();
      }
    } else if (update.type === 'update') {
      const index = this.messages.findIndex(m => m.id === update.message.id);
      if (index !== -1) {
        this.messages[index] = update.message;
        this.renderMessages();
      }
    } else if (update.type === 'delete') {
      const index = this.messages.findIndex(m => m.id === update.messageId);
      if (index !== -1) {
        this.messages.splice(index, 1);
        this.renderMessages();
      }
    }
  }

  async sendMessage() {
    const input = document.getElementById('chatInput');
    const message = input.value.trim();

    if (!message) return;

    // Extract mentions (@username)
    const mentions = this.extractMentions(message);

    try {
      // Send message
      const sent = await this.realtime.sendMessage(
        this.gameId,
        this.castMemberId,
        message,
        { mentions }
      );

      if (sent) {
        input.value = '';
        input.style.height = 'auto';
      } else {
        // Failed to send
        if (window.showToast) {
          window.showToast('Failed to send message. Please try again.', 'error');
        }
      }
    } catch (error) {
      console.error('Error sending message:', error);
      // Show user-facing error message
      if (window.showToast) {
        window.showToast('An error occurred sending your message. Please try again.', 'error');
      }
    }
  }

  extractMentions(message) {
    // Extract @mentions from message
    const mentionRegex = /@(\w+)/g;
    const mentions = [];
    let match;

    while ((match = mentionRegex.exec(message)) !== null) {
      const username = match[1].toLowerCase();
      // Find cast member by username (simplified - you might need better matching)
      const user = Array.from(this.onlineUsers.values())
        .find(u => u.cast_member_name.toLowerCase().includes(username));
      if (user) {
        mentions.push(user.cast_member_id);
      }
    }

    return mentions;
  }

  // ============================================================
  // PRESENCE HANDLING
  // ============================================================

  handlePresenceUpdate(presence) {
    if (presence.type === 'sync') {
      // Full state update
      this.onlineUsers.clear();
      Object.values(presence.state).forEach(presences => {
        presences.forEach(p => {
          this.onlineUsers.set(p.cast_member_id, p);
        });
      });
    } else if (presence.type === 'join') {
      presence.presences.forEach(p => {
        this.onlineUsers.set(p.cast_member_id, p);
      });
    } else if (presence.type === 'leave') {
      presence.presences.forEach(p => {
        this.onlineUsers.delete(p.cast_member_id);
      });
    }

    this.updateOnlineUsers();
  }

  updateOnlineUsers() {
    const count = document.getElementById('chatOnlineCount');
    const container = document.getElementById('chatOnlineUsers');

    if (count) {
      count.textContent = this.onlineUsers.size;
    }

    if (container) {
      const usersHTML = Array.from(this.onlineUsers.values())
        .filter(u => u.cast_member_id !== this.castMemberId) // Exclude self
        .map(u => `
          <div class="online-user">
            <div class="online-user-avatar">${this.getInitials(u.cast_member_name)}</div>
            <div class="online-user-name">${u.cast_member_name}</div>
            <div class="online-user-indicator"></div>
          </div>
        `).join('');

      container.innerHTML = usersHTML || '<div class="no-online-users">No other cast members online</div>';
    }
  }

  // ============================================================
  // MESSAGE RENDERING
  // ============================================================

  renderMessages() {
    const container = document.getElementById('chatMessages');
    if (!container) return;

    if (this.messages.length === 0) {
      container.innerHTML = `
        <div class="chat-empty">
          <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
          </svg>
          <p>No messages yet. Be the first to say something!</p>
        </div>
      `;
      return;
    }

    const html = this.messages.map((msg, idx) => {
      const prev = this.messages[idx - 1];
      const showAvatar = !prev || prev.cast_member_id !== msg.cast_member_id;
      const showTimestamp = !prev || this.shouldShowTimestamp(prev.created_at, msg.created_at);

      return this.renderMessage(msg, showAvatar, showTimestamp);
    }).join('');

    container.innerHTML = html;
    this.scrollToBottom();
  }

  renderMessage(message, showAvatar, showTimestamp) {
    const isOwn = message.sender_cast_member_id === this.castMemberId;
    const time = new Date(message.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const initials = this.getInitials(message.cast_member?.display_name || 'Unknown');

    return `
      ${showTimestamp ? `<div class="chat-timestamp">${this.formatTimestamp(message.created_at)}</div>` : ''}
      <div class="chat-message ${isOwn ? 'own' : ''}">
        <div class="chat-message-avatar" style="${showAvatar ? '' : 'opacity:0;'}">
          ${initials}
        </div>
        <div class="chat-message-content">
          ${showAvatar && !isOwn ? `<div class="chat-message-sender">${message.cast_member?.display_name || 'Unknown'}</div>` : ''}
          <div class="chat-message-bubble">
            ${this.formatMessageText(message.message)}
            ${message.edited ? '<span class="chat-message-edited">(edited)</span>' : ''}
          </div>
          <div class="chat-message-time">${time}</div>
        </div>
      </div>
    `;
  }

  formatMessageText(text) {
    // Simple formatting: convert @mentions to highlighted spans
    return text.replace(/@(\w+)/g, '<span class="chat-mention">@$1</span>');
  }

  shouldShowTimestamp(prevTime, currentTime) {
    const prev = new Date(prevTime);
    const current = new Date(currentTime);
    const diffMinutes = (current - prev) / 1000 / 60;
    return diffMinutes > 15; // Show timestamp every 15 minutes
  }

  formatTimestamp(timestamp) {
    const date = new Date(timestamp);
    const now = new Date();
    const diffDays = Math.floor((now - date) / (1000 * 60 * 60 * 24));

    if (diffDays === 0) {
      return 'Today ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } else if (diffDays === 1) {
      return 'Yesterday ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } else {
      return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
  }

  getInitials(name) {
    if (!name) return '?';
    return name
      .split(' ')
      .map(n => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  }

  // ============================================================
  // UI INTERACTIONS
  // ============================================================

  toggleChat() {
    if (this.isOpen) {
      this.closeChat();
    } else {
      this.openChat();
    }
  }

  openChat() {
    const panel = document.getElementById('chatPanel');
    if (panel) {
      panel.classList.add('open');
      this.isOpen = true;
      this.clearUnreadBadge();
      this.scrollToBottom();
      document.getElementById('chatInput')?.focus();
    }
  }

  closeChat() {
    const panel = document.getElementById('chatPanel');
    if (panel) {
      panel.classList.remove('open');
      this.isOpen = false;
    }
  }

  scrollToBottom() {
    setTimeout(() => {
      const messages = document.getElementById('chatMessages');
      if (messages) {
        messages.scrollTop = messages.scrollHeight;
      }
    }, 100);
  }

  incrementUnreadBadge() {
    const badge = document.getElementById('chatUnreadBadge');
    if (badge) {
      const current = parseInt(badge.textContent) || 0;
      badge.textContent = current + 1;
      badge.style.display = 'flex';
    }
  }

  clearUnreadBadge() {
    const badge = document.getElementById('chatUnreadBadge');
    if (badge) {
      badge.textContent = '0';
      badge.style.display = 'none';
    }
  }

  playMessageSound() {
    // Simple notification sound
    try {
      const audioContext = new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = audioContext.createOscillator();
      const gainNode = audioContext.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(audioContext.destination);

      oscillator.frequency.value = 600;
      oscillator.type = 'sine';

      gainNode.gain.setValueAtTime(0.1, audioContext.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.08);

      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + 0.08);
    } catch (e) {
      // Silently fail
    }
  }

  // ============================================================
  // STYLES
  // ============================================================

  addStyles() {
    const styles = `
      <style>
        /* Chat Toggle Button */
        .chat-toggle {
          position: fixed;
          bottom: 24px;
          right: 24px;
          width: 56px;
          height: 56px;
          background: linear-gradient(135deg, var(--rose, #e91e63), var(--purple, #9c27b0));
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          box-shadow: 0 4px 20px rgba(233,30,99,0.4);
          transition: all 0.3s;
          z-index: 998;
          color: white;
        }
        .chat-toggle:hover {
          transform: scale(1.1);
          box-shadow: 0 6px 28px rgba(233,30,99,0.6);
        }
        .chat-unread-badge {
          position: absolute;
          top: -4px;
          right: -4px;
          background: var(--warning, #ff9800);
          color: white;
          font-size: 11px;
          font-weight: 700;
          padding: 4px 7px;
          border-radius: 12px;
          min-width: 20px;
          height: 20px;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        /* Chat Panel */
        .chat-panel {
          position: fixed;
          bottom: 24px;
          right: 24px;
          width: 400px;
          max-width: calc(100vw - 48px);
          height: 600px;
          max-height: calc(100vh - 48px);
          background: var(--bg-card, #111);
          border: 1px solid var(--border, #2a2a2a);
          border-radius: 16px;
          box-shadow: 0 8px 40px rgba(0,0,0,0.6);
          z-index: 999;
          display: flex;
          flex-direction: column;
          transform: translateY(calc(100% + 24px));
          opacity: 0;
          pointer-events: none;
          transition: all 0.3s ease;
        }
        .chat-panel.open {
          transform: translateY(0);
          opacity: 1;
          pointer-events: auto;
        }

        /* Chat Header */
        .chat-header {
          padding: 16px 20px;
          border-bottom: 1px solid var(--border, #2a2a2a);
          display: flex;
          justify-content: space-between;
          align-items: center;
        }
        .chat-header-left {
          display: flex;
          flex-direction: column;
          gap: 4px;
        }
        .chat-header h3 {
          margin: 0;
          font-size: 16px;
          font-weight: 700;
        }
        .chat-online-status {
          display: flex;
          align-items: center;
          gap: 6px;
          font-size: 12px;
          color: var(--text-dim, #888);
        }
        .online-dot {
          width: 8px;
          height: 8px;
          background: var(--success, #4caf50);
          border-radius: 50%;
          animation: pulse-online 2s infinite;
        }
        @keyframes pulse-online {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
        .chat-close {
          background: none;
          border: none;
          color: var(--text-dim, #888);
          font-size: 28px;
          cursor: pointer;
          padding: 0;
          width: 32px;
          height: 32px;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 8px;
          transition: all 0.2s;
        }
        .chat-close:hover {
          background: var(--bg-elevated, #1a1a1a);
          color: var(--text, #fff);
        }

        /* Online Users */
        .chat-online-users {
          padding: 12px;
          border-bottom: 1px solid var(--border, #2a2a2a);
          display: flex;
          gap: 8px;
          overflow-x: auto;
          max-height: 80px;
        }
        .chat-online-users::-webkit-scrollbar {
          height: 4px;
        }
        .chat-online-users::-webkit-scrollbar-thumb {
          background: var(--border, #2a2a2a);
          border-radius: 2px;
        }
        .online-user {
          display: flex;
          align-items: center;
          gap: 8px;
          padding: 6px 12px;
          background: var(--bg-elevated, #1a1a1a);
          border-radius: 20px;
          font-size: 12px;
          white-space: nowrap;
        }
        .online-user-avatar {
          width: 24px;
          height: 24px;
          border-radius: 50%;
          background: linear-gradient(135deg, var(--rose, #e91e63), var(--purple, #9c27b0));
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 10px;
          font-weight: 700;
        }
        .online-user-indicator {
          width: 6px;
          height: 6px;
          background: var(--success, #4caf50);
          border-radius: 50%;
        }
        .no-online-users {
          color: var(--text-dim, #888);
          font-size: 12px;
          text-align: center;
          width: 100%;
        }

        /* Messages */
        .chat-messages {
          flex: 1;
          overflow-y: auto;
          padding: 16px;
          display: flex;
          flex-direction: column;
          gap: 8px;
        }
        .chat-messages::-webkit-scrollbar {
          width: 6px;
        }
        .chat-messages::-webkit-scrollbar-thumb {
          background: var(--border, #2a2a2a);
          border-radius: 3px;
        }
        .chat-empty, .chat-loading {
          text-align: center;
          padding: 60px 20px;
          color: var(--text-dim, #888);
        }
        .chat-empty svg {
          opacity: 0.3;
          margin-bottom: 16px;
        }

        /* Message */
        .chat-timestamp {
          text-align: center;
          font-size: 11px;
          color: var(--text-muted, #555);
          margin: 16px 0 8px;
        }
        .chat-message {
          display: flex;
          gap: 8px;
          align-items: flex-end;
        }
        .chat-message.own {
          flex-direction: row-reverse;
        }
        .chat-message-avatar {
          width: 32px;
          height: 32px;
          border-radius: 50%;
          background: linear-gradient(135deg, var(--rose, #e91e63), var(--purple, #9c27b0));
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 11px;
          font-weight: 700;
          flex-shrink: 0;
          color: white;
        }
        .chat-message-content {
          display: flex;
          flex-direction: column;
          gap: 2px;
          max-width: 70%;
        }
        .chat-message.own .chat-message-content {
          align-items: flex-end;
        }
        .chat-message-sender {
          font-size: 11px;
          font-weight: 600;
          color: var(--text-dim, #888);
          padding: 0 12px;
        }
        .chat-message-bubble {
          background: var(--bg-elevated, #1a1a1a);
          padding: 10px 14px;
          border-radius: 16px;
          font-size: 14px;
          line-height: 1.4;
          word-wrap: break-word;
        }
        .chat-message.own .chat-message-bubble {
          background: linear-gradient(135deg, var(--rose, #e91e63), var(--purple, #9c27b0));
          color: white;
        }
        .chat-message-time {
          font-size: 10px;
          color: var(--text-muted, #555);
          padding: 0 12px;
        }
        .chat-message-edited {
          font-size: 10px;
          color: var(--text-muted, #555);
          margin-left: 6px;
          font-style: italic;
        }
        .chat-mention {
          color: var(--gold, #d4af37);
          font-weight: 600;
        }

        /* Input */
        .chat-input-container {
          padding: 12px;
          border-top: 1px solid var(--border, #2a2a2a);
          display: flex;
          gap: 8px;
          align-items: flex-end;
        }
        .chat-input {
          flex: 1;
          background: var(--bg-elevated, #1a1a1a);
          border: 1px solid var(--border, #2a2a2a);
          border-radius: 12px;
          padding: 10px 14px;
          color: var(--text, #fff);
          font-family: inherit;
          font-size: 14px;
          resize: none;
          max-height: 120px;
          overflow-y: auto;
        }
        .chat-input:focus {
          outline: none;
          border-color: var(--gold, #d4af37);
        }
        .chat-input::-webkit-scrollbar {
          width: 4px;
        }
        .chat-input::-webkit-scrollbar-thumb {
          background: var(--border, #2a2a2a);
          border-radius: 2px;
        }
        .chat-send {
          width: 40px;
          height: 40px;
          background: linear-gradient(135deg, var(--rose, #e91e63), var(--purple, #9c27b0));
          border: none;
          border-radius: 10px;
          color: white;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: all 0.2s;
          flex-shrink: 0;
        }
        .chat-send:hover {
          transform: scale(1.05);
        }
        .chat-send:active {
          transform: scale(0.95);
        }
      </style>
    `;
    document.head.insertAdjacentHTML('beforeend', styles);
  }
}

// Export
window.ChatUI = ChatUI;
console.log('✅ Chat UI module loaded');
