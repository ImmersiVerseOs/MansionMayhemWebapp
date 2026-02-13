/**
 * MANSION MAYHEM - Component Library JavaScript
 * Based on mobile app (Mansion_Mayhem_App)
 * Luxury Reality TV Aesthetic
 */

// ===== COUNTDOWN TIMER CLASS =====

class CountdownTimer {
  constructor(targetDate, element, options = {}) {
    this.targetDate = new Date(targetDate);
    this.element = element;
    this.options = {
      size: options.size || 'medium',
      showLabels: options.showLabels !== false,
      compact: options.compact || false,
      onExpire: options.onExpire || null,
      onTick: options.onTick || null
    };

    this.interval = null;
    this.init();
  }

  init() {
    this.render();
    this.start();
  }

  calculateTimeLeft() {
    const now = new Date();
    const difference = this.targetDate - now;

    if (difference > 0) {
      return {
        hours: Math.floor((difference / (1000 * 60 * 60)) % 24),
        minutes: Math.floor((difference / 1000 / 60) % 60),
        seconds: Math.floor((difference / 1000) % 60),
        total: difference
      };
    }

    return { hours: 0, minutes: 0, seconds: 0, total: 0 };
  }

  render() {
    const timeLeft = this.calculateTimeLeft();
    const hasExpired = timeLeft.total <= 0;
    const isUrgent = timeLeft.total > 0 && timeLeft.total < 3600000; // Less than 1 hour
    const isWarning = timeLeft.total > 0 && timeLeft.total < 10800000; // Less than 3 hours

    if (hasExpired) {
      this.element.innerHTML = `
        <div class="mm-timer mm-timer-urgent">
          ⏰ Time's Up
        </div>
      `;
      return;
    }

    const hours = String(timeLeft.hours).padStart(2, '0');
    const minutes = String(timeLeft.minutes).padStart(2, '0');
    const seconds = String(timeLeft.seconds).padStart(2, '0');

    let timerClass = 'mm-timer';
    if (this.options.size === 'large') timerClass += ' mm-timer-large';
    if (this.options.compact) timerClass += ' mm-timer-compact';
    if (isUrgent) timerClass += ' mm-timer-urgent';
    else if (isWarning) timerClass += ' mm-timer-warning';

    if (this.options.compact) {
      this.element.innerHTML = `
        <div class="${timerClass}">
          ⏰ ${hours}:${minutes}:${seconds}
        </div>
      `;
    } else {
      this.element.innerHTML = `
        <div class="${timerClass}">
          <div class="mm-timer-unit">
            <div class="mm-timer-value">${hours}</div>
            ${this.options.showLabels ? '<div class="mm-timer-label">Hours</div>' : ''}
          </div>
          <span class="mm-timer-separator">:</span>
          <div class="mm-timer-unit">
            <div class="mm-timer-value">${minutes}</div>
            ${this.options.showLabels ? '<div class="mm-timer-label">Min</div>' : ''}
          </div>
          <span class="mm-timer-separator">:</span>
          <div class="mm-timer-unit">
            <div class="mm-timer-value">${seconds}</div>
            ${this.options.showLabels ? '<div class="mm-timer-label">Sec</div>' : ''}
          </div>
        </div>
      `;
    }

    // Call onTick callback if provided
    if (this.options.onTick) {
      this.options.onTick(timeLeft);
    }
  }

  start() {
    this.interval = setInterval(() => {
      const timeLeft = this.calculateTimeLeft();
      this.render();

      if (timeLeft.total <= 0) {
        this.stop();
        if (this.options.onExpire) {
          this.options.onExpire();
        }
      }
    }, 1000);
  }

  stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
  }

  destroy() {
    this.stop();
    this.element.innerHTML = '';
  }
}

// ===== TOAST NOTIFICATIONS =====

class ToastManager {
  constructor() {
    this.container = null;
    this.init();
  }

  init() {
    if (!document.querySelector('.mm-toast-container')) {
      this.container = document.createElement('div');
      this.container.className = 'mm-toast-container';
      document.body.appendChild(this.container);
    } else {
      this.container = document.querySelector('.mm-toast-container');
    }
  }

