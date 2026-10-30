# Phase 3: CRM "WhatsApp" button and activity webhook (R9)

## Launch flow
1. The CRM sends the browser to `GET /chat?code=<CODE>`. The code is single-use and valid for 60 seconds.
2. `Shawky::CrmLaunchesController` checks the code format, then **resolves it with the CRM right away**:
   - The call is `POST {SHAWKY_CRM_BASE_URL}/api/integrations/shawky/resolve`, signed with HMAC (`Shawky::Crm::Client`).
   - The response picks the account through the CRM user mapping (`agent.id`). The lead is stored in Redis for 5 minutes (`Shawky::CrmLaunchStore`).
   - The browser gets only a random token, in an encrypted httpOnly cookie.
   - The browser is redirected (303) to `/app/accounts/:id/shawky/crm-launch`, with no code and no lead data in the URL.
   - Response headers: `Referrer-Policy: no-referrer` and `Cache-Control: no-store`.
3. If the agent isn't logged in, the dashboard sends them to login. Afterwards it asks `GET /shawky/crm_launch` once and resumes the launch.
4. `POST /api/v1/accounts/:id/shawky/crm_launch` takes the parked lead (one time only) and runs `Shawky::CrmLaunch`:
   - **Who may open it:** only the lead's CRM owner (mapped user) or that user's team supervisor. Anyone else gets `403 not_allowed`.
   - **Contact:** found or created by the WhatsApp number in E.164 (local numbers default to Egypt). The lead fields are saved as contact custom attributes.
   - **Conversation:** the open conversation on the **active** number, or a new one. It is assigned to the CRM owner; if someone else had it, it is reassigned and audited.
   - **Audit:** `crm_launch` with the user, `lead_id` and CRM agent. Never the phone number.
   - **Opening it:** the dashboard opens the conversation. If the 24-hour window is closed, the template picker opens too (`?shawky_open_templates=1`).
5. Error pages are in Arabic:
   - expired or used code → 410
   - malformed code → 400
   - unmapped CRM user → 403
   - CRM down or rejected → 502
   - rate limited → 429 (CRM 429, or our own limit of 30/min per IP on `/chat`)

## Activity webhook
- **When:** `Shawky::CrmActivity` records one `reply` activity per conversation per 24 hours (the first agent reply), plus one `resolved` activity when the conversation is resolved. This only happens for contacts with a `lead_id` and agents with a CRM mapping.
- **Payload:** fixed when the activity is created, including `event_id = evt_<uuid>`, so every retry sends exactly the same event. Example:
  `{event_id, lead_id, agent_id, type: "whatsapp", direction: "outbound", status: "sent"|"resolved", started_at (Africa/Cairo ISO8601), duration_sec: null, summary: null, recording_url: null}`
- **Delivery:** `Shawky::CrmActivityJob` posts to `/api/integrations/shawky/activities` with the same signature.
  - Unreachable, 429 and 5xx responses are retried with growing delays, up to 10 attempts.
  - Any other error marks the activity `failed`.

**To confirm with the CRM company:**
- the `"resolved"` status value
- that `summary` stays null until the n8n summaries arrive in Phase 5

## Mock CRM
`Shawky::MockCrm` (lib/shawky/mock_crm.rb) speaks the same signed API. It is mounted at `/mock_crm` when `SHAWKY_MOCK_CRM=true`:
- `GET /mock_crm/leads/L-123?agent=U-77&mobile=%2B2010...` shows a lead page with a WhatsApp button (it issues a real 60-second code)
- `GET /mock_crm/activities` lists the activities received

Specs route the CRM calls to it through WebMock.

## Env
`SHAWKY_CRM_INTEGRATION`, `SHAWKY_CRM_BASE_URL` (https in production), `SHAWKY_CRM_KEY_ID`, `SHAWKY_CRM_SECRET`, `SHAWKY_MOCK_CRM`.
