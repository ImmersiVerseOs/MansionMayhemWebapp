# Mansion Mayhem Component Library

A comprehensive design system and component library for Mansion Mayhem web pages, based on the mobile app design (Mansion_Mayhem_App).

## 📁 Files

- **`css/mansion-mayhem-theme.css`** - Design system variables and base styles
- **`css/mansion-mayhem-components.css`** - Component styles
- **`js/mansion-mayhem-components.js`** - Component JavaScript utilities

## 🎨 Design System

### Colors

```css
/* Primary Palette */
--mm-gold: #D4AF37;
--mm-gold-light: #E8D090;
--mm-gold-dark: #B8941F;

--mm-rose: #E91E63;
--mm-rose-light: #F48FB1;
--mm-rose-dark: #C2185B;

/* Neutrals */
--mm-dark: #0A0A0A;
--mm-dark-gray: #1A1A1A;
--mm-medium-gray: #2A2A2A;
--mm-light-gray: #3A3A3A;
--mm-text-gray: #A0A0A0;

/* Status Colors */
--mm-success: #4CAF50;
--mm-warning: #FF9800;
--mm-danger: #F44336;
--mm-info: #2196F3;
```

### Typography

- **Heading Font**: 'Playfair Display', serif
- **Body Font**: 'Montserrat', sans-serif
- **Mono Font**: 'Roboto Mono', monospace

```css
/* Font Sizes */
--mm-font-xs: 12px;
--mm-font-sm: 14px;
--mm-font-base: 16px;
--mm-font-lg: 18px;
--mm-font-xl: 20px;
--mm-font-2xl: 24px;
--mm-font-3xl: 30px;
--mm-font-4xl: 36px;
--mm-font-5xl: 48px;
```

### Spacing (8-point grid)

```css
--mm-space-xs: 4px;
--mm-space-sm: 8px;
--mm-space-md: 16px;
--mm-space-lg: 24px;
--mm-space-xl: 32px;
--mm-space-2xl: 48px;
--mm-space-3xl: 64px;
```

---

## 🧩 Components

### Container

The main container provides a mobile-first 428px width with shadow.

```html
<div class="mm-container">
  <!-- Your content here -->
</div>
```

**Variants:**
- `.mm-container` - Mobile-first (428px max width)
- `.mm-container-wide` - Desktop layout (1200px max width)

---

### Buttons

Buttons with multiple variants and sizes.

```html
<!-- Primary Button -->
<button class="mm-button mm-button-primary">
  Submit
</button>

<!-- Secondary Button -->
<button class="mm-button mm-button-secondary">
  Cancel
</button>

<!-- Ghost Button -->
<button class="mm-button mm-button-ghost">
  ← Back
</button>

<!-- Danger Button -->
<button class="mm-button mm-button-danger">
  Delete
</button>
```

**Modifiers:**
- `.mm-button-small` - Smaller button
- `.mm-button-large` - Larger button
- `.mm-button-full` - Full width button

**With Icons:**
```html
<button class="mm-button mm-button-primary">
  🎬 Join Game
</button>
```

**JavaScript Helper:**
```javascript
// Show loading spinner on button
setButtonLoading(button, true);  // Enable loading
setButtonLoading(button, false); // Disable loading
```

---

### Cards

Versatile card component with multiple variants.

```html
<!-- Basic Card -->
<div class="mm-card">
  <h3 class="mm-card-title">Card Title</h3>
  <p class="mm-card-subtitle">Subtitle text</p>
  <div class="mm-card-content">
    Content goes here
  </div>
</div>

<!-- Compact Card -->
<div class="mm-card mm-card-compact">
  Compact padding
</div>

<!-- Elevated Card -->
<div class="mm-card mm-card-elevated">
  Slightly raised
</div>

<!-- Highlighted Card (gold border) -->
<div class="mm-card mm-card-highlight">
  Important content
</div>

<!-- Gradient Card -->
<div class="mm-card mm-card-gradient">
  Gold-to-rose gradient background
</div>

<!-- Clickable Card -->
<div class="mm-card mm-card-clickable" onclick="handleClick()">
  Clickable with hover effect
</div>
```

