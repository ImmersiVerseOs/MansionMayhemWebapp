/**
 * NOTIFICATION UI COMPONENT
 * =========================
 * Handles notification display, toast popups, and notification center
 */

class NotificationUI {
  constructor(realtimeManager) {
    this.realtime = realtimeManager;
    this.unreadCount = 0;
    this.notifications = [];
    this.isOpen = false;

    this.init();
  }

  async init() {
    // Create notification UI elements
    this.createNotificationBell();
    this.createNotificationPanel();
    this.createToastContainer();

    // Load initial notifications
    await this.loadNotifications();

    // Subscribe to real-time notifications
    this.realtime.subscribeToNotifications((notification) => {
      this.handleNewNotification(notification);
    });

    // Request browser notification permission
    this.realtime.requestNotificationPermission();
  }

  // ============================================================
  // UI CREATION
  // ============================================================

  createNotificationBell() {
    const bellHTML = `
      <div class="notification-bell" id="notificationBell">
        <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
          <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
        </svg>
        <span class="notification-badge" id="notificationBadge" style="display:none;">0</span>
      </div>
    `;

    // Find header actions or create notification container
    let container = document.querySelector('.header-actions');
    if (!container) {
      container = document.querySelector('.header');
      if (container) {
        const actionsDiv = document.createElement('div');
        actionsDiv.className = 'header-actions';
        container.appendChild(actionsDiv);
        container = actionsDiv;
      }
    }

    if (container) {
      container.insertAdjacentHTML('beforeend', bellHTML);
      document.getElementById('notificationBell').addEventListener('click', () => {
        this.togglePanel();
      });
    }

    // Add styles
    this.addBellStyles();
  }

  createNotificationPanel() {
    const panelHTML = `
      <div class="notification-panel" id="notificationPanel">
        <div class="notification-panel-header">
          <h3>Notifications</h3>
          <button class="btn-mark-all-read" id="markAllRead">Mark all read</button>
        </div>
        <div class="notification-panel-body" id="notificationPanelBody">
          <div class="notification-loading">Loading...</div>
        </div>
      </div>
      <div class="notification-overlay" id="notificationOverlay"></div>
    `;

    document.body.insertAdjacentHTML('beforeend', panelHTML);

    // Event listeners
    document.getElementById('notificationOverlay').addEventListener('click', () => {
      this.closePanel();
    });

    document.getElementById('markAllRead').addEventListener('click', async () => {
      await this.markAllAsRead();
    });

    // Add styles
    this.addPanelStyles();
  }

  createToastContainer() {
    const toastHTML = `<div class="toast-container" id="toastContainer"></div>`;
    document.body.insertAdjacentHTML('beforeend', toastHTML);
    this.addToastStyles();
  }

  // ============================================================
  // NOTIFICATION HANDLING
  // ============================================================

  async loadNotifications() {
    this.notifications = await this.realtime.getNotifications(50);
    this.unreadCount = await this.realtime.getUnreadCount();

    this.updateBadge();
    this.renderNotifications();
  }

  handleNewNotification(notification) {
    // Add to list
    this.notifications.unshift(notification);
    this.unreadCount++;

    // Update UI
    this.updateBadge();
    if (this.isOpen) {
      this.renderNotifications();
    }

    // Show toast
    this.showToast(notification);

    // Play sound
    this.playNotificationSound();
  }

  updateBadge() {
    const badge = document.getElementById('notificationBadge');
    if (badge) {
      if (this.unreadCount > 0) {
        badge.textContent = this.unreadCount > 99 ? '99+' : this.unreadCount;
        badge.style.display = 'flex';
      } else {
        badge.style.display = 'none';
      }
    }
  }

  renderNotifications() {
    const body = document.getElementById('notificationPanelBody');
    if (!body) return;

    if (this.notifications.length === 0) {
      body.innerHTML = `
        <div class="notification-empty">
          <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
            <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
          </svg>
          <p>No notifications yet</p>
        </div>
      `;
      return;
    }

    const html = this.notifications.map(n => this.renderNotification(n)).join('');
    body.innerHTML = html;

    // Add click handlers
    this.notifications.forEach(n => {
      const el = document.getElementById(`notification-${n.id}`);
      if (el) {
        el.addEventListener('click', () => this.handleNotificationClick(n));
      }
    });
  }

  renderNotification(notification) {
    const icon = this.getNotificationIcon(notification.type);
    const timeAgo = this.getTimeAgo(notification.created_at);

    return `
      <div class="notification-item ${notification.read ? 'read' : 'unread'}"
           id="notification-${notification.id}">
        <div class="notification-icon ${notification.type}">${icon}</div>
        <div class="notification-content">
          <div class="notification-title">${notification.title}</div>
          <div class="notification-message">${notification.message}</div>
          <div class="notification-time">${timeAgo}</div>
        </div>
      </div>
    `;
  }

