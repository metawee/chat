# Shawky WhatsApp — خطة التنفيذ (مسودة للموافقة)

## 0. النسخة والبيئة

- **Chatwoot v4.19.1** (آخر release مستقر، tag `v4.19.1`، commit `caab07a`، بتاريخ 2026-10-24).
- فرع الأساس: `shawky/main` من الـ tag ده. كل phase ليها فرع: `shawky/phase-1-masking-roles` وهكذا، وبتتعمل PR على `shawky/main`.
- **Community Edition فقط:** هنشغّل كل البيئات (dev/test/production) بـ `DISABLE_ENTERPRISE=true`. ده المفتاح الرسمي في `lib/chatwoot_app.rb`، وبيمنع تحميل أي كود من `enterprise/` (لا `prepend_mod_with` ولا routes). مش هنلمس `enterprise/`، وفي الـ production image هنشيله خالص.
- ملاحظة: آلية `custom/` اللي جاية مع upstream **مش هنستخدمها**، لأن وجود فولدر `custom/` بيرجّع تحميل `enterprise` تاني (`ChatwootApp.extensions`).

## 1. اللي موجود فعلاً في الكود مقابل المطلوب

| المتطلب | الموجود في v4.19.1 | المطلوب نبنيه |
|---|---|---|
| **الأدوار** | `account_users.role` = `agent` / `administrator` بس. الـ custom roles في enterprise. | دور Supervisor (§2) |
| **رؤية المحادثات** | `Conversations::PermissionFilterService` و `ConversationPolicy#show?`: الـ agent **بيشوف كل محادثات الـ inboxes اللي هو عضو فيها**، مش اللي متعيّنة له بس. | تقييد الرؤية: الـ agent يشوف المحادثات المتعيّنة له، والـ supervisor يشوف محادثات فريقه. |
| **الـ Contacts** | `ContactPolicy`: أي agent يقدر يعمل index/search/filter/show/update على **كل contacts الأكونت**. الـ export مقصور على الأدمن. | تقييد الـ contacts على اللي ليهم محادثات الـ user يقدر يشوفها، ومنع البحث/الفلترة/الترتيب بالرقم، ومنع تعديل الرقم. |
| **Serializers** | `api/v1/models/_contact.json.jbuilder` و `_contact_inbox` (`source_id` = رقم الواتساب) و `search/_contact` و `contacts/create` و `contactable_inboxes` و `Contact#push_event_data` و `Message#push_event_data` (فيه `conversation.contact_inbox.source_id` و `sender`) و `Conversations::EventDataPresenter` (`meta.sender`). | Masking من السيرفر في كل نقطة من دول. |
| **ActionCable** | `ActionCableListener#broadcast`: **نفس الـ payload** بيروح لكل أعضاء الـ inbox والأدمنز. أحداث `contact.*` بتروح على stream اسمه `account_<id>`، وده **كل users الأكونت مشتركين فيه**. | تقسيم الإرسال: الأدمن ياخد payload كامل، وغيره ياخد payload مـ masked. وكمان تقييد مين يستقبل (assignee + supervisors). |
| **البحث** | `SearchService` و `ContactsController#search` بيبحثوا بـ `phone_number ILIKE`. | البحث بالرقم للأدمن بس. الـ agent يبحث بالاسم و `lead_id`. |
| **أسماء جهات الاتصال** | الـ WhatsApp contact من غير profile name **اسمه بيبقى رقم التليفون** (`incoming_message_base_service.rb:197`). | الاسم اللي شكله رقم يتعمله mask هو كمان. |
| **Liquid** | `Liquidable` + `ContactDrop#phone_number`: الـ agent لو كتب `{{contact.phone_number}}` في رسالة أو canned response، **السيرفر بيحط الرقم الحقيقي** ويبعته ويخزّنه. | ده **ثغرة تسريب**. لازم يرجّع قيمة مـ masked لغير الأدمن. |
| **Round robin** | `AutoAssignment::AgentAssignmentService` + `InboxRoundRobinService` بيوزّعوا على أعضاء الـ inbox الـ **online** بس. فيه كمان `assignment_v2` (assignment policies) في CE. | نتأكد منها ونضبط الإعداد، ونضيف رجوع العميل لنفس الـ agent (R3). |
| **نافذة 24 ساعة** | `Conversations::MessageWindowService`: الواتساب = 24 ساعة، و `can_reply` بيوصل الـ frontend. الـ ReplyBox بيجبر على template لما `can_reply=false`. | عدّاد الوقت المتبقي في الهيدر، وتأكيد المنع من السيرفر كمان، و welcome template تلقائي (R6). |
| **Templates** | `Channel::Whatsapp#message_templates` + sync + `send_template`. | إعداد اسم الـ welcome template. |
| **Webhooks** | `Webhook` بيدعم `message_created` و `conversation_status_changed` و `conversation_updated`، وموقّع بـ HMAC (`X-Chatwoot-Signature: sha256=HMAC(secret, ts.body)`). | مفيش event اسمه `conversation_assignee_changed`، فهنضيفه (R8). |
| **Rate limiting** | `rack_attack.rb` موجود وفيه 39 throttle. | throttles للـ endpoints الجديدة. |
| **Audit log** | الـ audit logs في enterprise (`audited` gem متركّب بس الـ UI والمنطق EE). | جدول `shawky_audit_logs` خاص بينا. |
| **التخزين** | ActiveStorage + S3 عن طريق env. | لينكات الـ blob في Rails **مالهاش انتهاء صلاحية افتراضياً**، فلازم نضبط ده. |
| **Custom attributes و Custom filters** | موجودين في CE. | نستخدمهم في R5 و R8. |