  show(message, type = 'info', duration = 3000) {
    const toast = document.createElement('div');
    toast.className = `mm-toast mm-toast-${type}`;

    const icon = this.getIcon(type);

    toast.innerHTML = `
      <span style="font-size: var(--mm-font-lg);">${icon}</span>
      <div class="mm-toast-message">${message}</div>
      <button class="mm-toast-close" onclick="this.parentElement.remove()">×</button>
    `;

    this.container.appendChild(toast);

    if (duration > 0) {
      setTimeout(() => {
        toast.style.animation = 'mm-toast-slide-in var(--mm-duration-normal) var(--mm-ease-default) reverse';
        setTimeout(() => toast.remove(), 300);
      }, duration);
    }

    return toast;
  }

  getIcon(type) {
    const icons = {
      success: '✓',
      error: '✕',
      warning: '⚠',
      info: 'ℹ'
    };
    return icons[type] || icons.info;
  }

  success(message, duration) {
    return this.show(message, 'success', duration);
  }

  error(message, duration) {
    return this.show(message, 'error', duration);
  }

  warning(message, duration) {
    return this.show(message, 'warning', duration);
  }

  info(message, duration) {
    return this.show(message, 'info', duration);
  }
}

// Create global toast instance
const toast = new ToastManager();

// ===== MODAL MANAGER =====

class Modal {
  constructor(options = {}) {
    this.options = {
      title: options.title || '',
      content: options.content || '',
      footer: options.footer || null,
      onClose: options.onClose || null,
      closeOnOverlayClick: options.closeOnOverlayClick !== false
    };

    this.overlay = null;
    this.modal = null;
  }

  open() {
    this.render();
    document.body.style.overflow = 'hidden';
  }

  close() {
    if (this.options.onClose) {
      this.options.onClose();
    }

    if (this.overlay) {
      this.overlay.style.animation = 'mm-fade-in var(--mm-duration-normal) var(--mm-ease-default) reverse';
      setTimeout(() => {
        this.overlay.remove();
        document.body.style.overflow = '';
      }, 300);
    }
  }

  render() {
    this.overlay = document.createElement('div');
    this.overlay.className = 'mm-modal-overlay';

    if (this.options.closeOnOverlayClick) {
      this.overlay.addEventListener('click', (e) => {
        if (e.target === this.overlay) {
          this.close();
        }
      });
    }

    const modalHTML = `
      <div class="mm-modal">
        <div class="mm-modal-header">
          <h2 class="mm-modal-title">${this.options.title}</h2>
          <button class="mm-modal-close" onclick="this.closest('.mm-modal-overlay').dispatchEvent(new Event('close'))">×</button>
        </div>
        <div class="mm-modal-body">
          ${this.options.content}
        </div>
        ${this.options.footer ? `<div class="mm-modal-footer">${this.options.footer}</div>` : ''}
      </div>
    `;

    this.overlay.innerHTML = modalHTML;
    document.body.appendChild(this.overlay);

    // Add close event listener
    this.overlay.addEventListener('close', () => this.close());

    // Add close button listener
    const closeBtn = this.overlay.querySelector('.mm-modal-close');
    if (closeBtn) {
      closeBtn.addEventListener('click', () => this.close());
    }
  }

  setContent(content) {
    const body = this.overlay.querySelector('.mm-modal-body');
    if (body) {
      body.innerHTML = content;
    }
  }
}

// ===== REAL-TIME UPDATE UTILITIES =====

class RealtimeUpdater {
  constructor(supabase, table) {
    this.supabase = supabase;
    this.table = table;
    this.subscription = null;
    this.callbacks = {
      insert: [],
      update: [],
      delete: []
    };
  }

  on(event, callback) {
    if (this.callbacks[event]) {
      this.callbacks[event].push(callback);
    }
    return this;
  }

  subscribe(filter = null) {
    let channel = this.supabase
      .channel(`${this.table}-changes`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: this.table,
          ...(filter && { filter })
        },
        (payload) => {
          const { eventType, new: newRecord, old: oldRecord } = payload;

          if (eventType === 'INSERT' && this.callbacks.insert.length > 0) {
            this.callbacks.insert.forEach(cb => cb(newRecord));
          }

          if (eventType === 'UPDATE' && this.callbacks.update.length > 0) {
            this.callbacks.update.forEach(cb => cb(newRecord, oldRecord));
          }

          if (eventType === 'DELETE' && this.callbacks.delete.length > 0) {
            this.callbacks.delete.forEach(cb => cb(oldRecord));
          }
        }
      )
      .subscribe();

    this.subscription = channel;
    return this;
  }

  unsubscribe() {
    if (this.subscription) {
      this.supabase.removeChannel(this.subscription);
      this.subscription = null;
    }
  }
}

