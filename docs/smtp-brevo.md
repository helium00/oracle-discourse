# SMTP Configuration — Brevo

## Overview

Discourse requires outbound email for account registration, password resets,
notifications, and digest emails. This deployment uses **Brevo** (formerly
Sendinblue) as the SMTP relay.

Brevo offers a generous free tier and provides DKIM signing for your domain.

---

## Step 1 — Create a Brevo Account

1. Go to [https://app.brevo.com/account/register](https://app.brevo.com/account/register).
2. Sign up with your email address.
3. Verify your email address.
4. Complete the account setup form (company name, phone number).

---

## Step 2 — Generate SMTP Credentials

1. Log in to Brevo.
2. Navigate to: **Transactional** → **Email** → **SMTP & API**.
3. Click **Generate a new SMTP key**.
4. Copy the key — this is your `DISCOURSE_SMTP_PASSWORD` (an API key, not your Brevo account password).
5. Your `DISCOURSE_SMTP_USER_NAME` is your Brevo **account login email**.

Set these values in your `.env`:

```dotenv
DISCOURSE_SMTP_ADDRESS=smtp-relay.brevo.com
DISCOURSE_SMTP_PORT=587
DISCOURSE_SMTP_USER_NAME=your-brevo-login@example.com
DISCOURSE_SMTP_PASSWORD=xsmtpsib-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-XXXXXXXX
DISCOURSE_SMTP_ENABLE_START_TLS=true
```

---

## Step 3 — Add and Verify Your Sending Domain

Brevo requires you to authenticate the domain you send email from. This
improves deliverability and is required for DKIM signing.

1. In Brevo: **Senders & IPs** → **Domains** → **Add a domain**.
2. Enter your domain (e.g., `example.com`).
3. Brevo will display DNS records to add. Proceed to Steps 4 and 5.

---

## Step 4 — SPF Configuration

SPF authorizes Brevo's servers to send email on behalf of your domain.

Add or update the TXT record at the root of your domain (`@`):

| Type | Host | Value |
|---|---|---|
| `TXT` | `@` | `v=spf1 include:spf.brevo.com ~all` |

**If you already have an SPF record**, merge the include:
```
v=spf1 include:spf.brevo.com include:your-existing-provider ~all
```

Do not create more than one SPF TXT record on the same hostname.

DNS propagation: up to 48 hours. Verify with:
```bash
dig TXT example.com | grep spf
```

---

## Step 5 — DKIM Configuration

DKIM adds a cryptographic signature to outgoing emails so recipients can
verify authenticity. Brevo generates the key pair; you add a CNAME record.

After adding your domain in Brevo, you will see a record like:

| Type | Host | Value |
|---|---|---|
| `CNAME` | `mail._domainkey` | `mail._domainkey.brevo.com` |

The selector name (`mail`) may differ — use exactly what Brevo shows.

After adding the DNS record, click **Verify** in the Brevo dashboard.

Verify with:
```bash
dig CNAME mail._domainkey.example.com
```

---

## Step 6 — DMARC Recommendation

DMARC tells receiving mail servers what to do with emails that fail SPF or DKIM.

Start with a monitoring-only policy to collect reports without affecting delivery:

| Type | Host | Value |
|---|---|---|
| `TXT` | `_dmarc` | `v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com` |

Once you confirm all legitimate email passes SPF/DKIM, upgrade to quarantine:
```
v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@example.com
```

And eventually to reject:
```
v=DMARC1; p=reject; rua=mailto:dmarc-reports@example.com
```

---

## Step 7 — Test Email Delivery

### From the Discourse Admin Panel

1. Log in as admin.
2. Go to **Admin** → **Email** → **Settings**.
3. Click **Send Test Email** and enter a real email address.
4. Check whether the email arrives (also check the spam folder).
5. Check delivery status in Brevo: **Transactional** → **Email** → **Statistics**.

### Manual SMTP test with swaks

```bash
# Install swaks if not present: apt install swaks
swaks \
  --to test@example.com \
  --from noreply@example.com \
  --server smtp-relay.brevo.com:587 \
  --auth LOGIN \
  --auth-user "your-brevo-login@example.com" \
  --auth-password "your-smtp-api-key" \
  --tls \
  --body "Discourse SMTP relay test"
```

### Test port 587 reachability from the host

```bash
nc -vz smtp-relay.brevo.com 587
```

Expected: `Connection to smtp-relay.brevo.com 587 port [tcp/submission] succeeded!`

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| `535 Authentication failed` | Wrong credentials | Verify `DISCOURSE_SMTP_USER_NAME` is your Brevo login email and `DISCOURSE_SMTP_PASSWORD` is the SMTP API key (not your account password) |
| `Connection refused` or `Connection timed out` on port 587 | Firewall blocking outbound 587 | Allow outbound TCP 587: `sudo ufw allow out 587/tcp` |
| Emails delivered to spam | Missing or invalid DKIM/SPF | Complete Steps 4 and 5; allow 48 h for DNS propagation |
| `DISCOURSE_SMTP_PASSWORD` accepted but no email arrives | Brevo daily limit reached | Check Brevo → Transactional → Statistics for quota usage |
| TLS handshake errors in Discourse logs | `DISCOURSE_SMTP_ENABLE_START_TLS` not set | Confirm `DISCOURSE_SMTP_ENABLE_START_TLS=true` in `.env` and restart the stack |