## 2. تصميم الـ Phase 1 (الجزء الأمني الأساسي)

### الأدوار
- جدول جديد اسمه `shawky_team_supervisors (account_id, team_id, user_id)` بدل ما نعدّل الـ enum بتاع `account_users.role`. ده بيخلّي الكود قابل للـ merge مع upstream ومش متعارض مع custom roles. الـ supervisor في Chatwoot هيفضل `agent`، ومعاه سجل supervisor على فريق أو أكتر.
- مصدر واحد للصلاحيات: `Shawky::ConversationAccess.scope(user, account)`، وبيرجّع relation:
  - **admin**: كل المحادثات.
  - **supervisor**: محادثات الفريق (التفاصيل في سؤال 2).
  - **agent**: `assignee_id = user.id`.
- الـ scope ده بيتطبّق في: `PermissionFilterService` (اللي بيغذّي الـ list والـ filters والـ counts)، و `ConversationPolicy#show?`، و `SearchService`، و contacts scope، و الـ ActionCable recipients، و الـ notifications، و الـ reports.

### الـ Masking
- `Shawky::PhoneMask`:
  - `mask("+966542921507")` → `•••••••••507`، أو مخفي بالكامل حسب الإعداد.
  - `viewer_can_see_phone?(account_user)` → admin بس.
