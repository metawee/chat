# دليل التشغيل — Shawky WhatsApp

الدليل ده للي بيشغّل السيرفر. كل الأوامر بتتنفذ من فولدر:

```
cd /www/wwwroot/web.shawkygroup.com/chat/deployment/shawky/server
```

> ⚠️ السيرفر عليه مواقع تانية على aaPanel. متمسحش ولا توقف أي container أو volume غير بتوع الملف ده
> (`rails`, `sidekiq`, `postgres`, `redis`).
> ⚠️ متبعتش محتوى `.env` ولا أي باسورد أو توكن في شات أو واتساب.

---

## 1. التثبيت أول مرة

1. اسحب الكود:
   ```
   cd /www/wwwroot/web.shawkygroup.com
   git clone https://github.com/metawee/chat.git chat
   cd chat
   git checkout shawky/gateway-launch
   ```
2. جهّز ملف الإعدادات:
   ```
   cd deployment/shawky/server
   cp .env.example .env
   chmod 600 .env
   ```
   افتح `.env` وغيّر القيم دي:
   - `FRONTEND_URL=https://web.shawkygroup.com` و `RAILS_PORT=3010` (أي بورت فاضي على السيرفر).
   - `SECRET_KEY_BASE`: اعمله بالأمر `openssl rand -hex 64`.
   - `POSTGRES_PASSWORD` و `REDIS_PASSWORD`: اعمل كل واحد بالأمر `openssl rand -hex 24`. نفس باسورد Redis لازم يتكتب كمان جوه `REDIS_URL`.
   - بيانات SMTP عشان الإيميلات.
   - Cloudflare R2: `ACTIVE_STORAGE_SERVICE=s3_compatible` ومعاها بيانات الـ bucket.
   - `SHAWKY_N8N_SECRET`: سر مشترك مع n8n، اعمله بالأمر `openssl rand -hex 32`.
   - `SHAWKY_GATEWAY_URL=https://system.shawkygroup.com` ومعاه `SHAWKY_GATEWAY_API_KEY`. المفتاح ده بتاخده من مسؤول الـ gateway.
3. ابني وشغّل:
   ```
   docker compose build
   docker compose up -d postgres redis
   docker compose run --rm rails bundle exec rails db:chatwoot_prepare
   docker compose up -d
   docker compose exec rails bundle exec rails shawky:branding
   ```
