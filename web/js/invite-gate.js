// ============================================================================
// INVITE CODE GATE - Beta Access Control
// ============================================================================
// Add to any page to require invite code for access during beta
// ============================================================================

// ⚠️ SECURITY: Invite codes are now validated server-side
// No hardcoded codes in client - all validation via Supabase RPC
// See backend/validate-invite-code-rpc.sql for implementation

// Import Supabase client
import { supabaseClient } from './supabase-module.js';

// Check if user has valid access
function checkInviteAccess() {
  const storedCode = localStorage.getItem('mansion_mayhem_invite_code');
  const validatedAt = localStorage.getItem('mansion_mayhem_validated_at');

  // Check if code exists and was validated within last 30 days
  if (storedCode && validatedAt) {
    const thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000);
    if (parseInt(validatedAt) > thirtyDaysAgo) {
      return true;
    }
  }

  return false;
}

// Show invite gate modal
function showInviteGate() {
  // Create overlay
  const overlay = document.createElement('div');
  overlay.id = 'inviteGateOverlay';
  overlay.style.cssText = `
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.95);
    backdrop-filter: blur(10px);
    z-index: 999999;
    display: flex;
    align-items: center;
    justify-content: center;
    animation: fadeIn 0.3s ease;
  `;

  // Create modal
  const modal = document.createElement('div');
  modal.style.cssText = `
    background: linear-gradient(135deg, #1a1428 0%, #0a0612 100%);
    border: 2px solid rgba(212, 175, 55, 0.3);
    border-radius: 20px;
    padding: 3rem;
    max-width: 500px;
    width: 90%;
    text-align: center;
    animation: slideUp 0.4s ease;
  `;

  modal.innerHTML = `
    <img src="/assets/logo/mansion-mayhem-logo-256.png" alt="Mansion Mayhem" style="width: 100px; height: 100px; margin: 0 auto 1rem; object-fit: contain;">
    <h2 style="font-size: 2rem; font-weight: 900; margin-bottom: 0.5rem; background: linear-gradient(135deg, #D4AF37 0%, #FFD700 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent;">
      MANSION MAYHEM
    </h2>
    <p style="color: rgba(255, 255, 255, 0.6); margin-bottom: 2rem;">
      Private Beta - Invite Code Required
    </p>

    <div style="margin-bottom: 1.5rem;">
      <input
        type="text"
        id="inviteCodeInput"
        placeholder="Enter your invite code"
        style="
          width: 100%;
          padding: 1rem;
          background: rgba(255, 255, 255, 0.05);
          border: 2px solid rgba(212, 175, 55, 0.3);
          border-radius: 12px;
          color: white;
          font-size: 1rem;
          text-align: center;
          text-transform: uppercase;
          letter-spacing: 2px;
          transition: all 0.3s;
        "
        autocomplete="off"
      />
    </div>

    <button
      id="inviteCodeSubmit"
      style="
        width: 100%;
        padding: 1rem 2rem;
        background: linear-gradient(135deg, #D4AF37 0%, #FFD700 100%);
        border: none;
        border-radius: 12px;
        color: #0a0612;
        font-size: 1rem;
        font-weight: 700;
        cursor: pointer;
        transition: all 0.3s;
        text-transform: uppercase;
        letter-spacing: 1px;
      "
    >
      Enter
    </button>

    <div id="inviteError" style="
      margin-top: 1rem;
      color: #ef4444;
      font-size: 0.875rem;
      min-height: 20px;
    "></div>

    <div style="margin-top: 2rem; padding-top: 2rem; border-top: 1px solid rgba(255, 255, 255, 0.1);">
      <p style="color: rgba(255, 255, 255, 0.4); font-size: 0.875rem; margin-bottom: 0.5rem;">
        Need an invite code?
      </p>
      <a href="mailto:beta@mansionmayhem.com" style="color: #D4AF37; text-decoration: none; font-size: 0.875rem;">
        Request Beta Access →
      </a>
    </div>
  `;

  overlay.appendChild(modal);
  document.body.appendChild(overlay);

  // Add animations
  const style = document.createElement('style');
  style.textContent = `
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    @keyframes slideUp {
      from {
        opacity: 0;
        transform: translateY(30px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }
    #inviteCodeInput:focus {
      outline: none;
      border-color: #D4AF37 !important;
      box-shadow: 0 0 0 3px rgba(212, 175, 55, 0.2);
    }
    #inviteCodeSubmit:hover {
      transform: translateY(-2px);
      box-shadow: 0 10px 30px rgba(212, 175, 55, 0.3);
    }
    #inviteCodeSubmit:active {
      transform: translateY(0);
    }
  `;
  document.head.appendChild(style);

  // Handle submit
  const input = document.getElementById('inviteCodeInput');
  const submitBtn = document.getElementById('inviteCodeSubmit');
  const errorDiv = document.getElementById('inviteError');

  async function validateCode() {
    const code = input.value.trim().toUpperCase();

    if (!code) {
      errorDiv.textContent = 'Please enter an invite code';
      input.style.borderColor = '#ef4444';
      return;
    }

    // Disable button during validation
    submitBtn.disabled = true;
    submitBtn.textContent = 'Validating...';
    errorDiv.textContent = '';

    try {
      // Call server-side validation RPC
      const { data, error } = await supabaseClient.rpc('validate_invite_code', {
        p_code: code
      });

      if (error) {
        throw error;
      }

      if (data && data.valid) {
        // Valid code - store and remove overlay
        localStorage.setItem('mansion_mayhem_invite_code', code);
        localStorage.setItem('mansion_mayhem_validated_at', Date.now().toString());
        localStorage.setItem('mansion_mayhem_code_type', data.code_type);

        errorDiv.textContent = '✓ Valid code!';
        errorDiv.style.color = '#10b981';

        overlay.style.animation = 'fadeOut 0.3s ease';
        setTimeout(() => {
          overlay.remove();
        }, 300);
      } else {
        // Invalid code
        errorDiv.textContent = data.message || 'Invalid invite code. Please try again.';
        input.style.borderColor = '#ef4444';
        input.value = '';
        input.focus();

        // Shake animation
        modal.style.animation = 'shake 0.5s';
        setTimeout(() => {
          modal.style.animation = 'slideUp 0.4s ease';
        }, 500);

        submitBtn.disabled = false;
        submitBtn.textContent = 'Enter';
      }
    } catch (error) {
      console.error('Error validating invite code:', error);
      errorDiv.textContent = 'Error validating code. Please try again.';
      submitBtn.disabled = false;
      submitBtn.textContent = 'Enter';
    }
  }

  submitBtn.addEventListener('click', validateCode);
  input.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      validateCode();
    }
  });

  // Clear error on input
  input.addEventListener('input', () => {
    errorDiv.textContent = '';
    input.style.borderColor = 'rgba(212, 175, 55, 0.3)';
  });

  // Focus input
  setTimeout(() => input.focus(), 300);

  // Add shake animation
  const shakeStyle = document.createElement('style');
  shakeStyle.textContent = `
    @keyframes shake {
      0%, 100% { transform: translateX(0); }
      10%, 30%, 50%, 70%, 90% { transform: translateX(-10px); }
      20%, 40%, 60%, 80% { transform: translateX(10px); }
    }
    @keyframes fadeOut {
      from { opacity: 1; }
      to { opacity: 0; }
    }
  `;
  document.head.appendChild(shakeStyle);
}