**With Footer:**
```html
<div class="mm-card">
  <div class="mm-card-header">
    <h3 class="mm-card-title">Title</h3>
  </div>
  <div class="mm-card-content">
    Content
  </div>
  <div class="mm-card-footer">
    Footer actions
  </div>
</div>
```

---

### Badges

Small status indicators.

```html
<!-- Fire Badge (urgent) -->
<span class="mm-badge mm-badge-fire">🔥 Urgent</span>

<!-- Warning Badge -->
<span class="mm-badge mm-badge-warning">⚠ Warning</span>

<!-- Success Badge -->
<span class="mm-badge mm-badge-success">✓ Complete</span>

<!-- Premium Badge -->
<span class="mm-badge mm-badge-premium">⭐ Premium</span>

<!-- Default Badge -->
<span class="mm-badge mm-badge-default">Info</span>
```

**Positioned Badge:**
```html
<div class="mm-card" style="position: relative;">
  <span class="mm-badge mm-badge-fire mm-badge-top-right">🔥 Urgent</span>
  Card content
</div>
```

---

### Form Inputs

Styled form elements.

```html
<!-- Text Input -->
<input type="text" class="mm-input" placeholder="Enter text">

<!-- Monospace Input (for codes) -->
<input type="text" class="mm-input mm-input-mono" placeholder="GAME-CODE">

<!-- Textarea -->
<textarea class="mm-textarea" placeholder="Enter your response..."></textarea>

<!-- Select Dropdown -->
<select class="mm-input">
  <option>Option 1</option>
  <option>Option 2</option>
</select>
```

---

### Radio Buttons

Styled radio button group.

```html
<div class="mm-radio-group">
  <label class="mm-radio-option">
    <input type="radio" name="choice" value="1">
    <span>Option 1</span>
  </label>
  <label class="mm-radio-option">
    <input type="radio" name="choice" value="2">
    <span>Option 2</span>
  </label>
  <label class="mm-radio-option">
    <input type="radio" name="choice" value="3">
    <span>Option 3</span>
  </label>
</div>
```

**JavaScript:**
Radio buttons are automatically initialized with proper styling on page load.

```javascript
// Manually initialize if adding dynamically
initRadioButtons();
```

---

### Countdown Timer

Real-time countdown with automatic updates.

**HTML (Data Attributes):**
```html
<!-- Auto-initialized timer -->
<div
  data-countdown-target="2026-12-31T23:59:59Z"
  data-countdown-size="large"
  data-countdown-labels="true"
  data-countdown-compact="false"
></div>
```

**JavaScript:**
```javascript
// Manual initialization
const timer = new CountdownTimer('2026-12-31T23:59:59Z', element, {
  size: 'large',           // 'medium' | 'large'
  showLabels: true,        // Show Hours/Min/Sec labels
  compact: false,          // Compact format (⏰ 01:23:45)
  onExpire: () => {
    console.log('Timer expired!');
  },
  onTick: (timeLeft) => {
    console.log('Time remaining:', timeLeft);
  }
});

// Control timer
timer.stop();    // Stop updates
timer.destroy(); // Remove timer
```

**Automatic Initialization:**
```javascript
// All timers with data-countdown-target are auto-initialized
const timers = initCountdownTimers();
```

---

### Toast Notifications

Modern notification system (replaces alert()).

```javascript
// Show toast
toast.show('Message here', 'success', 3000);

// Helper methods
toast.success('Operation successful!');
toast.error('Something went wrong');
toast.warning('Please review this');
toast.info('Just so you know...');

// Custom duration (milliseconds)
toast.success('Saved!', 5000); // Shows for 5 seconds
```

**Types:**
- `success` - Green with ✓
- `error` - Red with ✕
- `warning` - Orange with ⚠
- `info` - Blue with ℹ

---

### Modal

Popup modal dialog.

