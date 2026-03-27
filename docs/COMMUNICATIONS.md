# Communications and Messaging Playbook

## Audience Overview
- **Contractors, Governing Institutions & Professional Associations**
  - Goal: Confirm compliance, onboarding steps, contract links.
  - Tone: Formal; authoritative.
  - CTA: Review contract & upload compliance docs.

- **Customers and Members**
  - Goal: Reassure service status and next steps.
  - Tone: Friendly; concise.
  - CTA: View account / Contact support.

- **STFX Hub System Administrator**
  - Goal: Operational status, remediation actions.
  - Tone: Technical; urgent.
  - CTA: Open admin console / Run diagnostics.

- **Software Developer**
  - Goal: Dev status, repo/CI actions, required fixes.
  - Tone: Technical; collaborative.
  - CTA: Pull branch / Run local checks.

- **SFSSA Owners**
  - Goal: Executive summary, impact, resolution.
  - Tone: Executive; confident.
  - CTA: Review final report / Approve release.

## Personalization Tokens
Use these tokens in templates and messages:
- **{name}**
- **{contract_id}**
- **{account_link}**
- **{upload_link}**
- **{admin_console_link}**
- **{report_link}**
- **{support_link}**

## Delivery Rules
- Contractors: send only to verified contractor accounts; include contract ID.
- Customers: send to active members only; throttle to avoid duplicates.
- Admins/Developers: immediate delivery with high priority and links to logs.
- Owners: single message with read receipt requested; include executive summary and approval CTA.

## Deployment Checklist
1. Create audience segments in user database.
2. Stage templates and banners with a small user subset.
3. Register WhatsApp templates with WhatsApp Business (pre-approval required).
4. Deploy browser banners/modals via feature flags per role.
5. Add the GitHub Action large-object check and LFS patterns (recommended).
6. Monitor delivery and route replies to support queue.

## WhatsApp Compliance Notes
- Templates must be pre-approved by WhatsApp Business.
- Use concise, non-promotional language for transactional messages.
- Provide an opt-out mechanism (e.g., reply STOP).
- Keep templates localized and include required placeholders.

### Demo User
**Purpose**: Let prospective users explore TFX Hub features in a sandbox environment without affecting production data.
**Tone**: Friendly; exploratory.
**CTA**: Try demo / Give feedback.
**Banner**: **Try the TFX Hub demo** — Explore interactive features in a sandbox. [Start demo](/demo)
**WhatsApp**: `TFX Hub Demo: Hi {name}, try our interactive demo at {demo_link}. Share feedback to help us improve.`

## Minimal Governance
- Keep a changelog for communications templates in docs/COMMUNICATIONS_CHANGELOG.md.
- Only authorized users may update WhatsApp templates and .gitattributes.

## Integration Snippets

### Banner injection (include web/snippets/banner-inject.js in your layout)
### WhatsApp API payload example (use docs/WHATSAPP_TEMPLATES.json to populate placeholders)
```json
{
  "to": "+27123456789",
  "type": "template",
  "template": {
    "name": "tfx_compliance_reminder",
    "language": { "code": "en_US" },
    "components": [
      { "type": "body", "parameters": [{ "type": "text", "text": "{name}" }, { "type": "text", "text": "{contract_id}" }, { "type": "text", "text": "{upload_link}" }] }
    ]
  }
}
```