  getNotificationIcon(type) {
    const icons = {
      new_scenario: '🎬',
      vote_result: '🗳️',
      game_update: '🎮',
      system: '⚙️',
      chat_mention: '💬'
    };
    return icons[type] || '🔔';
  }

  async handleNotificationClick(notification) {
    // Mark as read
    if (!notification.read) {
      await this.realtime.markAsRead(notification.id);
      notification.read = true;
      this.unreadCount--;
      this.updateBadge();
      this.renderNotifications();
    }

    // Navigate to link if provided
    if (notification.link) {
      window.location.href = notification.link;
    }

    this.closePanel();
  }

  async markAllAsRead() {
    await this.realtime.markAllAsRead();
    this.notifications.forEach(n => n.read = true);
    this.unreadCount = 0;
    this.updateBadge();
    this.renderNotifications();
  }

  // ============================================================
  // TOAST NOTIFICATIONS
  // ============================================================

  showToast(notification) {
    const container = document.getElementById('toastContainer');
    if (!container) return;

    const icon = this.getNotificationIcon(notification.type);
    const toastId = `toast-${Date.now()}`;

    const toastHTML = `
      <div class="toast" id="${toastId}">
        <div class="toast-icon">${icon}</div>
        <div class="toast-content">
          <div class="toast-title">${notification.title}</div>
          <div class="toast-message">${notification.message}</div>
        </div>
        <button class="toast-close" onclick="document.getElementById('${toastId}').remove()">×</button>
      </div>
    `;

    container.insertAdjacentHTML('beforeend', toastHTML);

    // Auto remove after 5 seconds
    setTimeout(() => {
      const toast = document.getElementById(toastId);
      if (toast) {
        toast.classList.add('fade-out');
        setTimeout(() => toast.remove(), 300);
      }
    }, 5000);
  }

  // ============================================================
  // PANEL MANAGEMENT
  // ============================================================

  togglePanel() {
    if (this.isOpen) {
      this.closePanel();
    } else {
      this.openPanel();
    }
  }

  openPanel() {
    const panel = document.getElementById('notificationPanel');
    const overlay = document.getElementById('notificationOverlay');

    if (panel && overlay) {
      panel.classList.add('open');
      overlay.classList.add('open');
      this.isOpen = true;
      this.renderNotifications();
    }
  }

