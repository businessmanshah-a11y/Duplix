# Duplix — سند جامع طراحی و معماری فیچر Voicofski

> **Feature Name:** Voicofski (`voicofski`)  
> **Parent App:** Duplix (Native macOS — Swift 6 / SwiftUI / AppKit, macOS 13+)  
> **AI Engine:** Google AI Studio (Gemini REST API — BYOK Multi-Key Pool)  
> **UI Language:** English (Minimal, Icon-Driven, Uncluttered)  
> **Status:** Design Specification (Finalized — Ready for Implementation)

---

## ۱. نمای کلی فیچر (Executive Overview)

**Voicofski** یک ماژول مستقل تبدیل متن به صوت (Text-to-Speech) و ترجمه هوشمند به صوت (Translate + TTS) در اپلیکیشن **Duplix** است که کاملاً بومی برای macOS طراحی شده است.

برخلاف `Voice Memo` (که برای **ضبط صدا** با میکروفون است)، **Voicofski** برای **تولید صوت طبیعی از متن** طراحی شده و به صورت یک تب مجزا در سایدبار Duplix قرار می‌گیرد.

### دو نقطه ورود اصلی (Entry Points)
1. **پاپ‌آپ شناور سراسری روی کل سیستم (System-Wide Selection Trigger):** کاربر در هر برنامه‌ای روی مک، متنی (حداقل ۳ کاراکتر) را با موس سلکت می‌کند ← یک دکمه کوچک و غیرمزاحم در گوشه متن ظاهر می‌شود ← با کلیک روی آن، دو دکمه صرفاً آیکونی (**تبدیل مستقیم به صوت** و **ترجمه + صوت**) باز می‌شوند.
2. **باکس مستقیم داخل اپلیکیشن (In-App Composer):** در تب `Voicofski` داخل Duplix، کاربر می‌تواند هر متنی را مستقیماً Paste یا تایپ کند، حالت عادی یا ترجمه را انتخاب کند و خروجی صوتی بگیرد.

---

## ۲. جریان کار کاربر (End-to-End User Flows)

### ۲.۱ جریان الف — تبدیل مستقیم متن سلکت‌شده به صوت (Direct TTS)

```
┌──────────────────────────────────────────────────────────────────────┐
│  کاربر در هر اپ مک متنی (>= ۳ کاراکتر) را با موس سلکت می‌کند          │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│  ظاهر شدن دکمه کوچک شناور (Collapsed Accent Trigger) در گوشه متن     │
│  • اگر سلکت پاک شود یا ۱۰ ثانیه بی‌استفاده بماند ← محو می‌شود         │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │ (کاربر روی دکمه کوچک کلیک می‌کند)
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│  باز شدن ۲ دکمه صرفاً آیکونی (بدون متن، بدون ایموجی):                  │
│   [ 🔊 Direct TTS ]    [ 🌐 Translate + TTS ]                        │
└──────────────┬───────────────────────────────────────┬───────────────┘
               │ (کلیک روی Direct TTS)                 │ (کلیک روی Translate)
               ▼                                       ▼
┌──────────────────────────────┐       ┌───────────────────────────────┐
│  چک کردن تعداد کلمات:         │       │  ترجمه با Gemini Text API    │
│  اگر > ۵۰۰ کلمه ← هشدار توکن │       │  (زبان مبدا خودکار → مقصد)    │
└──────────────┬───────────────┘       └───────────────┬───────────────┘
               │ (تایید / <= ۵۰۰)                      │
               ▼                                       ▼
┌──────────────────────────────┐       ┌───────────────────────────────┐
│  اگر پلیر دیگری در حال پخش   │       │  باز شدن/فوکوس پنجره Duplix   │
│  نیست ← باز شدن Notch HUD   │       │  روی تب Voicofski و نمایش     │
│  (انیمیشن لودینگ غیرخطی)     │       │  متن ترجمه‌شده برای بررسی/تایید│
│  اگر در حال پخشه ← صف پخش    │       └───────────────┬───────────────┘
└──────────────┬───────────────┘                       │ (تایید کاربر)
               │                                       ▼
               │                       ┌───────────────────────────────┐
               │                       │  ارسال متن تاییدشده به TTS    │
               └───────────┬───────────┘  و باز شدن Notch HUD         │
                           ▼           └───────────────────────────────┘
┌──────────────────────────────────────────────────────────────────────┐
│  تولید صوت با Gemini TTS + ذخیره فایل .wav در تاریخچه محلی           │
│  ← پخش خودکار در Notch HUD (با Seekbar، Visualizer، Replay، Close)  │
└──────────────────────────────────────────────────────────────────────┘
```

