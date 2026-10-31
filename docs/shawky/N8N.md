# n8n ↔ Chatwoot contract (Shawky)

## 1. Chatwoot → n8n (events)
Create an **account webhook** in Chatwoot (Settings → Integrations → Webhooks). It needs:
- the URL `https://n8n.cws.social/webhook/...`
- a **secret**
- the events `message_created`, `conversation_created`, `conversation_status_changed` and `conversation_updated`

Then set `SHAWKY_UNMASKED_WEBHOOK_HOSTS=n8n.cws.social`. Only signed webhooks to that host get full phone numbers.

Each request carries the following headers. Verify the signature in n8n before using the payload.
- `X-Chatwoot-Timestamp`
- `X-Chatwoot-Signature: sha256=HMAC_SHA256(secret, "<timestamp>.<raw body>")`

## 2. New WhatsApp number → CRM lead
When a number Chatwoot has never seen writes in, Chatwoot sends the welcome message. It then waits
`crm_owner_wait_seconds` (60 by default) for n8n. Meanwhile the conversation stays unassigned, and supervisors can see it.

What n8n does on `message_created` (incoming) when `conversation.custom_attributes.shawky_routing == "awaiting_crm_owner"`:
1. Look up `meta.sender.phone_number` in the CRM, and create the lead if it does not exist.
2. Call Chatwoot:

```
POST https://web.shawkygroup.com/shawky/hooks/n8n/crm_owner
Content-Type: application/json
X-Shawky-Timestamp: <unix seconds>
X-Shawky-Signature: sha256=<hex HMAC_SHA256(SHAWKY_N8N_SECRET, timestamp + "." + raw_body)>

{
  "account_id": 1,
  "conversation_id": 42,          // display id from the webhook payload (conversation.id)
  "lead": { "lead_id": "L-104582", "salesman": "rawda", "name": "زياد", "status": "Fresh",
            "project": "طنطا", "channel": "شيفت نهار", "site_state": "محاره", "area": "120",
            "created_at": "10/31/26, 5:21 PM", "cs_agent": "", "extra": { "any_crm_field": "value" } }
}
```

How Chatwoot handles it:
- The lead has the same shape the Shawky gateway uses. Its fields are stored as contact custom attributes (`crm_lead_id`, `crm_name`, `salesman`, `project`, `status`, `channel`, `crm_created_at`, `site_state`, `area`, `cs_agent`, `crm_extra`). An empty value never replaces a filled one, and the phone number is never stored from this call.
- If `lead.salesman` (the CRM username) is mapped to an active member of the inbox, the conversation goes to that user. The mapping is set in Settings → Shawky settings → CRM users. This also takes the lead back from round robin, as long as no agent has replied yet.
- Otherwise the conversation goes to round robin.
- The response is `200 {"conversation_id": 42, "assignee_id": 7}`.
- Errors return `401` for a bad or old signature (±300s) and `422` for a missing `lead.lead_id` or a malformed body.

If n8n does not answer in time, round robin takes the conversation. A late answer still moves it to the CRM owner, provided no agent has replied yet.

## 3. Assignment changes
There is no separate event. `conversation_updated` fires on every assignment, transfer or team change, and
`changed_attributes` holds `assignee_id` (`[previous, current]`) or `team_id`. Filter on that key in n8n.

The AI hooks below also update `custom_attributes`, which fires `conversation_updated` too. Ignore changes that only
touch `ai_*` keys, or n8n reviews its own writes in a loop.

## 4. Reading conversations from n8n (system user)
Create a dedicated administrator once on the server:

```
docker compose exec rails bundle exec rails "shawky:n8n_user[1,n8n@shawkygroup.com]"
```

It prints an API token. Store it in n8n as a credential and send it as the `api_access_token` header. Never paste
it in chat. For the last 24 hours of a conversation:
`GET /api/v1/accounts/1/conversations/<id>/messages`. For the list:
`POST /api/v1/accounts/1/conversations/filter` with `last_activity_at` "days_before" filters.

While phone masking is on, this user sees masked numbers like any other administrator. Use the signed webhook payloads
when you need the full number.

## 5. AI review (score, summary, flags)
These calls use the same signing as section 2. AI output is stored for the team only and is never sent to the customer.

```
POST /shawky/hooks/n8n/ai_review
{ "account_id": 1, "conversation_id": 42, "ai_score": 82, "ai_summary": "رد سريع ومهذب", "ai_flags": ["no_follow_up"] }
```

- `ai_score` must be an integer from 0 to 100; anything else returns `422`.
- `ai_flags` is optional and must be a list of strings.
- The values are stored as conversation custom attributes (`ai_score`, `ai_summary`, `ai_flags`, `ai_reviewed_at`). A private
  note with the score is also added. Define these as conversation custom attributes in Settings so they show in the sidebar.
- The weekly **Agent scores** page (sidebar, supervisors and administrators only) averages `ai_score` per assignee over
  the last 7 days.

## 6. Abuse alert

```
POST /shawky/hooks/n8n/abuse_alert
{ "account_id": 1, "conversation_id": 42, "reason": "العميل اشتكى من ألفاظ الموظف" }
```

This adds the `abuse_flag` label, which is created in red if it is missing. It also posts a private note that mentions
the conversation's supervisors and every administrator, so they are notified right away by web, push and email.
