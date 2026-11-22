# Duplix Cross-Platform Architecture Specification (macOS, Windows, Linux)

> **Document Version:** 2.0.0  
> **Target Platforms:** macOS (Apple Silicon & Intel), Windows 10/11 (x64 & ARM64), Linux (x86_64 & AArch64)  
> **Status:** Phase 2 Architecture & Engine Implemented  

---

## ۱. نمای کلی معماری (Executive Architecture)

ابزار **Duplix** با هدف اجرای همزمان و ایزوله چندین نمونه از هر نرم‌افزار کاربردی (به‌ویژه ابزارهای توسعه، پیام‌رسان‌ها و مرورگرها) طراحی شده است. از آنجا که سیستم‌عامل‌های مختلف ساختار فایل، امنیت و مدیریت پردازش متفاوتی دارند، موتور Duplix از رویکرد بهینه اختصاصی هر سیستم‌عامل برای ارائه حداکثر کارایی با **حجم دیسک مصرفی اولیه صفر** استفاده می‌کند:

| سیستم‌عامل | روش ایزوله‌سازی نشست | مکانیزم شبیه‌سازی فایل | شورتکات و لانچر سیستمی |
| :--- | :--- | :--- | :--- |
| **macOS** | تفکیک `HOME`, Keychain و Bundle ID | APFS Copy-on-Write (`clonefile`) | پکیج `.app` در LaunchServices و داک |
| **Windows** | ایزوله‌سازی پروسه با `--user-data-dir` | شورتکات مستقیم و دیتادیر مجزا (Zero Disk) | فایل `.lnk` در منوی استارت و تسک‌بار |
| **Linux** | سندباکس کانتینری بدون روت با **Bubblewrap** | Btrfs/XFS CoW (`reflink`) یا XDG Bind | فایل استاندارد FreeDesktop (`.desktop`) |

---

## ۲. موتور ویندوز (Windows Engine Architecture)

### ۲.۱. چالش و راه‌حل ویندوز
در ویندوز برنامه‌ها به صورت فایل‌های `.exe` در پوشه `Program Files` نصب می‌شوند و کپی فیزیکی پوشه باعث اشغال حجم بسیار زیاد و تداخل لایسنس یا آپدیت‌ها می‌شود.

**معماری Duplix در ویندوز:**
1. **تولید دیتادیر مستقل:** داده‌های هر کلون در `%LOCALAPPDATA%\Duplix\data\<CloneID>` ایجاد می‌شود.
2. **اتصال خودکار به شورتکات:** شورتکات ویندوز (`.lnk`) با پارامترهای زیر تولید می‌شود:
   ```cmd
   "C:\Program Files\App\app.exe" --user-data-dir="%LOCALAPPDATA%\Duplix\data\<id>" --extensions-dir="%LOCALAPPDATA%\Duplix\data\<id>\Extensions" --password-store=basic
   ```
3. **پشتیبانی از گیت و کلیدهای توسعه‌دهنده:** اسکریپت لانچر به صورت خودکار فایل‌های کانفیگ `.gitconfig` و کلیدهای `.ssh` را از `%USERPROFILE%` به دیتادیر کلون پیوند سخت (Hardlink / Junction) می‌زند.

---

## ۳. موتور لینوکس (Linux Engine Architecture)

### ۳.۱. ایزوله‌سازی با Bubblewrap (`bwrap`)
در لینوکس استاندارد مدرن سندباکس (که توسط Flatpak استفاده می‌شود) Bubblewrap است. Duplix اسکریپت‌های کانتینری سبکی ایجاد می‌کند که بدون دسترسی روت:
1. فایل‌سیستم اصلی را به صورت فقط‌خواندنی (`--ro-bind / /`) مانت می‌کند.
2. مسیرهای حساس کاربر را روی پوشه مجزای کلون ماسک می‌کند:
   - `~/.config` ➔ `~/.local/share/duplix/data/<id>/config`
   - `~/.local/share` ➔ `~/.local/share/duplix/data/<id>/share`
   - `~/.cache` ➔ `~/.local/share/duplix/data/<id>/cache`
3. فایل استاندارد FreeDesktop `.desktop` در مسیر `~/.local/share/applications/` ثبت می‌شود تا در سوئیچر برنامه‌ها و منوی توزیع‌های اوبونتو، فدورا، آرچ و دبیان مستقیماً ظاهر شود.

---

## ۴. ساختار مسیرها در سیستم‌عامل‌ها (Platform Paths Matrix)

```
macOS:
  ├── Config & Registry: ~/Library/Application Support/Duplix/clones.json
  ├── Clones Storage:    ~/Applications/Duplix Clones/<App Name>.app
  └── Data Sessions:     ~/Library/Application Support/Duplix/data/<id>/

Windows:
  ├── Config & Registry: %APPDATA%\Duplix\clones.json
  ├── Start Menu:        %APPDATA%\Microsoft\Windows\Start Menu\Programs\Duplix Clones\
  └── Data Sessions:     %LOCALAPPDATA%\Duplix\data\<id>\

Linux:
  ├── Config & Registry: ~/.config/duplix/clones.json
  ├── Desktop Entries:   ~/.local/share/applications/duplix-*.desktop
  └── Data Sessions:     ~/.local/share/duplix/data/<id>/
```

---

## ۵. تست و یکپارچگی (Testing & Verification)
کلاس‌های `PlatformPaths`، `WindowsLauncherGenerator` و `LinuxLauncherGenerator` به همراه تست‌های خودکار در سوئیت `DuplixTests` به صورت ۱۰۰٪ آزمایش و اعتبارسنجی شده‌اند.