### ۲.۲ جریان ب — ساخت صوت مستقیم داخل اپلیکیشن (In-App Composer)
1. کاربر وارد تب **Voicofski** در سایدبار Duplix می‌شود.
2. متن را در باکس مینیمال وارد می‌کند.
3. دو حالت در دسترس است:
   - **Direct Mode:** متن به هر زبانی که هست مستقیماً تبدیل به صوت می‌شود.
   - **Translate Mode:** کاربر زبان مقصد را از بین ۶ زبان پشتیبانی‌شده انتخاب می‌کند ← ابتدا ترجمه تولید و نمایش داده می‌شود ← کاربر پس از بررسی/ویرایش دکمه تولید صوت را می‌زند.

---

## ۳. قوانین UX و طراحی رابط کاربری (UI/UX Specification)

> **اصل کلیدی طراحی:** تمام رابط کاربری Voicofski به زبان **انگلیسی**، کاملاً **خلوت، مینیمال و بومی SwiftUI** خواهد بود؛ بدون متن‌های توضیحی اضافه و **مطلقاً بدون استفاده از ایموجی** در دکمه‌های شناور و پلیر (صرفاً SF Symbols و آیکون‌های برداری تمیز).

### ۳.۱ پاپ‌آپ شناور سلکت متن (`SelectionTriggerPanel`)
- **شرط فعال‌سازی:** صرفاً با **سلکت موس** (بدون شورتکات کیبورد سراسری و بدون لیست اپ‌های مستثنی).
- **حداقل طول متن:** `>= 3` کاراکتر (پس از حذف فضاهای خالی ابتدا و انتها). کمتر از ۳ کاراکتر هیچ پاپ‌آپی ظاهر نمی‌شود.
- **مکان‌یابی هوشمند بدون مزاحمت:**
  - به صورت پیش‌فرض در **گوشه بالا (سمت چپ یا راست)** ناحیه سلکت‌شده ظاهر می‌شود تا روی متن نیفتد و مزاحم خواندن نشود.
  - اگر ناحیه بالایی نزدیک لبه بالای مانیتور یا خارج از کادر قابل‌مشاهده باشد، به صورت خودکار به **گوشه پایین** ناحیه سلکت‌شده منتقل (Flip) می‌شود.
- **تعامل دو مرحله‌ای (Two-Stage Micro-UI):**
  1. **حالت جمع‌شده (Collapsed):** یک دکمه دایره‌ای/کپسولی بسیار ظریف (با رنگ Accent قرمز/نارنجی و آیکون مینیمال) که دید کاربر را اشغال نمی‌کند.
  2. **حالت بازشده (Expanded — پس از کلیک روی دکمه اولیه):** باز شدن نرم ۲ دکمه صرفاً آیکونی:
     - آیکون **صوت (Direct TTS):** مثلاً `waveform` یا `speaker.wave.2.fill`
     - آیکون **ترجمه (Translate + TTS):** مثلاً `translate` (SF Symbol)
- **شرایط بسته شدن خودکار (Auto-Dismiss):**
  - به محض پاک شدن سلکت (Deselect) یا کلیک کاربر در فضای بیرون.
  - پس از انجام کپی (`Cmd+C`) و خروج از حالت سلکت.
  - در صورت کلیک نکردن و باقی ماندن سلکت به مدت بیش از **۱۰ ثانیه** (Auto-hide timeout).
  - با زدن کلید `Esc` یا اسکرول صفحه.

### ۳.۲ پلیر شناور زیر ناچ (`NotchPlayerPanel`)
- **مکان‌یابی (Positioning):**
  - در مک‌بوک‌های دارای ناچ: دقیقاً **زیر ناچ** در مرکز بالای صفحه.
  - در مک‌های بدون ناچ یا مانیتور دوم/اکسترنال: **بالا و وسط همان مانیتوری که نشانگر موس روی آن قرار دارد**، دقیقاً زیر Menu Bar.
  - رفتار پنجره: `NSPanel` از نوع `.nonactivatingPanel` و `.borderless`، شناور روی تمام فضاها (`canJoinAllSpaces`, `fullScreenAuxiliary`) با افکت شیشه‌ای تیره (`NSVisualEffectView` با `.hudWindow` مشابه `FloatingPillPanel` فعلی Duplix).