4. في aaPanel: **Website ← Proxy Project**
   - الدومين: `web.shawkygroup.com`
   - الـ Target: `http://127.0.0.1:3010`
   - فعّل SSL (Let's Encrypt) و Force HTTPS.
   - في إعدادات Nginx بتاعة الموقع لازم يبقى فيه الـ headers دي، عشان الـ websocket والرسايل اللحظية:
     ```
     proxy_http_version 1.1;
     proxy_set_header Upgrade $http_upgrade;
     proxy_set_header Connection "upgrade";
     proxy_set_header Host $host;
     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
     proxy_set_header X-Forwarded-Proto https;
     client_max_body_size 50m;
     ```
5. افتح `https://web.shawkygroup.com` واعمل حساب الأدمن الأول.

---

## 2. التحديث لما ينزل كود جديد

```
cd /www/wwwroot/web.shawkygroup.com/chat
git pull
cd deployment/shawky/server
bash backup.sh
docker compose build
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose up -d
```

اعمل باك أب الأول دايمًا قبل أي تحديث.

---

## 3. ربط رقم واتساب الرسمي (WhatsApp Cloud API)

إحنا شغالين بالـ API الرسمي من Meta بس. ممنوع Evolution API و Baileys و WAHA وأي حاجة بتعمل scan للـ QR.

1. من Meta Business Manager:
   - اعمل **System User** ليه صلاحية على الـ WhatsApp Business Account (WABA).
   - طلّع له **Permanent Token** بالصلاحيات `whatsapp_business_messaging` و `whatsapp_business_management`.
   - اكتب عندك: **Phone Number ID** و **WhatsApp Business Account ID**.
2. في البرنامج: **Settings ← Inboxes ← Add Inbox ← WhatsApp ← WhatsApp Cloud**.
   - حط الرقم والـ Phone Number ID والـ Business Account ID والتوكن.
3. البرنامج هيديك **Webhook URL** و **Verify Token**. حطهم في Meta App ← WhatsApp ← Configuration، واشترك في `messages`.
4. ابعت رسالة تجربة من موبايل للرقم واتأكد إنها وصلت.

### الرقم الاحتياطي
- اربط الرقم الاحتياطي بنفس الطريقة كـ Inbox تاني.
- من **Settings ← Shawky settings**، اختار الرقم الأساسي والرقم الاحتياطي.
- لو Meta وقفت الرقم الأساسي (BANNED / DISCONNECTED أو أخطاء 131031 / 368)، البرنامج بيحوّل على الاحتياطي لوحده، وده بيتسجل في الـ audit.
- لما الرقم الأساسي يرجع، دوس **رجوع للرقم الأساسي** من نفس الصفحة.

---

## 4. المستخدمين والفرق والمشرفين

1. **Settings ← Agents**: ضيف الموظفين. الموظف العادي يبقى Agent، والمدير يبقى Administrator.
2. **Settings ← Teams**: اعمل فريق لكل مجموعة مبيعات، وضيف فيه الموظفين.
3. **Settings ← Inboxes ← (الرقم) ← Collaborators**: ضيف الموظفين على الرقم.
4. **Settings ← Shawky settings ← المشرفين**: اختار المشرف لكل فريق. المشرف بيشوف محادثات فريقه وتقييمهم الأسبوعي.
5. **Settings ← Shawky settings ← مستخدمي الـ CRM**: اربط اسم المستخدم في الـ CRM (زي `rawda`) بالموظف هنا. لو الربط مش موجود، زرار الواتساب في الـ CRM هيطلع رسالة إن الموظف مش مربوط.

### مفاتيح التشغيل (Settings ← Shawky settings)
| المفتاح | الحالة دلوقتي | معناه |
|---|---|---|
| إخفاء رقم العميل | **مقفول** | متشغلوش غير لما الـ CRM يبعت كود مؤقت بدل الرقم |
| الموظف يشوف محادثاته بس | مفتوح | المحادثات اللي مش متعينة بتظهر للمشرف والأدمن بس |
| فتح المحادثة من الـ CRM | مفتوح | زرار الواتساب في الـ CRM بيفتح `/shawky/launch?session=` |

أي تغيير في المفاتيح دي بيتسجل مين عمله وإمتى.

---

## 5. n8n

- التفاصيل الكاملة في `docs/shawky/N8N.md`.
- مستخدم النظام بتاع n8n بيتعمل مرة واحدة بالأمر ده:
  ```
  docker compose exec rails bundle exec rails "shawky:n8n_user[1,n8n@shawkygroup.com]"
  ```
  التوكن اللي بيطلع حطه في n8n على طول كـ Credential، ومتبعتوش لحد.
- تقييمات الذكاء الاصطناعي وتنبيهات الإساءة بتوصل للفريق بس، ومفيش أي حاجة منها بتتبعت للعميل.

---

## 6. الباك أب والاسترجاع

### باك أب يومي
في aaPanel: **Cron ← Add** ← Type: Shell Script ← كل يوم الساعة 03:17:

```
bash /www/wwwroot/web.shawkygroup.com/chat/deployment/shawky/server/backup.sh
```

- النسخ بتتحفظ في `/www/backup/shawky`، وبيتمسح أي حاجة أقدم من 14 يوم.
- لو عايز تغيّر المدة، حط قبل الأمر: `KEEP_DAYS=30`.
- الأفضل كمان تنقل الفولدر ده لمكان برا السيرفر مرة في الأسبوع، زي R2 أو S3 أو جهاز تاني. ممكن تعمل ده بـ aaPanel ← Backup أو بـ `rclone`.
- الملفات والمرفقات محفوظة على Cloudflare R2، فمش داخلة في الباك أب ده.

### استرجاع
> ده بيمسح الداتا الحالية ويحط مكانها النسخة. اسأل الأول قبل ما تعمله.

```
CONFIRM=yes bash restore.sh /www/backup/shawky/db-20261101-0317.dump
```

جرّب الاسترجاع مرة كل شهر على سيرفر تجربة، عشان تتأكد إن النسخ سليمة.

---

## 7. المتابعة (Health)

في aaPanel: **Cron** ← كل 5 دقايق:

```
bash /www/wwwroot/web.shawkygroup.com/chat/deployment/shawky/server/healthcheck.sh
```

السكريبت بيتأكد من الحاجات دي:
- الـ containers الأربعة شغالين.
- `/health` بيرد.
- الديسك مش مليان أكتر من 85%.
- فيه باك أب اتعمل في آخر 26 ساعة.

لو حطيت `SHAWKY_ALERT_WEBHOOK_URL` في `.env` (webhook في n8n)، أي مشكلة بتتبعت هناك، و n8n يبلّغ الأدمن.

ممكن كمان تضيف `https://web.shawkygroup.com/health` في UptimeRobot أو أي خدمة شبهه.

### أوامر مفيدة
```
docker compose ps
docker compose logs --tail=200 rails
docker compose logs --tail=200 sidekiq
docker compose restart rails sidekiq
```

---

## 8. مشاكل معروفة

| المشكلة | الحل |
|---|---|
| `rails` حالته unhealthy وفي اللوج SSL | اتأكد إن `X-Forwarded-Proto https` موجود في Nginx |
| الرسايل مش بتظهر لحظيًا | headers الـ websocket ناقصة في Nginx (`Upgrade` و `Connection`) |
| زرار الـ CRM بيطلع «الرابط انتهى» | الـ session بتتستخدم مرة واحدة بس. ارجع للـ CRM ودوس تاني |
| زرار الـ CRM بيطلع «العميل ده مش متعيّن لك» | العميل متعيّن لموظف تاني في الـ CRM. المحاولة دي بتتسجل |
| «موظف المبيعات مش مربوط» | ضيف الربط في Shawky settings ← مستخدمي الـ CRM |
| الإيميلات مش بتوصل | راجع بيانات SMTP في `.env`، وبعدين `docker compose up -d` |
