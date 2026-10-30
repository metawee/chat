# Phase 1 — Phone masking and access control

## Summary
- **Masking (R2):** every customer number is masked server-side for everyone, administrators included (decision 4). Masking is value-based (`Shawky::PayloadMasker`), so fields we did not list are covered too. It applies at five exits:
  1. All `/api/**` responses (`Shawky::ApiPayloadMasking`, JSON and CSV).
  2. All ActionCable broadcasts (`ActionCableBroadcastJob`).
  3. All outgoing webhooks (`Webhooks::Trigger`).
  4. Liquid variables (`ContactDrop` and `ConversationDrop`).
  5. Contacts CSV export.
- **Masked values coming back:** a masked value sent back by a client is dropped from the params, so it never overwrites real data.
- **Revealing a number:** `GET /api/v1/accounts/:id/shawky/contacts/:contact_id/phone` is admin-only, and every call is written to `shawky_audit_logs`.
- **Access (roles):** all rules live in `Shawky::ConversationAccess`. Roles are agent, supervisor (`shawky_team_supervisors`) and administrator. History is read-only, and contacts are scoped to the conversations a user can work.
- **Lockdown:**
  - `/super_admin` and `/monitoring` are limited to an IP allowlist, and Sidekiq web can be turned off.
  - Integrations are limited to an allowlist.
  - Contact merge is admin-only.
  - Direct uploads need write access.
  - Phone parameters are filtered out of the logs.

## Feature flags (env)
All of them are on by default. See `.env.example` for:
- `SHAWKY_PHONE_MASKING`
- `SHAWKY_ACCESS_CONTROL`
- `SHAWKY_INTEGRATIONS_ALLOWLIST`
- `SHAWKY_ALLOWED_INTEGRATIONS`
- `SHAWKY_SUPER_ADMIN_ALLOWED_IPS`
- `SHAWKY_DISABLE_SIDEKIQ_WEB`
- `SHAWKY_UNMASKED_WEBHOOK_HOSTS`: signed account webhooks to these HTTPS hosts (n8n) receive full numbers. Unsigned automation and macro webhooks, agent bots and every other host stay masked.

The mask mode (`last3` or `hidden`) is an account setting, and admins change it from **Settings → Shawky settings**.

## Core files touched
Each core file got one `# SHAWKY:` / `// SHAWKY:` line (a `prepend`, `include`, import or route) pointing into the Shawky code.

- `app/controllers/api/base_controller.rb`
- `app/controllers/api/v1/accounts/actions/contact_merges_controller.rb`
- `app/controllers/api/v1/accounts/bulk_actions_controller.rb`
- `app/controllers/api/v1/accounts/contacts/base_controller.rb`
- `app/controllers/api/v1/accounts/contacts/contact_inboxes_controller.rb`
- `app/controllers/api/v1/accounts/contacts/conversations_controller.rb`
- `app/controllers/api/v1/accounts/contacts_controller.rb`
- `app/controllers/api/v1/accounts/conversations/assignments_controller.rb`
- `app/controllers/api/v1/accounts/conversations/base_controller.rb`
- `app/controllers/api/v1/accounts/conversations/direct_uploads_controller.rb`
- `app/controllers/api/v1/accounts/conversations_controller.rb`
- `app/drops/contact_drop.rb`
- `app/drops/conversation_drop.rb`
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue`
- `app/javascript/dashboard/i18n/locale/ar/index.js`
- `app/javascript/dashboard/i18n/locale/en/index.js`
- `app/javascript/dashboard/routes/dashboard/conversation/contact/ContactInfo.vue`
- `app/javascript/dashboard/routes/dashboard/settings/settings.routes.js`
- `app/jobs/account/contacts_export_job.rb`
- `app/jobs/action_cable_broadcast_job.rb`
- `app/listeners/action_cable_listener.rb`
- `app/models/integrations/app.rb`
- `app/models/integrations/hook.rb`
- `app/policies/contact_policy.rb`
- `app/policies/conversation_policy.rb`
- `app/services/contacts/filter_service.rb`
- `app/services/conversations/permission_filter_service.rb`
- `app/services/search_service.rb`
- `config/initializers/filter_parameter_logging.rb`
- `config/routes.rb`
- `lib/webhooks/trigger.rb`
- `db/schema.rb` (2 new tables), `.env.example` (Shawky section)
