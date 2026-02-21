// =====================================================
// NAVIGATION MODULE
// =====================================================
// Handles persistent navigation bar, notifications,
// and role-based navigation across all pages
// =====================================================

let currentUser = null;
let currentProfile = null;
let notificationInterval = null;

// Initialize navigation on page load
async function initNavigation() {
  try {
    console.log('🔍 Navigation.js: Checking auth...');

    // Wait for supabaseClient to be available
    let attempts = 0;
    while (!window.supabaseClient && attempts < 50) {
      await new Promise(resolve => setTimeout(resolve, 100));
      attempts++;
    }

    if (!window.supabaseClient) {
      console.error('❌ Navigation.js: supabaseClient not available after 5 seconds');
      return;
    }

    // Get current user
    const { data: { user }, error: authError } = await window.supabaseClient.auth.getUser();

    console.log('🔍 Navigation.js auth result:', { user: user?.email, error: authError?.message });

    if (authError || !user) {
      console.log('❌ Navigation.js: No user found, redirecting to landing');
      // Not authenticated - redirect to landing page unless already there
      if (!window.location.pathname.includes('index.html') && window.location.pathname !== '/') {
        window.location.href = '/index.html';
      }
      return;
    }

    console.log('✅ Navigation.js: User authenticated:', user.email);

    currentUser = user;

    // Redirect authenticated users from landing to dashboard
    const currentPath = window.location.pathname;
    if (currentPath === '/' || currentPath === '/index.html') {
      console.log('📍 Redirecting authenticated user to dashboard');
      window.location.href = '/pages/player-dashboard.html';
      return;
    }

    // Get user profile and role
    const { data: profile, error: profileError } = await window.supabaseClient
      .from('profiles')
      .select('display_name, role, avatar_url')
      .eq('id', user.id)
      .maybeSingle();

    if (profileError) {
      console.error('Error loading profile:', profileError);
      return;
    }

    currentProfile = profile;

    // Update nav UI
    updateNavUI();

    // Load initial notifications count
    await loadNotificationCount();

    // Subscribe to real-time notification updates
    // Replaces polling (every 30s) with instant updates via Supabase realtime
    if (window.RealtimeManager) {
      const realtimeManager = new window.RealtimeManager(window.supabaseClient);
      realtimeManager.subscribeToNotifications((payload) => {
        console.log('📬 New notification received:', payload);
        // Reload count when new notification arrives
        loadNotificationCount();
      });
      console.log('✅ Real-time notifications enabled');
    } else {
      // Fallback to polling if realtime not available
      console.warn('⚠️ RealtimeManager not available, using polling fallback');
      notificationInterval = setInterval(loadNotificationCount, 30000);
    }

    // Highlight current page
    highlightCurrentPage();

    // Set up event listeners
    setupEventListeners();

  } catch (error) {
    console.error('Navigation initialization error:', error);
  }
}

function updateNavUI() {
  if (!currentProfile) return;

  // Update user info
  const userNameEl = document.getElementById('userName');
  const userAvatarEl = document.getElementById('userAvatar');

  if (userNameEl) {
    userNameEl.textContent = currentProfile.display_name || 'User';
  }

  if (userAvatarEl) {
    userAvatarEl.src = currentProfile.avatar_url || '/assets/default-avatar.png';
  }

  // Show/hide role-specific links
  const isAdmin = currentProfile.role === 'admin';
  const isDirector = currentProfile.subscription_tier === 'premium' ||
                     currentProfile.subscription_tier === 'admin';

  // Show admin links
  document.querySelectorAll('.admin-only').forEach(el => {
    el.style.display = isAdmin ? '' : 'none';
  });

  // Show director links
  document.querySelectorAll('.director-only').forEach(el => {
    el.style.display = isDirector ? '' : 'none';
  });

  // Show cast member links (anyone who's not just a viewer)
  const isCastMember = true; // Everyone can be a cast member
  document.querySelectorAll('.cast-only').forEach(el => {
    el.style.display = isCastMember ? '' : 'none';
  });
}

