# Phase 0 — تجربة Chatwoot من غير تعديل على staging

الهدف هنا إننا نتأكد إن رقم واتساب تجريبي بيبعت ويستقبل كويس على Chatwoot الأصلي (v4.19.1 Community Edition)، قبل ما نبدأ أي تطوير. لو فيه مشاكل في إعدادات Meta، نكتشفها من الأول.

## 1. السيرفر
- Ubuntu 24.04، وأقل مواصفات 2 vCPU و 4GB RAM و 40GB disk. ده كفاية للتجربة.
- Docker و Docker Compose v2 متسطّبين.
- DNS: سجل A لـ `staging-web.shawkygroup.com` (أو أي subdomain تختاره) يشاور على IP السيرفر.
- البورتات 80 و 443 مفتوحة. Caddy هيطلّع شهادة TLS لوحده.

## 2. التشغيل
```bash
git clone -b shawky/main https://github.com/metawee/chat.git && cd chat/deployment/shawky/staging
cp .env.example .env
# املا: STAGING_DOMAIN و FRONTEND_URL و SECRET_KEY_BASE و POSTGRES_PASSWORD و REDIS_PASSWORD و SMTP_*
docker compose pull
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose up -d
```
افتح `https://<STAGING_DOMAIN>`، واعمل أول حساب أدمن من صفحة الإعداد.

## 3. إعداد Meta (WhatsApp Cloud API الرسمي)
1. **Meta Business Manager** بتاع الشركة → **Business Settings**: اتأكد إن الشركة verified، أو على الأقل شغّالة.
2. **developers.facebook.com** → Create App → نوعها **Business** → ضيف منتج **WhatsApp**.
3. **WhatsApp → API Setup**: استخدم الرقم التجريبي اللي Meta بتدّيه، أو ضيف رقم تجريبي حقيقي.
   **ماتستخدمش `01212239999` في التجربة.**
   سجّل عندك:
   - **Phone Number ID**
   - **WhatsApp Business Account ID**
4. **System User Token** (توكن دايم):
   - Business Settings → Users → **System users** → Add (Admin).
   - Assign assets: الـ App والـ WhatsApp Account (Full control).
   - Generate token بالصلاحيات دي: `whatsapp_business_messaging` و `whatsapp_business_management`، ومدته **Never expire**.
5. **في Chatwoot**: Settings → Inboxes → Add Inbox → **WhatsApp** → **WhatsApp Cloud**، وبعدها:
   - املا الرقم بصيغة E.164.
   - حط الـ Phone Number ID والـ Business Account ID والـ System User Token.
   - احفظ، وبعدين افتح إعدادات الـ inbox وانسخ **Webhook URL** و **Verify Token**.
   - الـ Webhook URL شكله كده: `https://<STAGING_DOMAIN>/webhooks/whatsapp/+20XXXXXXXXXX`
6. **في Meta**: WhatsApp → Configuration → Webhook → Edit:
   - حط الـ Callback URL والـ Verify Token → Verify and save.
   - من **Webhook fields** اعمل Subscribe على `messages`.
7. **Templates**: اعمل template تجريبي واحد على الأقل، marketing أو utility، باللغة العربية، واستنى لحد ما يتوافق عليه. وبعدين في Chatwoot من إعدادات الـ inbox دوس **Sync Templates**.

## 4. اختبارات Phase 0 (سجّل نتيجة كل خطوة)

| # | الاختبار | المتوقع |
|---|---|---|
| 1 | ابعت "مرحبا" من موبايل شخصي للرقم التجريبي | المحادثة تظهر في Chatwoot في أقل من 5 ثواني |
| 2 | رد من Chatwoot برسالة نصية | توصل للموبايل، والحالة تتغير sent → delivered → read |
| 3 | ابعت صورة وvoice note وملف PDF من الموبايل | يظهروا في Chatwoot ويفتحوا عادي |
| 4 | ابعت صورة وملف من Chatwoot | يوصلوا للموبايل |
| 5 | ابعت template من Chatwoot لرقم مكلّمناش قبل كده | يوصل. ولو رجع error، سجّل الكود (مثلاً 131026 أو 132001) |
| 6 | استنى أكتر من 24 ساعة من آخر رسالة للعميل، وبعدين جرّب رسالة حرة | Chatwoot يجبرك تختار template |
| 7 | اعمل `docker compose restart` وبعدها ابعت رسالة | توصل عادي من غير ما يضيع حاجة |

## 5. مشاكل Meta الشائعة
- **Webhook verify failed**: الـ verify token غلط، أو شهادة TLS لسه ماطلعتش. افتح الدومين في المتصفح واتأكد إن القفل ظاهر.
- **الرسايل مش بتوصل Chatwoot**: نسيت تعمل subscribe على `messages`، أو الـ App لسه في وضع Development والرقم اللي بيبعت مش متضاف في قايمة الأرقام التجريبية.
- **Error 131030** (الرقم مش في القايمة): في وضع Development لازم تضيف أرقام المستلمين.
- **Error 190** (token expired): التوكن مؤقت. استخدم System User Token مدته Never expire.
- **الـ template مرفوض**: راجع سياسة Meta للتصنيف (marketing / utility).