- **الـ API:** helper في الـ jbuilder partials (`shawky_phone(...)`) يقرا `Current.account_user`. التعديل في كل partial سطر واحد معلّم بـ `# SHAWKY:`.
- **الـ payloads الداخلية:** `Shawky::PayloadMasker.call(hash)` بيعمل mask بشكل deep للمفاتيح المعروفة: `phone_number`، `identifier`، `source_id` جوه `contact_inbox`/`contact_inboxes`، `wa_id`، `name` لو شكله رقم، ومفاتيح `additional_attributes` اللي فيها أرقام. **مش هيلمس `content` بتاع الرسالة.**
- **ActionCable:** patch واحد في `ActionCableListener#broadcast`: الأدمنز ياخدوا الـ payload كامل، وغيرهم ياخدوا نسخة masked، والمستلمين بيتفلتروا بالـ access scope. أحداث `contact.*` تتشال من الـ stream العام وتروح للأدمنز + اللي ليهم access.
- **Liquid:** `ContactDrop#phone_number` يرجّع masked لما المرسل مش أدمن.
- **Logs:** نضيف `phone_number`، `identifier`، `source_id`، `wa_id`، `mobile`، `whatsapp` لـ `filter_parameters`، ونراجع الـ log lines في خدمات الواتساب.
- **الإيميلات والـ push:** اسم الـ contact في الإشعارات بيعدّي على `PhoneMask`.
- **الـ specs:**
  - spec بتلف على **كل الـ routes** اللي بترجّع contact أو conversation وهي داخلة كـ agent، وتعمل assert إن الرقم الكامل (بكل صيغه: `+966…` و `966…` و `0…`) مش موجود في الـ body.
  - spec للـ ActionCable payload.
  - spec للـ Liquid.
  - spec للـ IDOR (agent يجرّب `display_id` بتاع محادثة غيره).
- **Feature flag:** إعداد `SHAWKY_PHONE_MASKING` في `installation_config`. **افتراضياً شغّال، والقفل محتاج أدمن.**

### الملفات (تقديري)
- **جديد:**
  - `app/models/shawky/team_supervisor.rb` و `app/models/shawky/audit_log.rb`
  - `app/services/shawky/{conversation_access,phone_mask,payload_masker}.rb`
  - `app/helpers/shawky/phone_helper.rb`
  - migrations `shawky_*`
  - `spec/shawky/**`
  - `app/javascript/dashboard/shawky/` (إعدادات الـ supervisor وإعداد الـ masking)
  - `ar.json` / `ar.yml` keys تحت namespace اسمه `SHAWKY`
- **Patches في core** (كل واحد سطر أو اتنين معلّم بـ `# SHAWKY:`):
  - `permission_filter_service.rb`
  - `conversation_policy.rb`
  - `contact_policy.rb`
  - `contacts_controller.rb` (search/filter/sort/update)
  - `search_service.rb`
  - `action_cable_listener.rb`
  - `contact_drop.rb`
  - jbuilder partials بتاعة contact/contact_inbox/search/conversation/message
  - `contact.rb` و `message.rb` و `conversations/event_data_presenter.rb` (push_event_data)
  - `config/initializers/filter_parameter_logging.rb`

## 3. Phases 2–6 (ملخص)

- **Phase 2:**
  - **R1:** نفس الـ Contact بيتربط بالـ inboxes الاتنين عن طريق الرقم بصيغة E.164، يعني contact واحد وليه اتنين `contact_inboxes`.
  - إعداد `shawky_active_outbound_inbox_id` يحدد الـ inbox اللي هيُستخدم لإطلاق الـ CRM وللـ outbound.
  - **R3:** `Shawky::ReturningCustomerAssigner` يشتغل قبل الـ round robin.
  - **R6:** welcome template على أول رسالة، و countdown في الهيدر، ومنع الرسالة الحرة بعد الـ 24 ساعة من السيرفر.
- **Phase 3:**
  - **R9:** `GET /chat` → `Shawky::CrmLaunchesController`. الكود يتحفظ في الـ session ويتعمل redirect فوراً لـ `/chat` من غير query. بعدها resolve موقّع، وربط `shawky_crm_user_mappings`، وفتح أو إنشاء المحادثة.
  - **ملاحظة مهمة:** الـ dashboard في Chatwoot بيعمل auth بـ devise_token_auth، والتوكنز محفوظة في cookie اسمها `cw_d_session_info`. هنتحقق من الـ user من السيرفر بالتوكنز دي.
  - `Shawky::CrmActivityJob` بـ `event_id` ثابت وإعادة محاولة بـ backoff.
  - Mock CRM كـ Rack app في `spec/support/shawky/mock_crm.rb`، وكمان يشتغل في dev.
