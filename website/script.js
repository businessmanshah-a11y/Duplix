document.addEventListener('DOMContentLoaded', () => {
  // 1. Terminal Command Copy Helper
  const terminalBox = document.getElementById('brew-cmd-box');
  const toast = document.getElementById('toast');

  if (terminalBox) {
    terminalBox.addEventListener('click', () => {
      const code = 'brew install --cask duplix';
      navigator.clipboard.writeText(code).then(() => {
        showToast('Copied to clipboard: ' + code);
      });
    });
  }

  window.copySnippet = function (text) {
    navigator.clipboard.writeText(text).then(() => {
      showToast('Copied: ' + text);
    });
  };

  function showToast(message) {
    if (!toast) return;
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => {
      toast.classList.remove('show');
    }, 2800);
  }

  // 2. Interactive Dock Simulator Logic
  const appButtons = document.querySelectorAll('.app-select-btn');
  const colorSwatches = document.querySelectorAll('.color-swatch');
  const badgeTextInput = document.getElementById('sim-badge-text');
  const simTargetApp = document.getElementById('sim-target-app');
  const simTargetBadge = document.getElementById('sim-target-badge');
  const simTargetIcon = document.getElementById('sim-target-icon');

  const appData = {
    antigravity: {
      name: 'Antigravity IDE',
      icon: 'assets/icon.png',
      defaultColor: '#3b82f6',
      defaultText: '1'
    },
    chrome: {
      name: 'Google Chrome',
      icon: 'https://cdn.simpleicons.org/googlechrome/ffffff',
      defaultColor: '#10b981',
      defaultText: 'DEV'
    },
    vscode: {
      name: 'VS Code',
      icon: 'https://cdn.simpleicons.org/visualstudiocode/ffffff',
      defaultColor: '#8b5cf6',
      defaultText: '2'
    },
    telegram: {
      name: 'Telegram',
      icon: 'https://cdn.simpleicons.org/telegram/ffffff',
      defaultColor: '#f59e0b',
      defaultText: 'W'
    },
    slack: {
      name: 'Slack',
      icon: 'https://cdn.simpleicons.org/slack/ffffff',
      defaultColor: '#ef4444',
      defaultText: '3'
    },
    figma: {
      name: 'Figma',
      icon: 'https://cdn.simpleicons.org/figma/ffffff',
      defaultColor: '#06b6d4',
      defaultText: 'ALT'
    }
  };

  let currentApp = 'antigravity';
  let currentColor = '#3b82f6';
  let currentText = '1';

  function updateDockSim() {
    if (!simTargetBadge || !simTargetIcon) return;
    simTargetBadge.style.backgroundColor = currentColor;
    simTargetBadge.textContent = currentText || '1';
    simTargetIcon.src = appData[currentApp]?.icon || 'assets/icon.png';

    // Trigger bounce micro-animation
    if (simTargetApp) {
      simTargetApp.style.transform = 'translateY(-14px) scale(1.15)';
      setTimeout(() => {
        simTargetApp.style.transform = '';
      }, 300);
    }
  }

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

        // Activate corresponding swatch
        colorSwatches.forEach(s => {
          s.classList.toggle('active', s.dataset.color.toLowerCase() === currentColor.toLowerCase());
        });

        updateDockSim();
      }
    });
  });

  colorSwatches.forEach(swatch => {
    swatch.addEventListener('click', () => {
      colorSwatches.forEach(s => s.classList.remove('active'));
      swatch.classList.add('active');
      currentColor = swatch.dataset.color;
      updateDockSim();
    });
  });

  if (badgeTextInput) {
    badgeTextInput.addEventListener('input', (e) => {
      currentText = e.target.value.trim().substring(0, 4);
      updateDockSim();
    });
  }

  // 3. FAQ Accordion Logic
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach(item => {
    const questionBtn = item.querySelector('.faq-question');
    if (questionBtn) {
      questionBtn.addEventListener('click', () => {
        const isOpen = item.classList.contains('open');
        faqItems.forEach(i => i.classList.remove('open'));
        if (!isOpen) {
          item.classList.add('open');
        }
      });
    }
  });

  // 4. Product Hunt Banner Click
  const phBanner = document.getElementById('ph-banner');
  if (phBanner) {
    phBanner.addEventListener('click', (e) => {
      e.preventDefault();
      showToast('🚀 Duplix Product Hunt launch page is coming soon!');
    });
  }

  // Initialize Dock Simulation
  updateDockSim();
});