```javascript
// Create modal
const modal = new Modal({
  title: 'Confirm Action',
  content: '<p>Are you sure you want to continue?</p>',
  footer: `
    <button class="mm-button mm-button-secondary" onclick="this.closest('.mm-modal-overlay').dispatchEvent(new Event('close'))">
      Cancel
    </button>
    <button class="mm-button mm-button-primary" onclick="confirmAction()">
      Confirm
    </button>
  `,
  onClose: () => {
    console.log('Modal closed');
  },
  closeOnOverlayClick: true
});

// Open modal
modal.open();

// Close modal
modal.close();

// Update content dynamically
modal.setContent('<p>New content here</p>');
```

---

### Header

Gradient header component.

```html
<div class="mm-header">
  <h1 class="mm-header-title">MANSION MAYHEM</h1>
  <p class="mm-header-subtitle">Game Code: MM-BETA-001</p>
</div>
```

---

### Progress Bar

Animated progress indicator.

```html
<div class="mm-progress">
  <div class="mm-progress-bar" style="width: 60%;"></div>
</div>
<p class="mm-progress-text">60% Complete</p>
```

**JavaScript:**
```javascript
// Update progress
document.querySelector('.mm-progress-bar').style.width = '80%';
document.querySelector('.mm-progress-text').textContent = '80% Complete';
```

---

### Avatar

User avatar component.

```html
<!-- Default size (48px) -->
<div class="mm-avatar">
  👤
</div>

<!-- With image -->
<div class="mm-avatar">
  <img src="avatar.jpg" alt="User">
</div>

<!-- Large (80px) -->
<div class="mm-avatar mm-avatar-large">
  JD
</div>

<!-- Small (32px) -->
<div class="mm-avatar mm-avatar-small">
  👤
</div>
```

---

### Loading Spinner

Animated loading indicator.

```html
<!-- Default spinner -->
<div class="mm-spinner"></div>

<!-- Large spinner -->
<div class="mm-spinner mm-spinner-large"></div>
```

**JavaScript Helper:**
```javascript
const spinner = createSpinner(); // Default size
const largeSpinner = createSpinner(true); // Large size
document.body.appendChild(spinner);
```

---

### Empty State

Placeholder for empty content areas.

```html
<div class="mm-empty-state">
  <div class="mm-empty-state-icon">🏝️</div>
  <div class="mm-empty-state-title">No Items Found</div>
  <div class="mm-empty-state-message">
    There are no items to display at this time.
  </div>
</div>
```

---

### Tabs

Tab navigation component.

```html
<div class="mm-tabs">
  <button class="mm-tab active">Active Tab</button>
  <button class="mm-tab">Inactive Tab</button>
  <button class="mm-tab">Another Tab</button>
</div>
```

---

## 🛠️ Utility Classes

### Text Alignment
```html
<div class="mm-text-center">Centered text</div>
<div class="mm-text-left">Left aligned</div>
<div class="mm-text-right">Right aligned</div>
```

### Spacing
```html
<!-- Margins -->
<div class="mm-mt-sm">Margin top small</div>
<div class="mm-mt-md">Margin top medium</div>
<div class="mm-mt-lg">Margin top large</div>
<div class="mm-mt-xl">Margin top extra large</div>

<div class="mm-mb-sm">Margin bottom small</div>
<div class="mm-mb-md">Margin bottom medium</div>
<div class="mm-mb-lg">Margin bottom large</div>
<div class="mm-mb-xl">Margin bottom extra large</div>
```

### Flexbox
```html
<div class="mm-flex">Flex container</div>
<div class="mm-flex-col">Flex column</div>
<div class="mm-flex mm-items-center">Vertically centered</div>
<div class="mm-flex mm-justify-center">Horizontally centered</div>
<div class="mm-flex mm-justify-between">Space between</div>

<!-- Gaps -->
<div class="mm-flex mm-gap-sm">Small gap</div>
<div class="mm-flex mm-gap-md">Medium gap</div>
<div class="mm-flex mm-gap-lg">Large gap</div>
```

