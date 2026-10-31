# Phase 4: Delay alerts, follow-ups, export, costs and purge

## R4: Response delay
- `Shawky::ResponseDelayScanJob` runs every 5 minutes through `Shawky::ScheduledJobsJob`. It looks at open, assigned conversations on the Shawky numbers whose `waiting_since` is older than **reply delay** (default 120 minutes; Settings → Shawky settings).
- For each one it posts a **private note mentioning the agent's supervisors**. If the agent has no supervisor, it mentions the administrators. Chatwoot's mention notifications then reach them in the app, by mobile push and by email.
- **One alert per waiting customer message:** `shawky_delay_alerts` is unique on (`conversation_id`, `waiting_since`). A new customer message after a reply starts a new wait.
- **Auto-reassign (optional, off by default):** moves the conversation to another online agent of the inbox through round robin. It is audited (`conversation_reassigned`, source `response_delay`), and Chatwoot adds its usual assignment activity.

## R5: Follow-up
- **Where:** a "Follow-up" page in the sidebar (`GET /api/v1/accounts/:id/shawky/follow_ups`).
- **What it lists:** open or pending conversations the user works on (agent: their own; supervisor: their team) where no agent has written for **N days** (default 3).

## R7: Storage and export
- **Storage:**
  - Every message and attachment is stored by upstream (Postgres plus ActiveStorage).
  - R2 uses upstream's `s3_compatible` service (see `.env.example`), and the bucket stays private.
- **Attachment links:** they expire after `SHAWKY_ATTACHMENT_URL_TTL_HOURS` (default 24), so a copied link to a photo or voice note stops working. The dashboard regenerates links on every load.
- **Admin export:** Settings → "Exports & costs".
  - It covers JSON (one object per conversation, with its messages) or CSV (one row per message) for a date range of up to a year.
  - Numbers are masked unless "include full phone numbers" is ticked. Every export is audited.
  - The file is generated in the background, and the download link expires like any attachment link.

## Cost report
- Meta's pricing in WhatsApp status webhooks (`pricing.category`, `billable`, `type`) is stored per outgoing message in `shawky_message_costs`, together with the recipient's country. Upstream ignores it.
- The report shows message counts per number and per agent by category (service, utility, marketing, authentication).
- The estimated cost uses rates the administrator enters from Meta's rate card, by country with a default. The first 1,000 service messages per number per month count as free.
- Meta's invoice is the source of truth; this is an estimate.

## Account purge (end of contract)
```bash
CONFIRM="<exact account name>" bundle exec rails "shawky:purge_account[<ACCOUNT_ID>]"
```
- It deletes Shawky records and export files, then calls upstream's `AccountDeletionService`.
- **Users who belong to no other account** are soft-deleted (their email is replaced).
- **Everything else is destroyed by `DeleteObjectJob`:** the account, contacts, conversations, messages and attachment files.
- **Without the exact name it refuses.** The counts are printed and logged; the account's audit log is deleted with it.
