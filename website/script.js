document.addEventListener('DOMContentLoaded', () => {
  // 1. Mobile Menu Drawer Toggle & Responsiveness
  const mobileMenuBtn = document.getElementById('mobile-menu-btn');
  const mobileNavDrawer = document.getElementById('mobile-nav-drawer');
  const mobileNavLinks = document.querySelectorAll('.mobile-nav-link');

  if (mobileMenuBtn && mobileNavDrawer) {
    mobileMenuBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      const isOpen = mobileNavDrawer.classList.contains('open');
      mobileNavDrawer.classList.toggle('open');
      mobileMenuBtn.classList.toggle('open');
      mobileMenuBtn.setAttribute('aria-expanded', !isOpen);
      mobileNavDrawer.setAttribute('aria-hidden', isOpen);
    });

    mobileNavLinks.forEach(link => {
      link.addEventListener('click', () => {
        mobileNavDrawer.classList.remove('open');
        mobileMenuBtn.classList.remove('open');
        mobileMenuBtn.setAttribute('aria-expanded', 'false');
        mobileNavDrawer.setAttribute('aria-hidden', 'true');
      });
    });

    document.addEventListener('click', (e) => {
      if (!mobileNavDrawer.contains(e.target) && !mobileMenuBtn.contains(e.target) && mobileNavDrawer.classList.contains('open')) {
        mobileNavDrawer.classList.remove('open');
        mobileMenuBtn.classList.remove('open');
        mobileMenuBtn.setAttribute('aria-expanded', 'false');
        mobileNavDrawer.setAttribute('aria-hidden', 'true');
      }
    });
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

  // 8. Interactive Live Playground Switcher (Voicofski + Dock Badging + Duplix Mobile)
  const pgTabs = document.querySelectorAll('.pg-switch-btn');
  const pgVoicofski = document.getElementById('pg-panel-voicofski');
  const pgDock = document.getElementById('pg-panel-dock');
  const pgMobile = document.getElementById('pg-panel-mobile');

  pgTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const target = tab.dataset.pg;
      pgTabs.forEach(t => {
        const isActive = t.dataset.pg === target;
        t.classList.toggle('active', isActive);
        t.setAttribute('aria-selected', isActive ? 'true' : 'false');
      });
      if (pgVoicofski) pgVoicofski.style.display = target === 'voicofski' ? 'grid' : 'none';
      if (pgDock) pgDock.style.display = target === 'dock' ? 'grid' : 'none';
      if (pgMobile) pgMobile.style.display = target === 'mobile' ? 'grid' : 'none';
    });
  });

  // 9. Voicofski Interactive Playground Logic
  const vfSamples = {
    en: {
      text: 'Select any passage across macOS and Duplix turns it into studio speech with zero clutter.',
      translations: {
        persian: 'هر متنی را در مک انتخاب کنید تا دوپلیکس بدون شلوغی آن را به صدای استودیویی تبدیل کند.',
        english: 'Select any passage across macOS and Duplix turns it into studio speech with zero clutter.',
        german: 'Markiere beliebigen Text auf macOS und Duplix verwandelt ihn klar in natürliche Studio-Sprache.',
        french: 'Sélectionnez n’importe quel texte sur macOS et Duplix le transforme en voix naturelle de studio.',
        dutch: 'Selecteer tekst overal op macOS en Duplix zet het direct om in heldere studiospraak.',
        arabic: 'حدد أي نص في نظام ماك وسيحوّله Duplix فوراً إلى صوت طبيعي بجودة استوديو.'
      }
    },
    de: {
      text: 'Guten Morgen! Dein Meeting beginnt in zehn Minuten und der Verkehr auf der Brücke staut sich leicht.',
      translations: {
        persian: 'صبح بخیر! جلسه شما ده دقیقه دیگر شروع می‌شود و ترافیک روی پل کمی سنگین است.',
        english: 'Good morning! Your meeting starts in ten minutes and traffic on the bridge is backing up slightly.',
        german: 'Guten Morgen! Dein Meeting beginnt in zehn Minuten und der Verkehr auf der Brücke staut sich leicht.',
        french: 'Bonjour ! Votre réunion commence dans dix minutes et la circulation sur le pont ralentit légèrement.',
        dutch: 'Goedemorgen! Je vergadering begint over tien minuten en het verkeer op de brug loopt iets vast.',
        arabic: 'صباح الخير! يبدأ اجتماعك خلال عشر دقائق وهناك ازدحام خفيف على الجسر.'
      }
    },
    fr: {
      text: 'Avec la bascule automatique entre plusieurs clés Google AI Studio, vos voix restent toujours prêtes.',
      translations: {
        persian: 'با سوییچ خودکار بین چند کلید Google AI Studio، صدای هوش مصنوعی شما همیشه آماده است.',
        english: 'With automatic failover across multiple Google AI Studio keys, your voices stay ready all day.',
        german: 'Mit automatischem Wechsel zwischen mehreren Google AI Studio Keys bleibt deine Stimme immer bereit.',
        french: 'Avec la bascule automatique entre plusieurs clés Google AI Studio, vos voix restent toujours prêtes.',
        dutch: 'Met automatische omschakeling tussen meerdere Google AI Studio-sleutels blijven je stemmen altijd klaar.',
        arabic: 'مع التبديل التلقائي بين عدة مفاتيح Google AI Studio، تبقى أصواتك جاهزة دائماً.'
      }
    }
  };

  let vfSampleKey = 'en';
  let vfVoice = 'Lora';
  let vfLang = 'persian';
  let vfKeyIndex = 0;
  let vfLoadTimer = null;
  let vfPlayTimer = null;
  let vfPlaying = false;
  let vfProgress = 0;
  let vfRateIdx = 0;
  const vfRates = ['1x', '1.25x', '1.5x'];

  const vfSimText = document.getElementById('vf-sim-text');
  const vfCornerTrigger = document.getElementById('vf-corner-trigger');
  const vfTriggerDot = document.getElementById('vf-trigger-dot');
  const vfActSpeak = document.getElementById('vf-act-speak');
  const vfActTranslate = document.getElementById('vf-act-translate');
  const vfHudIdle = document.getElementById('vf-hud-idle');
  const vfHudLoading = document.getElementById('vf-hud-loading');
  const vfHudPlaying = document.getElementById('vf-hud-playing');
  const vfLoadingTitle = document.getElementById('vf-loading-title');
  const vfLoadingFill = document.getElementById('vf-loading-fill');
  const vfHudCancel = document.getElementById('vf-hud-cancel');
  const vfHudPlayPause = document.getElementById('vf-hud-playpause');
  const vfPlayPauseIcon = document.getElementById('vf-playpause-icon');
  const vfLiveBars = document.getElementById('vf-live-bars');
  const vfLiveSeek = document.getElementById('vf-live-seek');
  const vfLiveSeekFill = document.getElementById('vf-live-seek-fill');
  const vfLiveTime = document.getElementById('vf-live-time');
  const vfHudRate = document.getElementById('vf-hud-rate');
  const vfHudReplay = document.getElementById('vf-hud-replay');
  const vfHudClose = document.getElementById('vf-hud-close');
  const vfReviewCard = document.getElementById('vf-sim-review-card');
  const vfReviewLang = document.getElementById('vf-sim-review-lang');
  const vfReviewBody = document.getElementById('vf-sim-review-body');
  const vfConfirmSpeak = document.getElementById('vf-sim-confirm-speak');
  const vfMenubarStatus = document.getElementById('vf-menubar-status');
  const vfFailoverBtn = document.getElementById('vf-sim-failover');
  const vfKeyPills = document.querySelectorAll('#vf-key-pills .vf-key-pill');

  function vfResetHudToIdle() {
    clearInterval(vfLoadTimer);
    clearInterval(vfPlayTimer);
    vfPlaying = false;
    vfProgress = 0;
    if (vfHudIdle) vfHudIdle.style.display = 'block';
    if (vfHudLoading) vfHudLoading.style.display = 'none';
    if (vfHudPlaying) vfHudPlaying.style.display = 'none';
    if (vfMenubarStatus) vfMenubarStatus.textContent = 'Voicofski Ready';
  }

  function vfStartPlaybackDemo() {
    clearInterval(vfPlayTimer);
    vfPlaying = true;
    vfProgress = 0;
    if (vfHudIdle) vfHudIdle.style.display = 'none';
    if (vfHudLoading) vfHudLoading.style.display = 'none';
    if (vfHudPlaying) vfHudPlaying.style.display = 'flex';
    if (vfLiveBars) vfLiveBars.classList.remove('paused');
    if (vfMenubarStatus) vfMenubarStatus.textContent = `Playing · ${vfVoice}`;
    vfUpdatePlayPauseSvg();

    vfPlayTimer = setInterval(() => {
      if (!vfPlaying) return;
      const rateMult = vfRateIdx === 0 ? 1 : vfRateIdx === 1 ? 1.25 : 1.5;
      vfProgress = Math.min(1, vfProgress + 0.012 * rateMult);
      if (vfLiveSeekFill) vfLiveSeekFill.style.width = `${(vfProgress * 100).toFixed(1)}%`;
      const secs = Math.floor(vfProgress * 8);
      if (vfLiveTime) vfLiveTime.textContent = `00:0${secs}`;
      if (vfProgress >= 1) {
        vfPlaying = false;
        if (vfLiveBars) vfLiveBars.classList.add('paused');
        vfUpdatePlayPauseSvg();
        if (vfMenubarStatus) vfMenubarStatus.textContent = 'Finished (Stays open for Replay)';
      }
    }, 100);
  }

  function vfUpdatePlayPauseSvg() {
    if (!vfPlayPauseIcon) return;
    if (vfPlaying) {
      vfPlayPauseIcon.innerHTML = '<rect x="3" y="2" width="3.5" height="12" rx="1"></rect><rect x="9.5" y="2" width="3.5" height="12" rx="1"></rect>';
    } else {
      vfPlayPauseIcon.innerHTML = '<polygon points="4,2 14,8 4,14"></polygon>';
    }
  }

  function vfRunNonLinearLoading(label, onDone) {
    clearInterval(vfLoadTimer);
    clearInterval(vfPlayTimer);
    if (vfHudIdle) vfHudIdle.style.display = 'none';
    if (vfHudPlaying) vfHudPlaying.style.display = 'none';
    if (vfHudLoading) vfHudLoading.style.display = 'flex';
    if (vfLoadingTitle) vfLoadingTitle.textContent = label;
    if (vfLoadingFill) vfLoadingFill.style.width = '4%';
    if (vfMenubarStatus) vfMenubarStatus.textContent = 'Generating...';

    const start = Date.now();
    vfLoadTimer = setInterval(() => {
      const elapsed = (Date.now() - start) / 1000;
      let pct = 0;
      if (elapsed <= 0.45) {
        pct = 4 + (elapsed / 0.45) * 28; // fast 0 -> 32%
      } else if (elapsed <= 1.25) {
        pct = 32 + ((elapsed - 0.45) / 0.8) * 28; // steady 32 -> 60%
      } else if (elapsed <= 1.8) {
        pct = 60 + ((elapsed - 1.25) / 0.55) * 40; // smooth surge 60 -> 100%
      } else {
        pct = 100;
      }
      if (vfLoadingFill) vfLoadingFill.style.width = `${Math.min(100, pct).toFixed(0)}%`;
      if (pct >= 100) {
        clearInterval(vfLoadTimer);
        onDone();
      }
    }, 40);
  }

  document.querySelectorAll('.vf-sample-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.vf-sample-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      vfSampleKey = btn.dataset.sample || 'en';
      if (vfSimText && vfSamples[vfSampleKey]) {
        vfSimText.textContent = vfSamples[vfSampleKey].text;
      }
      if (vfReviewCard) vfReviewCard.style.display = 'none';
      if (vfCornerTrigger) vfCornerTrigger.classList.remove('expanded');
    });
  });

  document.querySelectorAll('.vf-voice-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.vf-voice-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      vfVoice = btn.dataset.voice || 'Lora';
    });
  });

  document.querySelectorAll('.vf-lang-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.vf-lang-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      vfLang = btn.dataset.lang || 'persian';
      if (vfReviewCard && vfReviewCard.style.display !== 'none') {
        const translated = vfSamples[vfSampleKey].translations[vfLang];
        if (vfReviewLang) vfReviewLang.textContent = `Duplix Review · ${vfLang.charAt(0).toUpperCase() + vfLang.slice(1)}`;
        if (vfReviewBody) {
          vfReviewBody.textContent = translated;
          vfReviewBody.dir = (vfLang === 'persian' || vfLang === 'arabic') ? 'rtl' : 'ltr';
        }
      }
    });
  });

  if (vfTriggerDot && vfCornerTrigger) {
    vfTriggerDot.addEventListener('click', () => {
      vfCornerTrigger.classList.add('expanded');
    });
  }

  if (vfActSpeak) {
    vfActSpeak.addEventListener('click', () => {
      if (vfCornerTrigger) vfCornerTrigger.classList.remove('expanded');
      if (vfReviewCard) vfReviewCard.style.display = 'none';
      vfRunNonLinearLoading(`Generating voice (${vfVoice})...`, vfStartPlaybackDemo);
    });
  }

  if (vfActTranslate) {
    vfActTranslate.addEventListener('click', () => {
      if (vfCornerTrigger) vfCornerTrigger.classList.remove('expanded');
      const langTitle = vfLang.charAt(0).toUpperCase() + vfLang.slice(1);
      vfRunNonLinearLoading(`Translating to ${langTitle}...`, () => {
        vfResetHudToIdle();
        if (vfReviewCard && vfReviewBody && vfReviewLang) {
          vfReviewLang.textContent = `Duplix Review · ${langTitle}`;
          vfReviewBody.textContent = vfSamples[vfSampleKey].translations[vfLang];
          vfReviewBody.dir = (vfLang === 'persian' || vfLang === 'arabic') ? 'rtl' : 'ltr';
          vfReviewCard.style.display = 'flex';
        }
        if (vfMenubarStatus) vfMenubarStatus.textContent = 'Review Translation in Duplix';
      });
    });
  }

  if (vfConfirmSpeak) {
    vfConfirmSpeak.addEventListener('click', () => {
      vfRunNonLinearLoading(`Speaking ${vfLang} (${vfVoice})...`, vfStartPlaybackDemo);
    });
  }

  if (vfHudPlayPause) {
    vfHudPlayPause.addEventListener('click', () => {
      if (vfProgress >= 1) {
        vfStartPlaybackDemo();
        return;
      }
      vfPlaying = !vfPlaying;
      if (vfLiveBars) vfLiveBars.classList.toggle('paused', !vfPlaying);
      vfUpdatePlayPauseSvg();
    });
  }

  if (vfHudReplay) {
    vfHudReplay.addEventListener('click', () => vfStartPlaybackDemo());
  }

  if (vfHudRate) {
    vfHudRate.addEventListener('click', () => {
      vfRateIdx = (vfRateIdx + 1) % vfRates.length;
      vfHudRate.textContent = vfRates[vfRateIdx];
    });
  }

  if (vfLiveSeek) {
    vfLiveSeek.addEventListener('click', (e) => {
      const rect = vfLiveSeek.getBoundingClientRect();
      vfProgress = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
      if (vfLiveSeekFill) vfLiveSeekFill.style.width = `${(vfProgress * 100).toFixed(1)}%`;
      const secs = Math.floor(vfProgress * 8);
      if (vfLiveTime) vfLiveTime.textContent = `00:0${secs}`;
    });
  }

  if (vfHudCancel) vfHudCancel.addEventListener('click', vfResetHudToIdle);
  if (vfHudClose) vfHudClose.addEventListener('click', vfResetHudToIdle);

  if (vfFailoverBtn && vfKeyPills.length > 0) {
    vfFailoverBtn.addEventListener('click', () => {
      vfKeyIndex = (vfKeyIndex + 1) % vfKeyPills.length;
      vfKeyPills.forEach((pill, i) => {
        pill.classList.remove('active', 'exhausted', 'standby');
        if (i < vfKeyIndex) {
          pill.classList.add('exhausted');
          pill.innerHTML = `<span class="vf-kdot"></span>Gmail #${i + 1} · 429 Cooldown`;
        } else if (i === vfKeyIndex) {
          pill.classList.add('active');
          pill.innerHTML = `<span class="vf-kdot"></span>Gmail #${i + 1} · Active`;
        } else {
          pill.classList.add('standby');
          pill.innerHTML = `<span class="vf-kdot"></span>Gmail #${i + 1} · Standby`;
        }
      });
      if (vfKeyIndex === 0) {
        showToast('09:00 UTC Reset — All API keys automatically recovered!');
      } else {
        showToast(`Key #${vfKeyIndex} hit 429 quota — auto-switched to Gmail #${vfKeyIndex + 1}!`);
      }
    });
  }

  // ==========================================
  // 10. Duplix Mobile Interactive Simulator
  // ==========================================
  const phoneViews = {
    clones: document.getElementById('phone-view-clones'),
    voice: document.getElementById('phone-view-voice'),
    memo: document.getElementById('phone-view-memo')
  };

  const mobNavBtns = document.querySelectorAll('.mob-nav-btn');
  const mobSwitchBtns = {
    clones: document.getElementById('mob-switch-clones'),
    voice: document.getElementById('mob-switch-voice'),
    memo: document.getElementById('mob-switch-memo')
  };

  function setMobileView(mode) {
    Object.keys(phoneViews).forEach(key => {
      const view = phoneViews[key];
      if (view) view.style.display = key === mode ? 'flex' : 'none';
    });

    mobNavBtns.forEach(btn => {
      btn.classList.toggle('active', btn.dataset.target === mode);
    });

    Object.keys(mobSwitchBtns).forEach(key => {
      const btn = mobSwitchBtns[key];
      if (btn) btn.classList.toggle('active', key === mode);
    });
  }

  mobNavBtns.forEach(btn => {
    btn.addEventListener('click', () => setMobileView(btn.dataset.target));
  });

  if (mobSwitchBtns.clones) mobSwitchBtns.clones.addEventListener('click', () => setMobileView('clones'));
  if (mobSwitchBtns.voice) mobSwitchBtns.voice.addEventListener('click', () => setMobileView('voice'));
  if (mobSwitchBtns.memo) mobSwitchBtns.memo.addEventListener('click', () => setMobileView('memo'));

  // Mobile Clone Freeze Toggles
  document.addEventListener('click', e => {
    const freezeBtn = e.target.closest('.mob-freeze-toggle');
    if (freezeBtn) {
      const item = freezeBtn.closest('.mobile-clone-item');
      const isCurrentlyActive = freezeBtn.classList.contains('active');
      if (isCurrentlyActive) {
        freezeBtn.classList.remove('active');
        freezeBtn.textContent = 'Frozen';
        if (item) item.classList.add('frozen');
        showToast('Clone frozen: Background sync paused (0% battery)');
      } else {
        freezeBtn.classList.add('active');
        freezeBtn.textContent = 'Active';
        if (item) item.classList.remove('frozen');
        showToast('Clone active: Background sync & push notifications restored');
      }
    }
  });

  // Add 5th clone button
  const addCloneBtn = document.getElementById('mob-add-clone-btn');
  const clonesContainer = document.getElementById('mobile-clones-container');
  let addedTelegram = false;

  if (addCloneBtn && clonesContainer) {
    addCloneBtn.addEventListener('click', () => {
      if (addedTelegram) {
        showToast('Telegram clone is already running in Work Profile!');
        setMobileView('clones');
        return;
      }
      addedTelegram = true;
      const tgClone = document.createElement('div');
      tgClone.className = 'mobile-clone-item';
      tgClone.id = 'mob-clone-5';
      tgClone.innerHTML = `
        <div class="mob-clone-icon-wrap" style="border-color:#06b6d4;">
          <img src="assets/logos/telegram.svg" alt="Telegram" class="mob-app-img" onerror="this.src='assets/logos/antigravity.png'">
          <span class="mob-clone-badge" style="background:#06b6d4;">TG 2</span>
        </div>
        <div class="mob-clone-meta">
          <span class="mob-clone-title">Telegram (Work)</span>
          <span class="mob-clone-sub">Profile 4 • @team_leads</span>
        </div>
        <button class="mob-freeze-toggle active" title="Toggle Freeze" data-clone="5">Active</button>
      `;
      clonesContainer.appendChild(tgClone);
      addCloneBtn.innerHTML = `✓ 5th Clone Active (Telegram)`;
      addCloneBtn.disabled = true;
      showToast('Telegram successfully provisioned into Work Profile Sandbox!');
      setMobileView('clones');
    });
  }

  // Voice Memo Mobile Simulation
  const recordCircle = document.getElementById('mob-record-circle');
  const recordStatus = document.getElementById('mob-record-status');
  const recordTimer = document.getElementById('mob-record-timer');
  let isRecording = false;
  let recordInterval = null;
  let recordSeconds = 0;

  if (recordCircle) {
    recordCircle.addEventListener('click', () => {
      isRecording = !isRecording;
      recordCircle.classList.toggle('recording', isRecording);
      if (isRecording) {
        recordStatus.textContent = 'Recording Audio...';
        recordStatus.style.color = '#ef4444';
        recordSeconds = 0;
        recordInterval = setInterval(() => {
          recordSeconds++;
          const mins = String(Math.floor(recordSeconds / 60)).padStart(2, '0');
          const secs = String(recordSeconds % 60).padStart(2, '0');
          if (recordTimer) recordTimer.textContent = `${mins}:${secs}`;
        }, 1000);
        showToast('Microphone active. Recording voice memo...');
      } else {
        clearInterval(recordInterval);
        recordStatus.textContent = 'Tap to Record';
        recordStatus.style.color = '#e2e8f0';
        showToast(`Voice memo recorded (${recordSeconds}s) & saved to clipboard!`);
        if (recordTimer) recordTimer.textContent = '00:00';
      }
    });
  }

  // Voicofski play button inside phone
  const mobVoicePlayBtn = document.getElementById('mob-play-voice-btn');
  if (mobVoicePlayBtn) {
    mobVoicePlayBtn.addEventListener('click', () => {
      showToast('Streaming audio with Google AI Studio (gemini-3.8-flash-tts)...');
    });
  }

  // Jump to mobile simulator link from download card
  const jumpToMobBtn = document.getElementById('jump-to-mobile-sim');
  const mobTabBtn = document.getElementById('pg-tab-mobile');
  if (jumpToMobBtn && mobTabBtn) {
    jumpToMobBtn.addEventListener('click', e => {
      e.preventDefault();
      mobTabBtn.click();
      const simSection = document.getElementById('simulator');
      if (simSection) {
        simSection.scrollIntoView({ behavior: 'smooth' });
      }
    });
  }
});