- **حالت ۱ — در حال پردازش (Loading State):**
  - آیکون متحرک/سه‌بعدی با انیمیشن موج (Pulse / Wave) برای القای حس زنده بودن.
  - **منحنی پیشرفت غیرخطی (Non-Linear Progress Curve):**
    - `0% → 30%`: حرکت سریع اولیه (بازخورد فوری به کاربر).
    - `30% → 60%`: حرکت آرام‌تر و پیوسته در حین انتظار پاسخ API.
    - `60% → 85%`: افزایش سرعت نرم و سپس تکمیل تا `100%` به محض دریافت صوت.
  - دکمه **Cancel** برای لغو درخواست در حین ساخت.

- **حالت ۲ — در حال پخش و آماده (Playback State):**
  - پخش خودکار به محض آماده شدن فایل صوتی.
  - اجزای پلیر:
    - **موج صدا (Audio Waveform Visualizer):** رقص میله‌های صوتی هماهنگ با سطح صدای واقعی پخش (با الگوگیری از `AudioMeterView` موجود در Duplix).
    - **نوار پیشرفت قابل جابه‌جایی (Scrubbable Seekbar)** به همراه زمان سپری‌شده و کل مدت زمان.
    - کنترل‌های اصلی: **Play / Pause**، **Replay** (پخش مجدد از ابتدا)، **Close (`×`)**، و دکمه کوچک **تغییر سرعت** در پلیر (`1x` / `1.25x` / `1.5x`) به شکل کاملاً جمع‌وجور.
  - **رفتار پس از پایان پخش:** پنجره به صورت خودکار **بسته نمی‌شود** و باز می‌ماند تا کاربر در صورت تمایل دوباره Replay بزند یا با دکمه `×` آن را ببندد.

- **حالت ۳ — صف پخش همزمان (Playback Queue):**
  - اگر صدایی در حال پخش باشد و کاربر وسط آن متن جدیدی را سلکت کرده و درخواست ویس جدید بدهد:
    - صدای فعلی **قطع نمی‌شود**.
    - صوت جدید در پس‌زمینه ساخته شده و به **صف پخش (Playback Queue)** اضافه می‌شود.
    - یک نشانگر/اعلان ظریف روی HUD (یا Notification کوتاه) نمایش داده می‌شود که صوت جدید در صف آماده است (مثلاً بج `+1`).
    - به محض اینکه کاربر پلیر فعلی را ببندد (یا روی Next بزند)، آیتم بعدی صف به صورت خودکار باز و پخش می‌شود.

### ۳.۳ تب Voicofski در پنجره اصلی Duplix (`VoicofskiView`)
ساختار خلوت و منظم با ۴ بخش اصلی (قابل دسترسی به صورت تمیز و بدون شلوغی):
1. **Header & Toggle:** عنوان `Voicofski`، سوییچ روشن/خاموش کردن کل فیچر (Selection Trigger)، وضعیت سریع Accessibility، و دکمه باز کردن راهنمای دریافت API Key.
2. **Composer (Direct / Translate):**
   - باکس ورود متن + نمایشگر تعداد کلمات (نمایش هشدار هنگام عبور از **۵۰۰ کلمه**).
   - سگمنت ساده برای انتخاب حالت: `Speak` / `Translate & Speak`.
   - انتخابگر زبان مقصد (در حالت ترجمه) و انتخابگر صدا (`Female` / `Male`).
   - هنگام ورود از دکمه شناور Translate، متن ترجمه‌شده مستقیماً در این بخش نمایش داده می‌شود تا کاربر پس از بررسی، دکمه **Generate Voice** را بزند.
3. **History & Pending Queue:**
   - **History:** لیست ویس‌های تولیدشده (نمایش خلاصه متن اصلی/ترجمه‌شده، تاریخ، مدت زمان، صدای استفاده‌شده) با امکان پخش مجدد فوری، کپی متن، ذخیره/Export فایل `.wav` و حذف.
   - **Pending Queue:** نمایش متن‌هایی که در زمان اتمام سهمیه کلیدها در نوبت ذخیره شده‌اند (با امکان پردازش خودکار یا دستی پس از باز شدن سهمیه).
