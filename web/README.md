# Mansion Mayhem Web Portal

Cast-facing web pages for Mansion Mayhem, redesigned to match the mobile app design system.

## 📱 Mobile App
- **Live Site**: https://mansionofmayhem.netlify.app/
- **Repo**: https://github.com/ImmersiVerseOs/Mansion_Mayhem_App

## 🌐 Web Pages

### Cast-Facing Pages
- **join.html** - Join a game with code or token
- **lobby.html** - Pre-game lobby with real-time updates
- **cast-portal.html** - Active game dashboard with scenarios
- **scenario-detail.html** - Respond to scenarios with voice notes
- **consent.html** - FaceCast AI consent wizard

### Component Library
- **css/mansion-mayhem-theme.css** - Design system variables
- **css/mansion-mayhem-components.css** - Component styles
- **js/mansion-mayhem-components.js** - Component JavaScript

### Documentation
- **COMPONENTS.md** - Complete component reference guide

## 🎨 Design System

Matches the mobile app design:
- **Colors**: Gold (#D4AF37) and Rose (#E91E63) gradients
- **Fonts**: Playfair Display (headings) + Montserrat (body) + Roboto Mono (code)
- **Layout**: 428px mobile-first container
- **Theme**: Dark luxury reality TV aesthetic

## 🚀 Accessing the Pages

Once deployed, access pages at:
- `https://your-site.netlify.app/web/join.html`
- `https://your-site.netlify.app/web/lobby.html?game=GAME_ID`
- `https://your-site.netlify.app/web/cast-portal.html`
- `https://your-site.netlify.app/web/scenario-detail.html?id=SCENARIO_ID`
- `https://your-site.netlify.app/web/consent.html`

## 🔗 Integration

All pages connect to the same Supabase backend:
- Database: `https://dhqwxamggghewbslfdej.supabase.co`
- Tables: `mm_games`, `mm_game_cast`, `cast_members`, `scenarios`, `scenario_responses`
- Real-time subscriptions for live updates

## 📖 Component Reference

See [COMPONENTS.md](./COMPONENTS.md) for complete documentation of:
- Design system variables
- Component styles and usage
- JavaScript utilities
- Helper functions
- Usage examples

## ✨ Features

- **Real-time Updates**: Supabase subscriptions for live data
- **Toast Notifications**: Modern UX replacing alert()
- **Countdown Timers**: Auto-updating scenario deadlines
- **Voice Recording**: Browser-based audio capture
- **Responsive Design**: Mobile-first 428px layout
- **Loading States**: Spinners on all async actions
- **Form Validation**: Client-side validation with feedback

---

**Created**: February 2026
**Version**: 1.0.0
**Design Reference**: Mobile app at https://mansionofmayhem.netlify.app/
