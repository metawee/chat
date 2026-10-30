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
  "crm_agent_id": "U-77",         // CRM owner; null if the CRM has none
  "lead": { "lead_id": "L-104582", "status": "Fresh", "project": "طنطا", "channel": "شيفت نهار",
            "site_state": "محاره", "area_sqm": 120, "property_type": "شقه" }
}
```

How Chatwoot handles it:
- `lead.*` fields are stored as contact custom attributes. Other keys are ignored, and the phone number is never stored from this call.
- If `crm_agent_id` is mapped to an active member of the inbox, the conversation goes to that user. The mapping is set in Settings → Shawky settings → CRM users. This also takes the lead back from round robin, as long as no agent has replied yet.
- Otherwise the conversation goes to round robin.
- The response is `200 {"conversation_id": 42, "assignee_id": 7}`.
- Errors return `401` for a bad or old signature (±300s) and `422` for a missing `lead.lead_id` or a malformed body.

If n8n does not answer in time, round robin takes the conversation. A late answer still moves it to the CRM owner, provided no agent has replied yet.