4. **API Keys & Quick Guide (Sheet / Section):**
   - لیست API Keyهای کاربر (نام/برچسب دلخواه، وضعیت سلامت، دکمه `Test Key`، جابه‌جایی اولویت، حذف، افزودن).
   - **راهنمای قدم‌به‌قدم کوتاه و مینیمال** برای ساخت کلید رایگان در Google AI Studio به همراه لینک مستقیم (`https://aistudio.google.com/apikey`).

### ۳.۴ یکپارچگی با منوبار (Unified Menu Bar)
- اپلیکیشن Duplix یک **آیکون واحد در Menu Bar** خواهد داشت که دسترسی سریع به هر دو ماژول مجزا را فراهم می‌کند:
  - بخش `Voice Memo` (ضبط صدا)
  - بخش `Voicofski` (روشن/خاموش کردن Selection Trigger، وضعیت کلید فعال، تعداد آیتم‌های صف، باز کردن Voicofski)
- دسترسی **Accessibility** بین هر دو ماژول مشترک مدیریت می‌شود.

---

## ۴. تنظیمات زبان‌ها، صداها و محدودیت متن

### ۴.۱ زبان‌های مقصد پشتیبانی‌شده در ترجمه (۶ زبان)
تشخیص زبان مبدا به صورت کاملاً خودکار (`Auto-detect`) انجام می‌شود. زبان‌های مقصد:

| # | زبان | کد استاندارد | نام در UI |
| :-: | :--- | :---: | :--- |
| ۱ | فارسی | `fa` | Persian |
| ۲ | انگلیسی | `en` | English |
| ۳ | آلمانی | `de` | German |
| ۴ | فرانسوی | `fr` | French |
| ۵ | هلندی | `nl` | Dutch |
| ۶ | عربی | `ar` | Arabic |

### ۴.۲ صداها و لحن خواندن
- **مدل TTS منتخب:** `gemini-3.8-flash-tts`
- **۲ صدای از پیش انتخاب‌شده از Google AI Studio:**
  - `Female`: **`Lora`** *(Clear and friendly · Medium pitch)*
  - `Male`: **`Bodi`** *(Quiet and intimate · Low pitch)*
- **لحن خواندن:** عادی و طبیعی (بدون تنظیمات پیچیده لحن یا سرعت پیش‌فرض در Settings).

### ۴.۳ هشدار متن طولانی (Long Text Warning)
- **آستانه هشدار:** بیش از **۵۰۰ کلمه** (`wordCount > 500`).
- در صورت عبور متن از ۵۰۰ کلمه (چه در حالت سلکت و چه در Composer)، قبل از ارسال درخواست به API یک هشدار نمایش داده می‌شود که متن طولانی است و ممکن است به محدودیت توکن/سهمیه بخورد؛ کاربر می‌تواند انتخاب کند که **ادامه دهد (Continue)** یا **لغو/اصلاح کند (Cancel)**.

### ۴.۴ رفتار تکرار متن و کش
- فایل‌های صوتی ساخته‌شده به صورت دائمی در **تاریخچه محلی** ذخیره می‌شوند و کاربر می‌تواند از بخش History بدون مصرف سهمیه مجدد به آن‌ها گوش دهد.
- با این حال، اگر کاربر روی صفحه دوباره همان متن تکراری را سلکت کند و روی دکمه بزند، سیستم **درخواست را مجدداً اجرا می‌کند و صدای جدید می‌سازد** (کش مخفی مانع ساخت مجدد نمی‌شود).

---

## ۵. معماری فنی و جزئیات پیاده‌سازی در macOS

### ۵.۱ مکانیزم تشخیص سلکت متن (Hybrid Accessibility + Clipboard Fallback)
برای حداکثر سازگاری با تمامی برنامه‌های macOS (اپ‌های Native، Safari، Chrome، Electron، PDFها):

1. **نظارت بر رویداد موس (Global Mouse Monitor):**
   - گوش دادن به `leftMouseUp` (پس از Drag با فاصله حرکت `>= 4pt` یا Double/Triple-click) از طریق `NSEvent.addGlobalMonitorForEvents`.
   - تاخیر کوتاه (~`150ms`) برای پایدار شدن سلکت در اپ مبدا و جلوگیری از نمایش‌های ناخواسته.
