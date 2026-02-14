# 🎨 Mansion Mayhem - Modern Color System

## Updated Color Palette (2025)

### Primary Colors
```css
--color-gold: #FFC107          /* Bright gold (was #D4AF37) */
--color-rose: #E91E63          /* Hot pink (unchanged) */
--color-purple: #9C27B0        /* NEW! Deep purple accent */
```

### Background Colors (Blue-tinted Dark)
```css
--color-background: #0A0E27    /* Primary background (was pure black #0A0A0A) */
--color-surface: #151936       /* Surface cards (was #1A1A1A) */
--color-light-gray: #1E2139    /* Card backgrounds (was #2A2A2A) */
--color-elevated: #252949      /* Elevated surfaces (was #2A2A2A) */
```

### Text Colors
```css
--color-text-primary: #FFFFFF  /* Primary text (unchanged) */
--color-text-secondary: #B8B9C5 /* Secondary text (was #B0B0B0) */
--color-text-muted: #6B7280    /* Muted text (was #707070) */
```

### Status Colors
```css
--color-success: #00C853       /* Brighter green (was #4CAF50) */
--color-error: #D32F2F         /* Error red (was #F44336) */
--color-warning: #FF9800       /* Warning orange (unchanged) */
--color-info: #2196F3          /* Info blue (unchanged) */
```

### Gradients
```css
--gradient-pink-purple: linear-gradient(135deg, #E91E63 0%, #9C27B0 100%)
--gradient-purple-pink: linear-gradient(135deg, #9C27B0 0%, #E91E63 100%)
--gradient-gold-rose: linear-gradient(135deg, #FFC107 0%, #E91E63 100%)
```

### Shadows
```css
--shadow-gold: 0 0 20px rgba(255, 193, 7, 0.3)
--shadow-rose: 0 0 20px rgba(233, 30, 99, 0.3)
--shadow-purple: 0 0 20px rgba(156, 39, 176, 0.3)
--shadow-pink-purple: 0 4px 12px rgba(233, 30, 99, 0.3)
```

## Usage Examples

### Modern Gradient Button
```css
.btn-primary {
  background: linear-gradient(135deg, #E91E63, #9C27B0);
  box-shadow: 0 4px 12px rgba(233, 30, 99, 0.3);
}
```

### Card with Gradient Accent
```css
.card {
  background: #1E2139;
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.card::before {
  background: linear-gradient(90deg, #E91E63, #9C27B0);
}
```

### Text Gradient Title
```css
.title {
  background: linear-gradient(135deg, #E91E63, #9C27B0);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
```

## Key Changes from Old System

1. **Blue-tinted Backgrounds** - Warmer, more modern feel
2. **Purple Accent Added** - Secondary accent color for variety
3. **Brighter Gold** - More vibrant (#FFC107 vs old #D4AF37)
4. **Lighter Text Secondary** - Better contrast (#B8B9C5 vs #B0B0B0)
5. **Brighter Success Green** - More saturated (#00C853 vs #4CAF50)

## Files Updated
- `web/css/global.css`
- `web/css/mansion-mayhem-theme.css`
- `web/pages/player-dashboard.html`
- `web/link-up-requests.html`

## Browser Support
All colors support modern browsers with CSS custom properties (IE11+)
