# برنامج Shawky WhatsApp للويندوز

برنامج صغير بيفتح `https://web.shawkygroup.com` في شباك لوحده، وبيسجّل الرابط `shawkywhatsapp://` على الجهاز.

## بيعمل إيه
- زرار الواتساب في الـ CRM بيفتح رابط زي ده: `shawkywhatsapp://launch?session=s_...`. البرنامج بياخد الرابط ويفتح
  `https://web.shawkygroup.com/shawky/launch?session=s_...`، وبعدها المحادثة بتفتح على طول.
- لو البرنامج مفتوح أصلًا، الرابط بيفتح في نفس الشباك ومبيفتحش نسخة تانية.
- تسجيل الدخول بيفضل محفوظ حتى لو قفلت البرنامج وفتحته.
- لما تقفل الشباك البرنامج مبيقفلش، بيستخبى جنب الساعة عشان إشعارات الرسايل الجديدة تفضل توصلك. للخروج: كليك يمين على الأيقونة ← خروج.
- أي لينك برا الموقع بيفتح في المتصفح العادي.
- الصلاحيات المسموحة بس: الإشعارات، والمايك عشان الرسايل الصوتية، والنسخ.

## التنزيل
- من GitHub ← Actions ← **Shawky Windows app** ← آخر run ← Artifacts ← `Shawky-WhatsApp-Setup`.
- شغّل `Shawky WhatsApp Setup x.y.z.exe` على جهاز الموظف.
- الملف مش متوقّع رقميًا، فممكن Windows SmartScreen يطلع تحذير. دوس **More info ← Run anyway**.
  لو عايزين التحذير يختفي، لازم نشتري شهادة Code Signing.

## تجربة الرابط
بعد التثبيت، افتح Run (Win+R) واكتب:

```
shawkywhatsapp://launch?session=s_test12345
```

المفروض البرنامج يفتح ويطلع «الرابط انتهى». ده معناه إن الربط شغال، لأن الـ session دي مش حقيقية.

## للمطوّرين
```
cd desktop/shawky-windows
npm ci
npm start              # تشغيل محلي
npm test               # اختبارات الروابط
npm run dist           # يبني ملف التثبيت على ويندوز في dist/
```

لو عايز تجرّب على سيرفر تاني: `SHAWKY_APP_URL=https://staging.example.com npm start`.