2. **روش اول — Accessibility API (Primary):**
   - خواندن المان فوکوس‌شده (`kAXFocusedUIElementAttribute`) از `AXUIElementCreateSystemWide()`.
   - خواندن متن سلکت‌شده با `kAXSelectedTextAttribute`.
   - خواندن مختصات دقیق ناحیه سلکت با `kAXSelectedTextRangeAttribute` + `kAXBoundsForRangeParameterizedAttribute` جهت قرار دادن دقیق دکمه شناور در گوشه متن (در صورت نبودن Bounds، استفاده از مختصات `NSEvent.mouseLocation` به عنوان مرجع).
3. **روش دوم — Clipboard Fallback (فقط هنگام کلیک کاربر):**
   - اگر در اپ‌های خاص (مانند برخی اپ‌های Electron یا PDF Viewerها) Accessibility متن را برنگرداند اما کاربر درگ موس انجام داده باشد، در زمان کلیک روی دکمه شناور:
     1. محتوای فعلی `NSPasteboard.general` (تمام انواع داده) بکاپ گرفته می‌شود.
     2. کلید ترکیبی `Cmd+C` از طریق `CGEvent` شبیه‌سازی می‌شود.
     3. پس از ~`80ms` متن جدید از Pasteboard خوانده می‌شود.
     4. بلافاصله محتوای قبلی Pasteboard عیناً بازگردانی (Restore) می‌شود تا کلیپ‌بورد کاربر دست‌نخورده بماند.

---

## ۶. معماری Google AI Studio API و مدیریت چند کلید (Multi-Key Pool)

### ۶.۱ مسیرهای API (Endpoints & Payloads)

تمام درخواست‌ها مستقیماً از طریق `URLSession` بومی Swift (بدون وابستگی خارجی) ارسال می‌شوند. کلید API در هدر `x-goog-api-key` قرار می‌گیرد.

#### الف) اعتبارسنجی کلید (`Test Key` — بدون مصرف توکن تولید)
- **Method & URL:** `GET https://generativelanguage.googleapis.com/v1beta/models?pageSize=1`
- **Header:** `x-goog-api-key: <API_KEY>`
- **نتیجه:**
  - `200 OK` ← کلید معتبر (`valid`)
  - `400 / 401 / 403 (API_KEY_INVALID)` ← کلید نامعتبر (`invalid`)
  - `403 (FAILED_PRECONDITION / Location not supported)` ← خطای منطقه جغرافیایی / نیاز به VPN

#### ب) مرحله ترجمه (`Translate`)
- **Method & URL:** `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`
- **Headers:** `x-goog-api-key: <API_KEY>`, `Content-Type: application/json`
- **Request Body:**
```json
{
  "systemInstruction": {
    "parts": [
      {
        "text": "You are a precise translator. Translate the user's text naturally into <TARGET_LANGUAGE>. Return ONLY the translated text without explanations, quotes, or extra formatting."
      }
    ]
  },
  "contents": [
    {
      "parts": [
        {
          "text": "<SELECTED_TEXT>"
        }
      ]
    }
  ]
}
```
- **Response Parsing:** استخراج متن از `candidates[0].content.parts[0].text`.

#### ج) مرحله تولید صوت (`Text-to-Speech`)
- **Method & URL:** `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash-tts:generateContent`
- **Headers:** `x-goog-api-key: <API_KEY>`, `Content-Type: application/json`
- **Request Body:**
```json
{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "<TEXT_TO_SPEAK>"
        }
      ]
    }
  ],
  "generationConfig": {
    "temperature": 1,
    "responseModalities": ["AUDIO"],
    "speechConfig": {
      "voiceConfig": {
        "prebuiltVoiceConfig": {
          "voiceName": "Lora"
        }
      }
    }
  }
}
```
*(مقدار `voiceName` برای صدای خانم `"Lora"` و برای صدای آقا `"Bodi"` خواهد بود.)*
- **Response Parsing & Audio Conversion:**
  - داده صوتی به صورت Base64 در `candidates[0].content.parts[*].inlineData.data` همراه با `inlineData.mimeType` (معمولاً `audio/L16;rate=24000`) برمی‌گردد.
  - ماژول `PCMWavEncoder` در Swift پارامترهای `bitsPerSample` (از `audio/L<bits>`، پیش‌فرض `16`) و `sampleRate` (از `rate=<hz>`، پیش‌فرض `24000`) را به صورت داینامیک از `mimeType` پارس کرده، هدر استاندارد ۴۴ بایتی **RIFF/WAV** را به ابتدای بایت‌های PCM اضافه می‌کند و فایل `.wav` نهایی را می‌سازد (قابل پخش مستقیم با `AVAudioPlayer` همراه با Metering برای Visualizer و Seek دقیق).

