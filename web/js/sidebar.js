/**
 * Mansion Mayhem — Desktop Sidebar
 * Auto-injects persistent sidebar nav into any page with class="page"
 * Call initSidebar(activePage, user) after auth
 */

export function renderSidebar(activePage, user, gameId) {
  const displayName = user?.user_metadata?.display_name || user?.email?.split('@')[0] || 'Player';
  const initial = displayName[0]?.toUpperCase() || '?';

  const links = [
    { id: 'lobby', icon: '🏠', text: 'Lobby', href: '/pages/lobby.html' },
    { id: 'drama', icon: '🔥', text: 'Drama Chat', href: gameId ? `/pages/drama-chat.html?game=${gameId}` : '/pages/drama-chat.html' },
    { id: 'alliances', icon: '🤝', text: 'Alliances', href: gameId ? `/pages/alliance-room.html?game=${gameId}` : '/pages/alliance-room.html' },
    { id: 'game', icon: '⚔️', text: 'Episode', href: gameId ? `/pages/episode-play.html?game=${gameId}` : '#', badge: gameId ? 'LIVE' : null },
    { divider: true },
    { id: 'profile', icon: '👤', text: 'Profile', href: '/pages/profile.html' },
    { id: 'leaderboard', icon: '🏆', text: 'Leaderboard', href: '/pages/leaderboard.html' },
    { id: 'rules', icon: '📖', text: 'How to Play', href: '/pages/how-to-play.html' },
  ];

  const html = `
    <aside class="sidebar" id="sidebar">
      <div class="sidebar-brand">
        <span class="sidebar-brand-icon">👑</span>
        <span class="sidebar-brand-text fire-text">Mansion Mayhem</span>
      </div>
      <nav class="sidebar-nav">
        ${links.map(l => {
          if (l.divider) return '<div class="sidebar-divider"></div>';
          const active = l.id === activePage ? ' on' : '';
          const badge = l.badge ? `<span class="sidebar-badge pill-pink">${l.badge}</span>` : '';
          return `<a href="${l.href}" class="sidebar-link${active}"><span class="sidebar-link-icon">${l.icon}</span><span class="sidebar-link-text">${l.text}</span>${badge}</a>`;
        }).join('')}
      </nav>
      <div class="sidebar-footer">
        <div class="sidebar-user">
          <div class="sidebar-user-av av-pink">${initial}</div>
          <span class="sidebar-user-name">${displayName}</span>
          <button class="sidebar-user-out" onclick="window.__signOut()">Sign Out</button>
        </div>
      </div>
    </aside>
  `;

  // Inject at start of .page
  const page = document.querySelector('.page');
  if (page) page.insertAdjacentHTML('afterbegin', html);
}

export async function initSidebar(activePage, userModule) {
  const user = await userModule.getUser();
  if (!user) return;

  // Try to find active game for links
  const sb = userModule.getSupabase();
  let gameId = new URLSearchParams(location.search).get('game');

  if (!gameId) {
    const { data: cms } = await sb.from('cast_members').select('id').eq('user_id', user.id);
    if (cms?.length) {
      const { data: gc } = await sb.from('mm_game_cast')
        .select('game_id, mm_games(status)')
        .in('cast_member_id', cms.map(c => c.id))
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
      if (gc?.mm_games?.status === 'active') gameId = gc.game_id;
    }
  }

  renderSidebar(activePage, user, gameId);

  window.__signOut = async () => {
    await userModule.signOut();
  };
}
