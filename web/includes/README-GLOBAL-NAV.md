# Global Navigation Component

## Usage

The global navigation component provides a consistent navigation bar across all pages with:
- Logo and branding
- Main navigation links (Voice Feed, Gallery, Cast, Leaderboard)
- Notifications button with badge
- User menu with dropdown
- Role-based visibility (admin links)
- Mobile responsive design

## How to Include in Pages

### Method 1: Simple Include (Recommended for new pages)

Add this line at the top of your `<body>` tag:

```html
<body>
  <!-- Include global navigation -->
  <div id="globalNavContainer"></div>
  <script>
    fetch('/includes/global-nav.html')
      .then(res => res.text())
      .then(html => {
        document.getElementById('globalNavContainer').innerHTML = html;
      });
  </script>

  <!-- Your page content here -->
  <div class="container">
    <!-- content -->
  </div>
</body>
```

### Method 2: Direct Copy (For pages that need customization)

Copy the entire content of `global-nav.html` directly into your page's `<body>` tag.

## Important Notes

1. **Body Padding**: The global nav is fixed at the top, so the component includes CSS that adds `padding-top: 80px` to the body. If your page already has custom body styling, you may need to adjust this.

2. **Dependencies**: The component requires:
   - `supabase-module.js` for authentication
   - Supabase tables: `profiles`, `notifications`

3. **Admin Links**: Links with class `admin-only` are automatically hidden for non-admin users.

4. **Active State**: The current page link is automatically highlighted with the `.active` class.

5. **Mobile**: Navigation links are hidden on mobile (< 968px width) to save space.

## Pages That Should Include Global Nav

**High Priority** (user-facing pages):
- ✅ `/pages/voice-feed.html`
- ✅ `/pages/gallery.html`
- ✅ `/pages/cast-roster.html`
- ✅ `/pages/leaderboard.html`
- ✅ `/pages/player-profile.html`
- ✅ `/pages/voting.html`
- ✅ `/pages/results.html`
- ✅ `/pages/settings.html`

**Medium Priority** (game pages):
- `/pages/cast-portal.html`
- `/lobby-dashboard.html`
- `/alliance-chat.html`

**Low Priority** (admin pages - already have their own nav):
- `/pages/admin-dashboard.html` (has custom admin nav)
- `/director-console.html` (has director nav)
- `/pages/admin-moderation.html` (has admin nav)

## Customization

### Change Navigation Links

Edit the `.nav-center` section in `global-nav.html`:

```html
<div class="nav-center">
  <a href="/your-page.html" class="nav-link">
    🎯 Your Link
  </a>
</div>
```

### Update Notification Count

Call this from your page JavaScript:

```javascript
const badge = document.getElementById('notificationBadge');
badge.textContent = count;
badge.style.display = count > 0 ? 'flex' : 'none';
```

### Add Role-Based Links

Add the `admin-only`, `director-only`, or `cast-only` class:

```html
<a href="/admin-page.html" class="nav-link admin-only">
  ⚙️ Admin Panel
</a>
```

## Styling

All styles are scoped within the component. To override:

```html
<style>
  .global-nav {
    /* Your custom styles */
  }
</style>
```

## Functions Available

The component exposes these functions to `window`:
- `toggleUserMenu()` - Toggle the user dropdown
- `handleSignOut(event)` - Sign out the current user