async function loadNotificationCount() {
  try {
    const { count, error } = await window.supabaseClient
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .is('read_at', null);

    if (error) {
      console.error('Error loading notification count:', error);
      return;
    }

    const badge = document.getElementById('notifCount');
    if (badge) {
      if (count > 0) {
        badge.textContent = count > 9 ? '9+' : count;
        badge.style.display = 'inline-block';
      } else {
        badge.style.display = 'none';
      }
    }
  } catch (error) {
    console.error('Error loading notifications:', error);
  }
}

function highlightCurrentPage() {
  const currentPath = window.location.pathname;

  document.querySelectorAll('.nav-link').forEach(link => {
    const linkPath = link.getAttribute('href');

    // Remove active class from all
    link.classList.remove('active');

    // Add active to current page
    if (linkPath && (currentPath === linkPath || currentPath.endsWith(linkPath))) {
      link.classList.add('active');
    }
  });
}

function setupEventListeners() {
  // Notifications button
  const notifBtn = document.getElementById('notificationsBtn');
  if (notifBtn) {
    notifBtn.addEventListener('click', showNotifications);
  }

  // User menu button
  const userMenuBtn = document.getElementById('userMenuBtn');
  if (userMenuBtn) {
    userMenuBtn.addEventListener('click', toggleUserMenu);
  }

  // Mobile menu toggle
  const mobileToggle = document.getElementById('mobileMenuToggle');
  if (mobileToggle) {
    mobileToggle.addEventListener('click', toggleMobileMenu);
  }

  // Close dropdowns when clicking outside
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.nav-notifications') && !e.target.closest('.notifications-dropdown')) {
      closeNotificationsDropdown();
    }
    if (!e.target.closest('.nav-user') && !e.target.closest('.user-menu-dropdown')) {
      closeUserMenu();
    }
  });
}

async function showNotifications() {
  const dropdown = document.getElementById('notificationsDropdown');

  if (dropdown && dropdown.style.display === 'block') {
    closeNotificationsDropdown();
    return;
  }

  try {
    // Load recent notifications
    const { data: notifications, error } = await window.supabaseClient
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(10);

    if (error) {
      console.error('Error loading notifications:', error);
      return;
    }

    // Build dropdown HTML
    let html = '<div class="notifications-dropdown" id="notificationsDropdown">';
    html += '<div class="notifications-header">';
    html += '<h3>Notifications</h3>';
    html += '<button class="mark-all-read-btn" onclick="markAllNotificationsRead()">Mark all read</button>';
    html += '</div>';
    html += '<div class="notifications-list">';

    if (notifications.length === 0) {
      html += '<div class="notification-item empty">No notifications</div>';
    } else {
      notifications.forEach(notif => {
        const isUnread = !notif.read_at;
        const timeAgo = getTimeAgo(notif.created_at);

        html += `<div class="notification-item ${isUnread ? 'unread' : ''}" onclick="handleNotificationClick('${notif.id}', '${notif.action_url || ''}')">`;
        html += `<div class="notification-icon">${getNotificationIcon(notif.type)}</div>`;
        html += `<div class="notification-content">`;
        html += `<div class="notification-title">${notif.title}</div>`;
        html += `<div class="notification-message">${notif.message}</div>`;
        html += `<div class="notification-time">${timeAgo}</div>`;
        html += `</div>`;
        if (isUnread) {
          html += `<div class="notification-badge">●</div>`;
        }
        html += `</div>`;
      });
    }

    html += '</div>';
    html += '<div class="notifications-footer">';
    html += '<a href="/pages/notifications.html">View all notifications</a>';
    html += '</div>';
    html += '</div>';

    // Insert dropdown
    const container = document.querySelector('.nav-notifications');
    if (container) {
      // Remove existing dropdown
      const existing = document.getElementById('notificationsDropdown');
      if (existing) existing.remove();

      container.insertAdjacentHTML('beforeend', html);
    }

  } catch (error) {
    console.error('Error showing notifications:', error);
  }
}