- **Phase 4:**
  - **R4:** Sidekiq cron بيشغّل `Shawky::ResponseDelayScanJob`، ويستخدم `waiting_since` وجدول `shawky_delay_alerts (message_id unique)` علشان الـ idempotency.
  - **R5:** Follow-up list (endpoint + view).
  - **R7:** export JSON/CSV للأدمن بس، كـ job وإيميل بلينك.
- **Phase 5:**
  - event اسمه `conversation_assignee_changed`.
  - endpoint للـ n8n موقّع بـ HMAC لكتابة `ai_score` / `ai_summary` / `ai_flags` + private note + `abuse_flag`.
  - bot user مخصص.
  - صفحة weekly score.
- **Phase 6:** docker-compose production + Caddy + backups + health + الـ runbook بالعربي + الـ branding + اللغة العربية افتراضية.

## 4. أسئلة محتاج ردك عليها قبل ما أبدأ

1. **الـ agent:** هل يشوف **المحادثات المتعيّنة له بس**؟ ولا كمان المحادثات اللي اتعمله فيها mention أو participant؟ والمحادثات الـ unassigned، مين يشوفها؟ (اقتراحي: الـ supervisor والأدمن بس.)
2. **نطاق الـ supervisor:** أنهي واحد من دول؟
   - (أ) المحادثات المتعيّنة لأعضاء فريقه
   - (ب) المحادثات اللي `team_id` بتاعها فريقه
   - (ج) الاتنين
   
   وهل يشوف الـ unassigned في الـ inboxes بتاعة فريقه؟
3. **الـ supervisor والأرقام:** يشوف الرقم masked زي الـ agent؟ (المواصفات بتقول إن الأدمن بس هو اللي يشوف الرقم الكامل.)
4. **الأدمن والـ audit:** المواصفات بتطلب تسجيل "كل مرة الأدمن يشوف رقم كامل". لو الأدمن بيشوف الرقم دايماً، هيبقى عندنا log على كل request. **اقتراحي:** الأدمن كمان يشوف masked افتراضياً، وفيه زرار "إظهار الرقم" يسجّل في الـ audit. ولا تفضّل إن الأدمن يشوف الرقم دايماً ونسجّل بس الـ exports وصفحة الـ contact؟
5. **تاريخ العميل في الرقمين (R1):** لما العميل يبقى متعيّن لـ agent، هل الـ agent يشوف **كل** محادثات العميل القديمة (حتى اللي كانت مع agent تاني) read-only؟ ولا محادثاته هو بس؟
6. **صفحة الـ Contacts للـ agent:** نخفيها خالص، ولا تظهر بالـ contacts بتوعه بس؟ وهل مسموح للـ agent يبدأ محادثة جديدة بإنه يكتب رقم بإيده؟ (ده بيكشف إن الرقم موجود عندنا. اقتراحي: لأ، المحادثات الجديدة تتفتح من زرار الـ CRM بس.)
7. **تعديل بيانات الـ contact:** الـ agent يقدر يعدّل الاسم والـ custom attributes بس، والرقم والـ identifier للأدمن بس. موافق؟
8. **التحويل لزميل:** الإعداد الافتراضي مسموح ولا ممنوع؟ ولو مسموح، مسموح لأي agent في الفريق ولا لأي حد؟
9. **التخزين (R7، فيه تكلفة):** هنستخدم أنهي S3 provider؟ AWS S3، ولا Cloudflare R2، ولا MinIO على نفس السيرفر؟ وكام مدة الاحتفاظ بالميديا؟
10. **السيرفر (Phase 6، فيه تكلفة):** فيه سيرفر محدد أنشر عليه (مواصفات ومزوّد)؟ الحد الأدنى المقترح 4 vCPU و 8GB RAM.

أي حاجة في الخطة مش متوافقة مع شغلكم قولّي، وأنا هعدّلها قبل ما نبدأ Phase 1.
