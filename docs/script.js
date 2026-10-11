document.addEventListener('DOMContentLoaded', () => {
  // 1. Ultra-Premium Page Preloader
  const preloader = document.getElementById('preloader');
  const preloaderBar = document.getElementById('preloader-bar');
  const preloaderStatus = document.getElementById('preloader-status');

  if (preloader && preloaderBar) {
    let progress = 0;
    const interval = setInterval(() => {
      progress += Math.floor(Math.random() * 22) + 16;
      if (progress >= 100) {
        progress = 100;
        clearInterval(interval);
        preloaderBar.style.width = '100%';
        if (preloaderStatus) preloaderStatus.textContent = 'Engine Ready';
        setTimeout(() => {
          preloader.classList.add('fade-out');
          setTimeout(() => preloader.remove(), 600);
        }, 200);
      } else {
        preloaderBar.style.width = progress + '%';
        if (progress > 50 && preloaderStatus) {
          preloaderStatus.textContent = 'Loading Isolated Workspaces...';
        }
      }
    }, 55);
  }

  // 2. Scroll Reveal Engine (Smooth Micro-Animations)
  const revealElements = document.querySelectorAll('.reveal-on-scroll');
  if ('IntersectionObserver' in window) {
    const revealObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('revealed');
          observer.unobserve(entry.target);
        }
      });
    }, {
      root: null,
      threshold: 0.12,
      rootMargin: '0px 0px -40px 0px'
    });

    revealElements.forEach(el => revealObserver.observe(el));
  } else {
    revealElements.forEach(el => el.classList.add('revealed'));
  }

  // 3. Homebrew & CLI Copy Notification
  const cliBox = document.getElementById('cli-copy-box');
  const toast = document.getElementById('toast-notice');
  const toastText = document.getElementById('toast-message');

  if (cliBox) {
    cliBox.addEventListener('click', () => {
      const code = 'curl -fsSL https://businessmanshah-a11y.github.io/Duplix/install.sh | bash';
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

  // 4. Interactive Dock Simulator Logic
  const appButtons = document.querySelectorAll('.app-pill-btn');
  const colorSwatches = document.querySelectorAll('.swatch-item');
  const badgeTextInput = document.getElementById('sim-badge-input');
  const simTargetApp = document.getElementById('sim-target-app');
  const simTargetBadge = document.getElementById('sim-target-badge');
  const simTargetIcon = document.getElementById('sim-target-icon');
  const simOriginalIcon = document.getElementById('sim-original-icon');

  const appData = {
    antigravity: {
      name: 'Antigravity IDE',
      icon: 'assets/logos/antigravity.png',
      defaultColor: '#4f46e5',
      defaultText: '1',
      isFullIcon: true
    },
    cursor: {
      name: 'Cursor',
      icon: 'assets/logos/cursor.svg',
      defaultColor: '#06b6d4',
      defaultText: 'AI',
      isFullIcon: false
    },
    claude: {
      name: 'Claude Desktop',
      icon: 'assets/logos/claude.svg',
      defaultColor: '#d97757',
      defaultText: 'PRO',
      isFullIcon: false
    },
    vscode: {
      name: 'VS Code',
      icon: 'assets/logos/vscode.svg',
      defaultColor: '#007acc',
      defaultText: '2',
      isFullIcon: false
    },
    telegram: {
      name: 'Telegram',
      icon: 'assets/logos/telegram.svg',
      defaultColor: '#0284c7',
      defaultText: 'W',
      isFullIcon: true
    },
    slack: {
      name: 'Slack',
      icon: 'assets/logos/slack.svg',
      defaultColor: '#e11d48',
      defaultText: 'TEAM',
      isFullIcon: false
    },
    figma: {
      name: 'Figma',
      icon: 'assets/logos/figma.svg',
      defaultColor: '#a855f7',
      defaultText: 'ALT',
      isFullIcon: false
    }
  };

  let currentApp = 'antigravity';
  let currentColor = '#4f46e5';
  let currentText = '1';

  function updateDockSim() {
    if (!simTargetBadge || !simTargetIcon) return;
    const targetData = appData[currentApp] || appData.antigravity;

    simTargetBadge.style.backgroundColor = currentColor;
    simTargetBadge.textContent = currentText || '1';
    simTargetIcon.src = targetData.icon;

    if (simOriginalIcon) {
      simOriginalIcon.src = targetData.icon;
    }

    // Toggle padding/background for icon fit
    if (targetData.isFullIcon) {
      simTargetIcon.classList.add('dock-icon-full');
      if (simOriginalIcon) simOriginalIcon.classList.add('dock-icon-full');
    } else {
      simTargetIcon.classList.remove('dock-icon-full');
      if (simOriginalIcon) simOriginalIcon.classList.remove('dock-icon-full');
    }

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

  // 5. FAQ Accordion Logic
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

  // 6. Product Hunt Banner
  const phBanner = document.getElementById('ph-pill-link');
  if (phBanner) {
    phBanner.addEventListener('click', (e) => {
      e.preventDefault();
      showToast('Product Hunt launch campaign ready for submission!');
    });
  }

  // 7. Interactive Showcase Auto-Switching Carousel (Every 3 seconds)
  const showcaseSlides = document.querySelectorAll('.showcase-slide');
  const winTabButtons = document.querySelectorAll('.win-tab-btn');
  const slideIndicators = document.querySelectorAll('.slide-indicator');
  const windowCaption = document.getElementById('window-caption');
  const showcaseContainer = document.querySelector('.mac-window');

  let currentSlide = 0;
  const totalSlides = showcaseSlides.length;
  let slideTimer = null;
  const SLIDE_DURATION = 3000; // 3 seconds exact

  function goToSlide(index) {
    if (totalSlides === 0) return;
    currentSlide = (index + totalSlides) % totalSlides;

    showcaseSlides.forEach((slide, i) => {
      slide.classList.toggle('active', i === currentSlide);
    });

    winTabButtons.forEach((btn, i) => {
      btn.classList.toggle('active', i === currentSlide);
    });

    slideIndicators.forEach((ind, i) => {
      const fill = ind.querySelector('.indicator-fill');
      if (i === currentSlide) {
        ind.classList.add('active');
        if (fill) {
          fill.style.transition = 'none';
          fill.style.width = '0%';
          void fill.offsetWidth; // Trigger reflow
          fill.style.transition = `width ${SLIDE_DURATION}ms linear`;
          fill.style.width = '100%';
        }
      } else {
        ind.classList.remove('active');
        if (fill) {
          fill.style.transition = 'none';
          fill.style.width = '0%';
        }
      }
    });

    const activeSlide = showcaseSlides[currentSlide];
    if (windowCaption && activeSlide) {
      windowCaption.style.opacity = '0';
      setTimeout(() => {
        windowCaption.textContent = activeSlide.dataset.title || 'Duplix Control Center';
        windowCaption.style.opacity = '1';
      }, 150);
    }
  }

  function startAutoPlay() {
    stopAutoPlay();
    slideTimer = setInterval(() => {
      goToSlide(currentSlide + 1);
    }, SLIDE_DURATION);
  }

  function stopAutoPlay() {
    if (slideTimer) {
      clearInterval(slideTimer);
      slideTimer = null;
    }
  }

  winTabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const target = parseInt(btn.dataset.slide, 10);
      goToSlide(target);
      startAutoPlay();
    });
  });

  // Sidebar navigation switching
  const sidebarSwitchItems = document.querySelectorAll('.sidebar-nav-item[data-switch]');
  sidebarSwitchItems.forEach(item => {
    item.addEventListener('click', (e) => {
      e.stopPropagation();
      const target = parseInt(item.dataset.switch, 10);
      goToSlide(target);
      startAutoPlay();
    });
  });

  // Scanner segmented control toggle
  const segItems = document.querySelectorAll('.seg-item');
  segItems.forEach(item => {
    item.addEventListener('click', (e) => {
      e.stopPropagation();
      segItems.forEach(s => s.classList.remove('active'));
      item.classList.add('active');
    });
  });

  slideIndicators.forEach(ind => {
    ind.addEventListener('click', () => {
      const target = parseInt(ind.dataset.slide, 10);
      goToSlide(target);
      startAutoPlay();
    });
  });

  if (showcaseContainer) {
    showcaseContainer.addEventListener('mouseenter', () => stopAutoPlay());
    showcaseContainer.addEventListener('mouseleave', () => startAutoPlay());
  }

  startAutoPlay();

  // Initial render
  updateDockSim();
});