---

### ۶.۲ الگوریتم مدیریت چند API Key و سوییچ خودکار (`APIKeyPoolManager`)

#### امنیت ذخیره‌سازی
- **کلیدهای محرمانه (`apiKey`):** ذخیره امن در **macOS Keychain** با استفاده از `Security.framework` (`kSecClassGenericPassword`, Service: `com.duplix.voicofski.apikeys`, Account: `<key_uuid>`).
- **متادیتای غیرمحرمانه** (نام/برچسب، ترتیب، وضعیت، زمان ریست بعدی): ذخیره در `keys_metadata.json` در پوشه دیتای Voicofski.

#### استراتژی مصرف و سوییچ (Sequential Failover)
1. کلیدها بر اساس ترتیب تعریف‌شده کاربر (`orderIndex`) به صورت **پشت‌سرهم (Sequential)** استفاده می‌شوند.
2. سیستم همیشه از اولین کلید با وضعیت `active` استفاده می‌کند.
3. اگر درخواست با خطای `429 Too Many Requests` (`RESOURCE_EXHAUSTED`) مواجه شد:
   - کلید فعلی به وضعیت `exhausted` تغییر کرده و زمان بازگشت آن (`nextResetAt`) روی **نزدیک‌ترین ساعت `09:00 UTC` بعدی** تنظیم می‌شود. *(توضیح: سهمیه روزانه Google AI Studio حوالی `08:00 UTC` معادل نیمه‌شب PT / ۱۱:۳۰ صبح ایران ریست می‌شود؛ یک ساعت حاشیه اطمینان لحاظ شده و زمان در UI بر اساس تایم‌زون محلی سیستم کاربر نمایش داده می‌شود).*
   - سیستم **بلافاصله و به صورت خودکار** درخواست را روی کلید `active` بعدی تکرار می‌کند (بدون نیاز به دخالت کاربر).
4. پس از عبور ساعت سیستم از `09:00 UTC`، کلیدهای `exhausted` مجدداً به وضعیت `active` بازمی‌گردند. اگر هنگام مصرف مجدد دوباره `429` گرفتند، مجدداً تا پنجره بعدی `exhausted` می‌شوند.

#### سناریوی اتمام همه کلیدها (All Keys Exhausted → Pending Queue)
- سیستم **هرگز کاربر را از سلکت کردن متن محدود نمی‌کند**.
- در صورت اتمام سهمیه تمام کلیدها:
  1. یک پیام خطای شفاف نمایش داده می‌شود (`All API keys have reached their daily quota. Request saved to Pending Queue.`).
  2. درخواست فعلی (متن، نوع عملیات، زبان مقصد و صدای انتخابی) به صورت خودکار در **صف انتظار سهمیه (`Pending Queue`)** ذخیره می‌شود.
  3. به محض اینکه کاربر کلید جدیدی اضافه کند یا ساعت `09:00 UTC` فرا برسد و کلیدی آزاد شود، آیتم‌های داخل Pending Queue آماده اجرا شده و به کاربر اطلاع داده می‌شود (یا پردازش می‌شوند).

#### مدیریت شبکه و VPN
- مدیریت VPN بر عهده کاربر است (تنظیمات Custom Proxy در UI قرار نمی‌گیرد).
- در صورت بروز خطای شبکه یا محدودیت جغرافیایی (`403` / timeout / offline)، پیام کوتاه و دقیق نمایش داده می‌شود (مثلاً `Connection failed — please check your VPN or internet connection.`).

---

## ۷. ساختار فایل‌ها، مدل‌های داده و مسیرهای ذخیره‌سازی

### ۷.۱ مسیرهای ذخیره‌سازی محلی (Storage Layout)
تمامی فایل‌ها با استفاده از `DuplixPaths.realHomeDirectoryURL` در مسیر استاندارد زیر ذخیره می‌شوند:

```
~/Library/Application Support/Duplix/Voicofski/
├── audio/
│   ├── <uuid-1>.wav          # فایل صوتی ذخیره‌شده هر درخواست
│   └── <uuid-2>.wav
├── history.json              # تاریخچه ویس‌های ساخته‌شده (متن، ترجمه، صدا، مدت زمان، مسیر فایل)
├── pending_queue.json        # صف درخواست‌های ذخیره‌شده هنگام اتمام سهمیه کلیدها
└── keys_metadata.json        # متادیتای کلیدها (بدون خود Secret که در Keychain است)
```

### ۷.۲ ساختار ماژول‌ها در کدبیس Duplix (`Sources/`)

```
Sources/
├── DuplixCore/
│   └── Voicofski/
│       ├── Models/
│       │   ├── VoicofskiModels.swift        # VoiceOption, TargetLanguage, HistoryItem, PendingRequest, APIKeyMeta
│       │   └── VoicofskiSettings.swift      # تنظیمات کاربر (صدای منتخب، زبان مقصد، فعال‌سازی)
│       ├── Security/
│       │   └── KeychainStore.swift          # خواندن/نوشتن امن API Key در macOS Keychain
│       ├── Networking/
│       │   ├── GeminiAPIClient.swift        # ارتباط با Gemini Translate / TTS / Test Key
│       │   ├── APIKeyPoolManager.swift      # چرخش ترتیبی کلیدها، مدیریت 429 و ریست 09:00 UTC
│       │   └── PCMWavEncoder.swift          # تبدیل raw PCM 24kHz به فایل استاندارد WAV
│       └── Storage/
│           └── VoicofskiStorage.swift       # مدیریت پوشه audio/، history.json و pending_queue.json
│
└── DuplixApp/
    ├── Voicofski/
    │   ├── VoicofskiEngine.swift            # هماهنگ‌کننده اصلی (State، صف پخش، اتصال به AppDelegate)
    │   ├── SelectionMonitor.swift           # تشخیص سلکت موس، Accessibility + Clipboard Fallback
    │   ├── SelectionTriggerPanel.swift      # پاپ‌آپ شناور دو مرحله‌ای صرفاً آیکونی در گوشه متن
    │   ├── NotchPlayerPanel.swift           # پلیر شناور زیر ناچ (لودینگ غیرخطی، Seekbar، Visualizer، صف)
    │   └── VoicofskiAudioPlayer.swift       # پخش‌کننده مبتنی بر AVAudioPlayer با metering و seek
    ├── MenuBar/
    │   └── DuplixMenuBarController.swift    # کنترلر واحد Menu Bar برای Voice Memo و Voicofski
    └── Views/
        └── Voicofski/
            ├── VoicofskiView.swift          # صفحه اصلی تب Voicofski (Composer + History + Queue)
            ├── APIKeysSheet.swift           # مدیریت چند API Key + Test Key
            └── AIStudioGuideSheet.swift     # راهنمای کوتاه قدم‌به‌قدم ساخت کلید در Google AI Studio
```

### ۷.۳ مدل‌های کلیدی داده (Data Schemas)

| مدل | فیلدهای اصلی |
| :--- | :--- |
| **`APIKeyMetadata`** | `id: UUID`, `label: String`, `orderIndex: Int`, `status: active \| exhausted \| invalid \| untested`, `nextResetAt: Date?`, `lastError: String?`, `lastUsedAt: Date?` |
| **`VoicofskiHistoryItem`** | `id: UUID`, `createdAt: Date`, `mode: direct \| translate`, `originalText: String`, `translatedText: String?`, `targetLanguage: TargetLanguage?`, `voice: VoiceGender`, `audioFileName: String`, `durationSeconds: Double` |
| **`PendingQuotaRequest`** | `id: UUID`, `createdAt: Date`, `text: String`, `mode: direct \| translate`, `targetLanguage: TargetLanguage?`, `voice: VoiceGender` |
| **`PlaybackQueueItem`** | `id: UUID`, `historyItem: VoicofskiHistoryItem`, `audioURL: URL` |

---

## ۸. جدول Edge Caseها و نحوه برخورد سیستم