function closeNotificationsDropdown() {
  const dropdown = document.getElementById('notificationsDropdown');
  if (dropdown) {
    dropdown.remove();
  }
}

async function handleNotificationClick(notificationId, actionUrl) {
  // Mark as read
  await markNotificationRead(notificationId);

  // Navigate to action URL if provided
  if (actionUrl) {
    window.location.href = actionUrl;
  }

  closeNotificationsDropdown();
}

async function markNotificationRead(notificationId) {
  try {
    const { error } = await window.supabaseClient
      .from('notifications')
      .update({ read_at: new Date().toISOString() })
      .eq('id', notificationId);

    if (error) {
      console.error('Error marking notification as read:', error);
    }

    // Reload count
    await loadNotificationCount();
  } catch (error) {
    console.error('Error marking notification as read:', error);
  }
}

async function markAllNotificationsRead() {
  try {
    const { error } = await window.supabaseClient
      .from('notifications')
      .update({ read_at: new Date().toISOString() })
      .is('read_at', null);

    if (error) {
      console.error('Error marking all notifications as read:', error);
      return;
    }

    // Reload notifications dropdown
    closeNotificationsDropdown();
    await loadNotificationCount();

    showToast('All notifications marked as read');
  } catch (error) {
    console.error('Error marking all notifications as read:', error);
  }
}

function toggleUserMenu() {
  const dropdown = document.getElementById('userMenuDropdown');

  if (dropdown && dropdown.style.display === 'block') {
    closeUserMenu();
    return;
  }

  // Build user menu HTML
  let html = '<div class="user-menu-dropdown" id="userMenuDropdown">';
  html += `<div class="user-menu-header">`;
  html += `<img src="${currentProfile?.avatar_url || '/assets/default-avatar.png'}" class="user-menu-avatar">`;
  html += `<div class="user-menu-info">`;
  html += `<div class="user-menu-name">${currentProfile?.display_name || 'User'}</div>`;
  html += `<div class="user-menu-role">${formatRole(currentProfile?.role)}</div>`;
  html += `</div>`;
  html += `</div>`;
  html += `<div class="user-menu-links">`;
  html += `<a href="/pages/player-dashboard.html" class="user-menu-link">🏠 Dashboard</a>`;
  html += `<a href="/pages/profile.html" class="user-menu-link">👤 My Profile</a>`;
  html += `<a href="/pages/settings.html" class="user-menu-link">⚙️ Settings</a>`;
  html += `<hr class="user-menu-divider">`;
  html += `<a href="#" onclick="handleLogout()" class="user-menu-link">🚪 Logout</a>`;
  html += `</div>`;
  html += `</div>`;

  const container = document.querySelector('.nav-user');
  if (container) {
    const existing = document.getElementById('userMenuDropdown');
    if (existing) existing.remove();

    container.insertAdjacentHTML('beforeend', html);
  }
}

function closeUserMenu() {
  const dropdown = document.getElementById('userMenuDropdown');
  if (dropdown) {
    dropdown.remove();
  }
}

async function handleLogout() {
  try {
    await window.supabaseClient.auth.signOut();
    window.location.href = '/index.html';
  } catch (error) {
    console.error('Logout error:', error);
  }
}

function toggleMobileMenu() {
  const nav = document.querySelector('.mm-main-nav');
  if (nav) {
    nav.classList.toggle('mobile-open');
  }
}

// Helper functions
function getNotificationIcon(type) {
  const icons = {
    new_scenario: '📢',
    scenario_deadline: '⏰',
    elimination: '❌',
    episode_published: '🎬',
    vote_opened: '🗳️',
    game_update: '🎮',
    system: 'ℹ️'
  };
  return icons[type] || '📬';
}

function getTimeAgo(timestamp) {
  const now = new Date();
  const time = new Date(timestamp);
  const seconds = Math.floor((now - time) / 1000);

  if (seconds < 60) return 'Just now';
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
  if (seconds < 604800) return `${Math.floor(seconds / 86400)}d ago`;
  return time.toLocaleDateString();
}

