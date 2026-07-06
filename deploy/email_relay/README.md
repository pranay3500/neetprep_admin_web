# Admin email relay

Browsers cannot connect to SMTP directly. The admin web app POSTs to `/api/send-email` with settings + message body.

## Recommended: PHP relay (shared hosting)

Files ship in **`web/email-api/`** and deploy with the Flutter build output.

- `health.php` → `GET /api/health` (returns `{"ok":true,"runtime":"php"}`)
- `send-email.php` → `POST /api/send-email`

`web/.htaccess` routes `/api/*` to these scripts **before** the Flutter SPA fallback.

After `flutter build web`, upload the full `build/web/` folder including:

- `email-api/`
- `.htaccess`

## Optional: Node relay

`server.js` on port 8787 + reverse proxy — use only if PHP is unavailable.

```bash
cd deploy/email_relay
npm install
PORT=8787 node server.js
```

## Admin settings

1. **Settings → Email Config** → enable master switch  
2. Fill Hostinger SMTP (or SendGrid)  
3. **Email Relay URL:** `https://neetappadmin.satlas.org/api/send-email`  
4. **Check relay** → should show “Relay online (php)”  
5. **Send test email**  
6. Keep admin signed in so Firestore listeners dispatch trigger emails