### Typography
```html
<h1 class="mm-heading">Heading text</h1>
<p class="mm-mono">Monospace text</p>
<span class="mm-gradient-text">Gold-rose gradient text</span>
```

### Visibility
```html
<div class="mm-hidden">Hidden element</div>
```

### Animations
```html
<div class="mm-fade-in">Fade in animation</div>
<div class="mm-pulse">Pulsing animation</div>
```

---

## 🔧 JavaScript Utilities

### Helper Functions

```javascript
// Format time remaining
formatTimeRemaining('2026-12-31T23:59:59Z');
// Returns: "23h 45m" or "Expired"

// Format relative time
formatRelativeTime('2026-02-01T12:00:00Z');
// Returns: "2h ago", "Just now", "3d ago"

// Debounce function
const debouncedSearch = debounce((query) => {
  console.log('Searching for:', query);
}, 300);

// Copy to clipboard
await copyToClipboard('Text to copy', 'Copied!');
// Returns: true/false, shows toast notification
```

### Realtime Updates (Supabase)

```javascript
// Create realtime updater
const updater = new RealtimeUpdater(supabase, 'scenarios');

// Listen to events
updater
  .on('insert', (newRecord) => {
    console.log('New scenario:', newRecord);
  })
  .on('update', (newRecord, oldRecord) => {
    console.log('Updated scenario:', newRecord);
  })
  .on('delete', (oldRecord) => {
    console.log('Deleted scenario:', oldRecord);
  })
  .subscribe();

// Unsubscribe when done
updater.unsubscribe();
```

---

## 📖 Usage Example

Complete page structure:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>My Page | MANSION MAYHEM</title>

  <!-- Fonts -->
  <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700;900&family=Montserrat:wght@300;400;500;600;700&family=Roboto+Mono:wght@400;500&display=swap" rel="stylesheet">

  <!-- Mansion Mayhem Styles -->
  <link rel="stylesheet" href="css/mansion-mayhem-theme.css">
  <link rel="stylesheet" href="css/mansion-mayhem-components.css">
</head>
<body>
  <div class="mm-container">

    <!-- Header -->
    <div class="mm-header">
      <h1 class="mm-header-title">Page Title</h1>
      <p class="mm-header-subtitle">Subtitle</p>
    </div>

    <!-- Content Section -->
    <div class="mm-section">
      <div class="mm-card">
        <h2 class="mm-card-title">Card Title</h2>
        <div class="mm-card-content">
          Content goes here
        </div>
      </div>
    </div>

    <!-- Button -->
    <div class="mm-section">
      <button class="mm-button mm-button-primary mm-button-full">
        Submit
      </button>
    </div>

  </div>

  <!-- Scripts -->
  <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
  <script src="js/mansion-mayhem-components.js"></script>
  <script>
    // Your JavaScript here
    toast.success('Page loaded!');
  </script>
</body>
</html>
```

---

## 🎯 Best Practices

1. **Always include fonts** - Import Playfair Display, Montserrat, and Roboto Mono
2. **Load in order** - theme.css → components.css → components.js
3. **Use the container** - Wrap content in `.mm-container` for proper mobile layout
4. **Use toast instead of alert** - Better UX with `toast.success()`, `toast.error()`, etc.
5. **Initialize components** - Components auto-initialize on DOMContentLoaded
6. **Use utility classes** - Leverage spacing and flex utilities for layouts
7. **Preserve Supabase logic** - All database queries should remain functional

---

## 🚀 Future Enhancements

Potential additions to the component library:

- File upload component
- Data table component
- Carousel/slider component
- Collapsible accordion
- Image gallery
- Search/filter components
- Pagination component
- Notification center

---

## 📝 Notes

- All components are responsive by default
- The design system matches the mobile app (Mansion_Mayhem_App)
- Components use CSS custom properties for easy theming
- JavaScript components are vanilla JS (no framework dependencies)
- Supabase integration is maintained across all redesigned pages

---

**Created:** February 2026
**Version:** 1.0.0
**Mobile App Reference:** https://mansionofmayhem.netlify.app/