| سناریو / چالش | رفتار طراحی‌شده |
| :--- | :--- |
| سلکت کردن کمتر از ۳ کاراکتر (یا فقط فاصله/خط جدید) | نادیده گرفته می‌شود؛ دکمه شناور ظاهر نمی‌شود. |
| سلکت متن نزدیک لبه بالای صفحه | دکمه شناور به گوشه پایین ناحیه سلکت منتقل (Flip) می‌شود. |
| سلکت کردن متن صرفاً برای کپی و رها کردن | با Deselect بلافاصله و در غیر این صورت پس از ۱۰ ثانیه خودکار بسته می‌شود. |
| اپ مبدا Accessibility Text ندهد (مثل برخی PDF/Electron) | هنگام کلیک کاربر، Fallback غیرمخرب `Cmd+C` با حفظ و بازگردانی کلیپ‌بورد اجرا می‌شود. |
| متن بالای ۵۰۰ کلمه | نمایش هشدار قبل از مصرف API؛ تصمیم ادامه یا لغو با کاربر است. |
| کلید ۱ به محدودیت سهمیه (`429`) برسد | علامت‌گذاری `exhausted` تا `09:00 UTC` و سوییچ خودکار و آنی به کلید ۲. |
| تمام کلیدها به محدودیت سهمیه برسند | نمایش خطای شفاف + ذخیره متن در `Pending Queue` بدون محدود کردن سلکت کاربر. |
| درخواست جدید هنگام پخش صدای فعلی | صدای فعلی قطع نمی‌شود؛ ویس جدید در `Playback Queue` آماده شده و پس از بستن فعلی پخش می‌شود. |
| کار روی مانیتور دوم یا مک بدون ناچ | نمایش Notch HUD در بالا-وسط مانیتور فعالِ دارای نشانگر موس (زیر Menu Bar). |
| قطع بودن VPN یا خطای منطقه جغرافیایی | نمایش خطای کوتاه و شفاف درباره بررسی اتصال اینترنت/VPN (بدون کرش یا لودینگ بی‌پایان). |
| نبودن هیچ API Key ثبت‌شده | هدایت سریع کاربر به بخش تنظیم کلید + راهنمای Google AI Studio. |

---

## ۹. وضعیت تنظیمات پیش‌فرض مدل و صدا (Finalized Defaults)

تمامی پارامترهای مدل و صدا نهایی شدند:
- [x] **مدل TTS:** `gemini-3.8-flash-tts`
- [x] **صدای خانم (`Female`):** `Lora` (Clear and friendly · Medium pitch)
- [x] **صدای آقا (`Male`):** `Bodi` (Quiet and intimate · Low pitch)

---

## ۱۰. نقشه راه پیاده‌سازی (Implementation Phases)

| فاز | عنوان | شرح خروجی |
| :---: | :--- | :--- |
| **۱** | **Core, Keychain & Gemini API Engine** | پیاده‌سازی مدل‌ها، `KeychainStore`، `APIKeyPoolManager` (Sequential + 09:00 UTC Reset)، `GeminiAPIClient` (Test Key / Translate / TTS) و `PCMWavEncoder` همراه با تست واحد. |
| **۲** | **Selection Monitor & Two-Stage Floating Trigger** | پیاده‌سازی تشخیص سلکت موس (`>= 3 chars`)، Accessibility + Clipboard Fallback، دکمه شناور دو مرحله‌ای صرفاً آیکونی با مکان‌یابی هوشمند و تایمر ۱۰ ثانیه. |
| **۳** | **Notch HUD Player & Playback Queue** | پیاده‌سازی `NotchPlayerPanel` (زیر ناچ و مانیتور فعال)، انیمیشن لودینگ غیرخطی، `AVAudioPlayer` با Seekbar و Waveform Visualizer، و منطق صف پخش همزمان. |
| **۴** | **Duplix UI Tab, Composer, History & Unified Menu Bar** | افزودن تب `Voicofski` در سایدبار، Composer (Direct + Translate Review)، لیست History و Pending Queue، شیت مدیریت کلیدها و راهنمای AI Studio، و یکپارچه‌سازی Menu Bar. |
| **۵** | **QA & Multi-App Testing** | تست روی Safari، Chrome، Telegram، VS Code، PDFها، تست Failover چند کلید، تست مانیتور دوم/مک بدون ناچ و بررسی روان بودن انیمیشن‌ها. |
