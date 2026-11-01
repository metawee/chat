# برنامج Shawky WhatsApp للويندوز

برنامج صغير (Tauri + WebView2، حوالي 5–10MB) بيفتح `https://web.shawkygroup.com` في شباك لوحده، وبيسجّل الرابط `shawkywhatsapp://` على الجهاز.

## بيعمل إيه
- زرار الواتساب في الـ CRM بيفتح رابط زي ده: `shawkywhatsapp://launch?session=s_...`. البرنامج بياخد الرابط ويفتح
  `https://web.shawkygroup.com/shawky/launch?session=s_...`، وبعدها المحادثة بتفتح على طول.
- لو البرنامج مفتوح أصلًا، الرابط بيفتح في نفس الشباك ومبيفتحش نسخة تانية.
- تسجيل الدخول بيفضل محفوظ حتى لو قفلت البرنامج وفتحته.
- لما تقفل الشباك البرنامج مبيقفلش، بيستخبى جنب الساعة عشان إشعارات الرسايل الجديدة تفضل توصلك. للخروج: كليك يمين على الأيقونة ← خروج.
- أي لينك برا الموقع بيفتح في المتصفح العادي.
- الموقع شغال جوه البرنامج زي المتصفح بالظبط، ومالوش أي صلاحية على الجهاز غير اللي المتصفح بيديها.

## التنزيل
- من GitHub ← Actions ← **Shawky Windows app** ← آخر run ← Artifacts ← `Shawky-WhatsApp-Setup`.
- شغّل `Shawky WhatsApp_x.y.z_x64-setup.exe` على جهاز الموظف. مش محتاج صلاحيات أدمن.
- البرنامج بيستخدم WebView2 الموجود في Windows 10/11. لو مش موجود، ملف التثبيت بينزّله لوحده.
- الملف مش متوقّع رقميًا، فممكن Windows SmartScreen يطلع تحذير. دوس **More info ← Run anyway**.
  لو عايزين التحذير يختفي، لازم نشتري شهادة Code Signing.

## تجربة الرابط
بعد التثبيت، افتح Run (Win+R) واكتب:

```
shawkywhatsapp://launch?session=s_test12345
```

المفروض البرنامج يفتح ويطلع «الرابط انتهى». ده معناه إن الربط شغال، لأن الـ session دي مش حقيقية.

## للمطوّرين
محتاج Node 22 و Rust و WebView2 (ويندوز).

```
cd desktop/shawky-windows
npm ci
npm run dev                          # تشغيل محلي
cd src-tauri && cargo test           # اختبارات الروابط
cd .. && npm run dist                # ملف التثبيت في src-tauri/target/release/bundle/nsis/
```

لو عايز تبني نسخة لسيرفر تاني: `SHAWKY_APP_URL=https://staging.example.com npm run dist`.