  closePanel() {
    const panel = document.getElementById('notificationPanel');
    const overlay = document.getElementById('notificationOverlay');

    if (panel && overlay) {
      panel.classList.remove('open');
      overlay.classList.remove('open');
      this.isOpen = false;
    }
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  getTimeAgo(timestamp) {
    const seconds = Math.floor((new Date() - new Date(timestamp)) / 1000);

    if (seconds < 60) return 'Just now';
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
    if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`;
    return new Date(timestamp).toLocaleDateString();
  }

  playNotificationSound() {
    // Simple beep sound using Web Audio API
    try {
      const audioContext = new (window.AudioContext || window.webkitAudioContext)();
      const oscillator = audioContext.createOscillator();
      const gainNode = audioContext.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(audioContext.destination);

      oscillator.frequency.value = 800;
      oscillator.type = 'sine';

      gainNode.gain.setValueAtTime(0.1, audioContext.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.1);

      oscillator.start(audioContext.currentTime);
      oscillator.stop(audioContext.currentTime + 0.1);
    } catch (e) {
      // Silently fail if audio not supported
    }
  }

  // ============================================================
  // STYLES
  // ============================================================

  addBellStyles() {
    const styles = `
      <style>
        .notification-bell {
          position: relative;
          cursor: pointer;
          padding: 8px;
          border-radius: 8px;
          transition: background 0.2s;
          color: var(--text-dim, #888);
        }
        .notification-bell:hover {
          background: var(--bg-elevated, #1a1a1a);
          color: var(--text, #fff);
        }
        .notification-badge {
          position: absolute;
          top: 4px;
          right: 4px;
          background: var(--rose, #e91e63);
          color: white;
          font-size: 10px;
          font-weight: 700;
          padding: 2px 5px;
          border-radius: 10px;
          min-width: 16px;
          height: 16px;
          display: flex;
          align-items: center;
          justify-content: center;
        }
      </style>
    `;
    document.head.insertAdjacentHTML('beforeend', styles);
  }

  addPanelStyles() {
    const styles = `
      <style>
        .notification-overlay {
          position: fixed;
          inset: 0;
          background: rgba(0,0,0,0.5);
          backdrop-filter: blur(4px);
          z-index: 999;
          opacity: 0;
          pointer-events: none;
          transition: opacity 0.3s;
        }
        .notification-overlay.open {
          opacity: 1;
          pointer-events: auto;
        }
        .notification-panel {
          position: fixed;
          top: 0;
          right: 0;
          width: 400px;
          max-width: 100%;
          height: 100vh;
          background: var(--bg-card, #111);
          border-left: 1px solid var(--border, #2a2a2a);
          z-index: 1000;
          transform: translateX(100%);
          transition: transform 0.3s;
          display: flex;
          flex-direction: column;
        }
        .notification-panel.open {
          transform: translateX(0);
        }
        .notification-panel-header {
          padding: 20px;
          border-bottom: 1px solid var(--border, #2a2a2a);
          display: flex;
          justify-content: space-between;
          align-items: center;
        }
        .notification-panel-header h3 {
          margin: 0;
          font-size: 18px;
          font-weight: 700;
        }
        .btn-mark-all-read {
          background: none;
          border: 1px solid var(--border, #2a2a2a);
          color: var(--text-dim, #888);
          padding: 6px 12px;
          border-radius: 6px;
          font-size: 11px;
          cursor: pointer;
          transition: all 0.2s;
        }
        .btn-mark-all-read:hover {
          border-color: var(--gold, #d4af37);
          color: var(--gold, #d4af37);
        }
        .notification-panel-body {
          flex: 1;
          overflow-y: auto;
          padding: 8px;
        }
        .notification-item {
          display: flex;
          gap: 12px;
          padding: 12px;
          border-radius: 8px;
          margin-bottom: 8px;
          cursor: pointer;
          transition: background 0.2s;
          border: 1px solid transparent;
        }
        .notification-item:hover {
          background: var(--bg-elevated, #1a1a1a);
        }
        .notification-item.unread {
          background: rgba(212,175,55,0.05);
          border-color: var(--gold, #d4af37);
        }
        .notification-icon {
          font-size: 24px;
          flex-shrink: 0;
        }
        .notification-content {
          flex: 1;
          min-width: 0;
        }
        .notification-title {
          font-weight: 600;
          font-size: 14px;
          margin-bottom: 4px;
        }
        .notification-message {
          font-size: 13px;
          color: var(--text-dim, #888);
          margin-bottom: 4px;
          overflow: hidden;
          text-overflow: ellipsis;
          display: -webkit-box;
          -webkit-line-clamp: 2;
          -webkit-box-orient: vertical;
        }
        .notification-time {
          font-size: 11px;
          color: var(--text-muted, #555);
        }
        .notification-empty {
          text-align: center;
          padding: 60px 20px;
          color: var(--text-dim, #888);
        }
        .notification-empty svg {
          opacity: 0.3;
          margin-bottom: 16px;
        }
        .notification-loading {
          text-align: center;
          padding: 40px 20px;
          color: var(--text-dim, #888);
        }
      </style>
    `;
    document.head.insertAdjacentHTML('beforeend', styles);
  }

  addToastStyles() {
    const styles = `
      <style>
        .toast-container {
          position: fixed;
          top: 80px;
          right: 20px;
          z-index: 10000;
          display: flex;
          flex-direction: column;
          gap: 12px;
          max-width: 400px;
        }
        .toast {
          background: var(--bg-card, #111);
          border: 1px solid var(--border, #2a2a2a);
          border-radius: 12px;
          padding: 16px;
          display: flex;
          gap: 12px;
          align-items: start;
          box-shadow: 0 8px 32px rgba(0,0,0,0.4);
          animation: slideIn 0.3s ease;
        }
        @keyframes slideIn {
          from {
            transform: translateX(400px);
            opacity: 0;
          }
          to {
            transform: translateX(0);
            opacity: 1;
          }
        }
        .toast.fade-out {
          animation: fadeOut 0.3s ease;
        }
        @keyframes fadeOut {
          to {
            opacity: 0;
            transform: translateX(400px);
          }
        }
        .toast-icon {
          font-size: 24px;
          flex-shrink: 0;
        }
        .toast-content {
          flex: 1;
          min-width: 0;
        }
        .toast-title {
          font-weight: 600;
          font-size: 14px;
          margin-bottom: 4px;
        }
        .toast-message {
          font-size: 13px;
          color: var(--text-dim, #888);
        }
        .toast-close {
          background: none;
          border: none;
          color: var(--text-dim, #888);
          font-size: 20px;
          cursor: pointer;
          padding: 0;
          width: 24px;
          height: 24px;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 4px;
          transition: all 0.2s;
          flex-shrink: 0;
        }
        .toast-close:hover {
          background: var(--bg-elevated, #1a1a1a);
          color: var(--text, #fff);
        }
      </style>
    `;
    document.head.insertAdjacentHTML('beforeend', styles);
  }
}

// Export
window.NotificationUI = NotificationUI;
console.log('✅ Notification UI module loaded');
