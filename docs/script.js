document.addEventListener('DOMContentLoaded', () => {
  // 1. Homebrew & CLI Copy Notification
  const cliBox = document.getElementById('cli-copy-box');
  const toast = document.getElementById('toast-notice');
  const toastText = document.getElementById('toast-message');

  if (cliBox) {
    cliBox.addEventListener('click', () => {
      const code = 'brew install --cask duplix';
      navigator.clipboard.writeText(code).then(() => {
        showToast('Copied to clipboard: ' + code);
      });
    });
  }

  function showToast(message) {
    if (!toast || !toastText) return;
    toastText.textContent = message;
    toast.classList.add('show');
    setTimeout(() => {
      toast.classList.remove('show');
    }, 2800);
  }

  // 2. Interactive Dock Simulator Logic
  const appButtons = document.querySelectorAll('.app-pill-btn');
  const colorSwatches = document.querySelectorAll('.swatch-item');
  const badgeTextInput = document.getElementById('sim-badge-input');
  const simTargetApp = document.getElementById('sim-target-app');
  const simTargetBadge = document.getElementById('sim-target-badge');
  const simTargetIcon = document.getElementById('sim-target-icon');

  const appData = {
    antigravity: {
      name: 'Antigravity IDE',
      icon: 'assets/icon.png',
      defaultColor: '#4f46e5',
      defaultText: '1'
    },
    chrome: {
      name: 'Google Chrome',
      icon: 'https://cdn.simpleicons.org/googlechrome/06b6d4',
      defaultColor: '#06b6d4',
      defaultText: 'DEV'
    },
    vscode: {
      name: 'VS Code',
      icon: 'https://cdn.simpleicons.org/visualstudiocode/818cf8',
      defaultColor: '#7c3aed',
      defaultText: '2'
    },
    telegram: {
      name: 'Telegram',
      icon: 'https://cdn.simpleicons.org/telegram/38bdf8',
      defaultColor: '#0284c7',
      defaultText: 'W'
    },
    slack: {
      name: 'Slack',
      icon: 'https://cdn.simpleicons.org/slack/f43f5e',
      defaultColor: '#e11d48',
      defaultText: '3'
    },
    figma: {
      name: 'Figma',
      icon: 'https://cdn.simpleicons.org/figma/a855f7',
      defaultColor: '#9333ea',
      defaultText: 'ALT'
    }
  };

  let currentApp = 'antigravity';
  let currentColor = '#4f46e5';
  let currentText = '1';

  function updateDockSim() {
    if (!simTargetBadge || !simTargetIcon) return;
    simTargetBadge.style.backgroundColor = currentColor;
    simTargetBadge.textContent = currentText || '1';
    simTargetIcon.src = appData[currentApp]?.icon || 'assets/icon.png';

    // Physics-like Dock Bounce Animation
    if (simTargetApp) {
      simTargetApp.style.transform = 'translateY(-16px) scale(1.18)';
      setTimeout(() => {
        simTargetApp.style.transform = 'translateY(-4px) scale(1.05)';
        setTimeout(() => {
          simTargetApp.style.transform = '';
        }, 150);
      }, 200);
    }
  }

  // App Selection
  appButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      appButtons.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const appKey = btn.dataset.app;
      if (appData[appKey]) {
        currentApp = appKey;
        currentColor = appData[appKey].defaultColor;
        currentText = appData[appKey].defaultText;
        if (badgeTextInput) badgeTextInput.value = currentText;

        colorSwatches.forEach(s => {
          s.classList.toggle('active', s.dataset.color.toLowerCase() === currentColor.toLowerCase());
        });

        updateDockSim();
      }
    });
  });

  // Color Swatch Selection
  colorSwatches.forEach(swatch => {
    swatch.addEventListener('click', () => {
      colorSwatches.forEach(s => s.classList.remove('active'));
      swatch.classList.add('active');
      currentColor = swatch.dataset.color;
      updateDockSim();
    });
  });

  // Badge Text Input
  if (badgeTextInput) {
    badgeTextInput.addEventListener('input', (e) => {
      currentText = e.target.value.trim().substring(0, 4);
      updateDockSim();
    });
  }

  // Dock items bounce on click
  const dockSlots = document.querySelectorAll('.dock-slot');
  dockSlots.forEach(slot => {
    slot.addEventListener('click', () => {
      slot.style.transform = 'translateY(-14px) scale(1.15)';
      setTimeout(() => {
        slot.style.transform = '';
      }, 250);
    });
  });

  // 3. FAQ Accordion Logic
  const faqCards = document.querySelectorAll('.faq-card');
  faqCards.forEach(card => {
    const trigger = card.querySelector('.faq-trigger');
    if (trigger) {
      trigger.addEventListener('click', () => {
        const isOpen = card.classList.contains('open');
        faqCards.forEach(c => c.classList.remove('open'));
        if (!isOpen) {
          card.classList.add('open');
        }
      });
    }
  });

  // 4. Product Hunt Banner
  const phBanner = document.getElementById('ph-pill-link');
  if (phBanner) {
    phBanner.addEventListener('click', (e) => {
      e.preventDefault();
      showToast('Product Hunt launch campaign ready for submission!');
    });
  }

  // Initial render
  updateDockSim();
});