// Initialize invite gate
async function initInviteGate() {
  // Check if user is already authenticated - skip invite gate for logged-in users
  if (window.supabaseClient) {
    try {
      const { data: { session } } = await window.supabaseClient.auth.getSession();
      if (session && session.user) {
        console.log('✅ User authenticated, skipping invite gate');
        return; // User is logged in, don't show invite gate
      }
    } catch (error) {
      console.log('Could not check auth, will check invite code');
    }
  }

  // Check if already has valid invite code
  if (checkInviteAccess()) {
    return;
  }

  // Only show gate on public pages (landing, about, careers, etc.)
  // Skip on authenticated pages (dashboard, director console, etc.)
  const publicPages = ['index.html', 'about.html', 'careers.html', 'press.html', 'contact.html', 'how-to-play.html', 'faq.html'];
  const currentPage = window.location.pathname.split('/').pop() || 'index.html';

  if (!publicPages.includes(currentPage) && currentPage !== '' && currentPage !== '/') {
    console.log('✅ Internal page, skipping invite gate');
    return;
  }

  // Show gate after DOM loads
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', showInviteGate);
  } else {
    showInviteGate();
  }
}

// Wait for supabaseClient to be available before initializing
let initAttempts = 0;
const waitForSupabase = setInterval(() => {
  if (window.supabaseClient || initAttempts > 20) {
    clearInterval(waitForSupabase);
    initInviteGate();
  }
  initAttempts++;
}, 100);