function formatRole(role) {
  const roles = {
    admin: 'Administrator',
    director: 'Director',
    cast: 'Cast Member',
    viewer: 'Viewer'
  };
  return roles[role] || 'User';
}

function showToast(message, type = 'success') {
  // Simple toast notification
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);

  setTimeout(() => {
    toast.classList.add('show');
  }, 100);

  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

/**
 * Render global navigation HTML
 * @param {string} userRole - User's role (admin, director, cast, viewer)
 * @param {object} options - Additional options (showNotifications, currentPage, etc.)
 * @returns {string} HTML string for navigation
 */
function renderGlobalNav(userRole = 'cast', options = {}) {
  const {
    showNotifications = true,
    showUserMenu = true,
    currentPage = '',
    notificationCount = 0
  } = options;

  const isAdmin = userRole === 'admin';
  const isDirector = userRole === 'director';
  const userName = currentProfile?.display_name || currentUser?.email?.split('@')[0] || 'User';

  return `
    <nav class="global-nav" style="
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      z-index: 1000;
      background: rgba(10, 10, 10, 0.95);
      backdrop-filter: blur(10px);
      border-bottom: 2px solid rgba(212, 175, 55, 0.2);
      padding: 1rem 2rem;
    ">
      <div style="
        max-width: 1800px;
        margin: 0 auto;
        display: flex;
        justify-content: space-between;
        align-items: center;
      ">
        <!-- Logo -->
        <a href="/index.html" style="
          display: flex;
          align-items: center;
          gap: 0.75rem;
          text-decoration: none;
          color: #d4af37;
          font-size: 1.5rem;
          font-weight: 800;
        ">
          <span style="font-size: 2rem;">🏰</span>
          <span>MANSION MAYHEM</span>
        </a>

        <!-- Center Nav Links -->
        <div style="display: flex; gap: 2rem; align-items: center;">
          <a href="/pages/voice-feed.html" class="nav-link" style="color: rgba(255,255,255,0.8); text-decoration: none; font-weight: 600; transition: color 0.3s;">
            🎙️ Voice Feed
          </a>
          <a href="/pages/gallery.html" class="nav-link" style="color: rgba(255,255,255,0.8); text-decoration: none; font-weight: 600; transition: color 0.3s;">
            🎬 Gallery
          </a>
          <a href="/pages/cast-roster.html" class="nav-link" style="color: rgba(255,255,255,0.8); text-decoration: none; font-weight: 600; transition: color 0.3s;">
            🎭 Cast
          </a>
          <a href="/pages/leaderboard.html" class="nav-link" style="color: rgba(255,255,255,0.8); text-decoration: none; font-weight: 600; transition: color 0.3s;">
            🏆 Leaderboard
          </a>
          ${isAdmin ? `
            <a href="/pages/admin-dashboard.html" class="nav-link admin-only" style="color: #d4af37; text-decoration: none; font-weight: 600;">
              ⚙️ Admin
            </a>
          ` : ''}
        </div>

        <!-- Right Side: Notifications & User Menu -->
        <div style="display: flex; gap: 1.5rem; align-items: center;">
          ${showNotifications ? `
            <button class="notifications-btn" onclick="showNotifications()" style="
              position: relative;
              background: transparent;
              border: 2px solid rgba(255,255,255,0.1);
              border-radius: 50%;
              width: 44px;
              height: 44px;
              display: flex;
              align-items: center;
              justify-content: center;
              cursor: pointer;
              transition: all 0.3s;
              font-size: 1.25rem;
            ">
              🔔
              ${notificationCount > 0 ? `
                <span class="notification-badge" style="
                  position: absolute;
                  top: -4px;
                  right: -4px;
                  background: #e74c3c;
                  color: white;
                  border-radius: 50%;
                  width: 20px;
                  height: 20px;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  font-size: 11px;
                  font-weight: 700;
                ">${notificationCount}</span>
              ` : ''}
            </button>
          ` : ''}

          ${showUserMenu ? `
            <div class="user-menu-dropdown" style="position: relative;">
              <button onclick="toggleUserMenu()" style="
                display: flex;
                align-items: center;
                gap: 0.75rem;
                background: transparent;
                border: 2px solid rgba(212, 175, 55, 0.3);
                border-radius: 50px;
                padding: 0.5rem 1rem;
                cursor: pointer;
                transition: all 0.3s;
                color: white;
                font-weight: 600;
              ">
                <div style="
                  width: 32px;
                  height: 32px;
                  border-radius: 50%;
                  background: linear-gradient(135deg, #8b5cf6, #d4af37);
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  font-weight: 700;
                ">${userName.charAt(0).toUpperCase()}</div>
                <span>${userName}</span>
              </button>
            </div>
          ` : ''}
        </div>
      </div>
    </nav>
  `;
}

/**
 * Get the correct route for a game based on user role
 * @param {object} game - Game object with status, stage, etc.
 * @param {string} userRole - User's role
 * @returns {string} URL to navigate to
 */
function getGameRoute(game, userRole) {
  if (!game) return '/pages/player-dashboard.html';

  // Directors and admins go to director console
  if (userRole === 'director' || userRole === 'admin') {
    return `/director-console.html?game=${game.id}`;
  }

  // Cast members route based on game stage
  const stage = game.current_stage || game.mm_game_stages?.current_stage || 'lobby';
  const status = game.status;

  if (status === 'completed') {
    return `/pages/results.html?game=${game.id}`;
  }

  switch (stage) {
    case 'lobby':
    case 'pre_game':
      return `/lobby-dashboard.html?game=${game.id}`;
    case 'introductions':
      return `/voice-introduction.html?game=${game.id}`;
    case 'scenarios':
    case 'active':
      return `/pages/cast-portal.html?game=${game.id}`;
    case 'voting':
      return `/voting.html?game=${game.id}`;
    case 'episodes':
    case 'episode_viewing':
      return `/pages/gallery.html?game=${game.id}`;
    case 'results':
      return `/pages/results.html?game=${game.id}`;
    default:
      return `/pages/cast-portal.html?game=${game.id}`;
  }
}

/**
 * Update notification badge count
 * @param {number} count - Number of unread notifications
 */
function updateNotificationBadge(count) {
  const badge = document.querySelector('.notification-badge');

  if (count > 0) {
    if (badge) {
      badge.textContent = count;
      badge.style.display = 'flex';
    } else {
      // Create badge if it doesn't exist
      const notifBtn = document.querySelector('.notifications-btn');
      if (notifBtn) {
        const newBadge = document.createElement('span');
        newBadge.className = 'notification-badge';
        newBadge.textContent = count;
        newBadge.style.cssText = `
          position: absolute;
          top: -4px;
          right: -4px;
          background: #e74c3c;
          color: white;
          border-radius: 50%;
          width: 20px;
          height: 20px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 11px;
          font-weight: 700;
        `;
        notifBtn.appendChild(newBadge);
      }
    }
  } else {
    if (badge) {
      badge.style.display = 'none';
    }
  }
}

/**
 * Initialize phase-aware routing (uses phase-router.js)
 * Call this from pages that need automatic phase-based routing
 */
async function initPhaseAwareRouting(expectedPage, gameId) {
  try {
    // Import phase router if available
    if (window.phaseRouter) {
      await window.phaseRouter.initPhaseAwareRouting(expectedPage, gameId);
    }
  } catch (error) {
    console.error('Phase-aware routing error:', error);
  }
}

// Export functions for use in other modules
window.navigationModule = {
  renderGlobalNav,
  getGameRoute,
  updateNotificationBadge,
  initPhaseAwareRouting,
  updateNavUI,
  showToast
};

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
  if (notificationInterval) {
    clearInterval(notificationInterval);
  }
});

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initNavigation);
} else {
  initNavigation();
}