// ===== HELPER FUNCTIONS =====

/**
 * Format time remaining as human-readable string
 */
function formatTimeRemaining(targetDate) {
  const now = new Date();
  const difference = new Date(targetDate) - now;

  if (difference <= 0) return 'Expired';

  const hours = Math.floor(difference / (1000 * 60 * 60));
  const minutes = Math.floor((difference / (1000 * 60)) % 60);

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${minutes}m`;
}

/**
 * Format date as relative time (e.g., "2 hours ago")
 */
function formatRelativeTime(date) {
  const now = new Date();
  const past = new Date(date);
  const diffMs = now - past;
  const diffMins = Math.floor(diffMs / (1000 * 60));

  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;

  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours}h ago`;

  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d ago`;
}

/**
 * Debounce function to limit rate of execution
 */
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

/**
 * Initialize all countdown timers on page
 */
function initCountdownTimers() {
  const timerElements = document.querySelectorAll('[data-countdown-target]');
  const timers = [];

  timerElements.forEach(element => {
    const targetDate = element.getAttribute('data-countdown-target');
    const size = element.getAttribute('data-countdown-size') || 'medium';
    const showLabels = element.getAttribute('data-countdown-labels') !== 'false';
    const compact = element.getAttribute('data-countdown-compact') === 'true';

    const timer = new CountdownTimer(targetDate, element, {
      size,
      showLabels,
      compact,
      onExpire: () => {
        const onExpire = element.getAttribute('data-countdown-on-expire');
        if (onExpire && window[onExpire]) {
          window[onExpire]();
        }
      }
    });

    timers.push(timer);
  });

  return timers;
}

/**
 * Initialize radio button styling
 */
function initRadioButtons() {
  const radioOptions = document.querySelectorAll('.mm-radio-option');

  radioOptions.forEach(option => {
    const radio = option.querySelector('input[type="radio"]');

    if (radio) {
      // Set initial state
      if (radio.checked) {
        option.classList.add('selected');
      }

      // Handle clicks on the entire option
      option.addEventListener('click', () => {
        radio.checked = true;

        // Remove selected class from siblings
        const name = radio.getAttribute('name');
        document.querySelectorAll(`input[name="${name}"]`).forEach(r => {
          r.closest('.mm-radio-option').classList.remove('selected');
        });

        // Add selected class to this option
        option.classList.add('selected');
      });

      // Handle radio change event
      radio.addEventListener('change', () => {
        if (radio.checked) {
          const name = radio.getAttribute('name');
          document.querySelectorAll(`input[name="${name}"]`).forEach(r => {
            r.closest('.mm-radio-option').classList.remove('selected');
          });
          option.classList.add('selected');
        }
      });
    }
  });
}

/**
 * Create a loading spinner element
 */
function createSpinner(large = false) {
  const spinner = document.createElement('div');
  spinner.className = large ? 'mm-spinner mm-spinner-large' : 'mm-spinner';
  return spinner;
}

/**
 * Show loading state on button
 */
function setButtonLoading(button, loading) {
  if (loading) {
    button.disabled = true;
    button.dataset.originalContent = button.innerHTML;
    const spinner = createSpinner();
    button.innerHTML = '';
    button.appendChild(spinner);
  } else {
    button.disabled = false;
    if (button.dataset.originalContent) {
      button.innerHTML = button.dataset.originalContent;
      delete button.dataset.originalContent;
    }
  }
}

/**
 * Copy text to clipboard with feedback
 */
async function copyToClipboard(text, successMessage = 'Copied to clipboard!') {
  try {
    await navigator.clipboard.writeText(text);
    toast.success(successMessage);
    return true;
  } catch (err) {
    toast.error('Failed to copy to clipboard');
    return false;
  }
}

/**
 * Initialize all components on page load
 */
function initMansionMayhemComponents() {
  initCountdownTimers();
  initRadioButtons();

  console.log('✨ Mansion Mayhem components initialized');
}

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initMansionMayhemComponents);
} else {
  initMansionMayhemComponents();
}

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    CountdownTimer,
    ToastManager,
    Modal,
    RealtimeUpdater,
    toast,
    formatTimeRemaining,
    formatRelativeTime,
    debounce,
    initCountdownTimers,
    initRadioButtons,
    createSpinner,
    setButtonLoading,
    copyToClipboard
  };
}
