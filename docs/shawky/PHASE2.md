# Phase 2: WhatsApp numbers, assignment, welcome message and the 24-hour window

## R1: Primary and backup numbers
- Admins pick the primary and backup WhatsApp inboxes in Settings → Shawky settings. Doing so turns off `assignment_v2`, because Shawky routing builds on the legacy round robin.
- **Automatic failover** to the backup number happens in either of these cases:
  - Every 5 minutes, `Shawky::ScheduledJobsJob` asks Meta's health API about the primary number. Statuses `BANNED`, `DISCONNECTED` and `DELETED` trigger failover.
  - Meta reports a failed message on the primary with code `131031` (account locked) or `368` (blocked for policy violations).

  Each failover is audited (`number_failover`), and administrators get an email.
- **Switching back** is manual: the "Switch back to the primary number" button, also audited.
- **One contact per customer** across both numbers, matched on phone number by upstream. The assigned agent can read the history from both inboxes (Phase 1 read-only history).
- **"Continue on the active number"** is a button in the conversation header after a failover. It opens a conversation with the same customer on the active number, for the same agent and team, and nobody types the number. The first message there must be a template, because each number has its own 24-hour window.

## R3: Assignment
New conversations on the Shawky numbers are routed like this:
1. **Returning customer:** goes to the agent of their latest conversation, if that agent is still in the account and in the inbox.
2. **Brand-new number** (no conversations, no `lead_id`): waits for n8n to report the CRM owner (see N8N.md), then falls back to round robin.
3. **Otherwise:** round robin over the inbox members who are online (upstream `AutoAssignment::AgentAssignmentService`).

The routing decision is stored in `conversation.custom_attributes.shawky_routing`.

## R6: Welcome message and the 24-hour window
- **Welcome message:** a free-form message on a brand-new customer's first message, sent once. Under Meta's pricing since 1 Oct 2026 it is billed as a service message, not a marketing template. An empty text turns it off.
- **Free-form replies outside the window** are refused with `422` and an Arabic error (web, mobile and API). Templates and private notes still go through. Upstream already disables the editor and shows the template picker in the dashboard.
- **Countdown:** conversations expose `shawky_window_closes_at`, and the header shows the time left (amber under 2 hours, red when closed).

## R7 (checked)
Every inbound and outbound message is stored in Postgres (`messages`) by upstream.

## New env vars
- `SHAWKY_ROUTING` (on by default)
- `SHAWKY_N8N_SECRET`
