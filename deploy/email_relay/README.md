# Admin email relay (no Firebase Blaze)

Browsers cannot connect to SMTP directly. This small Node server sends mail using the SMTP/API settings posted from the admin web app.

## Deploy on Satlas (same host as admin)

```bash
cd deploy/email_relay
npm install
PORT=8787 node server.js
```

Use PM2 or a reverse proxy so `https://neetappadmin.satlas.org/api/send-email` forwards to this process.

## Admin settings

In **Settings → Email Config**, set **Email Relay URL** to:

`https://neetappadmin.satlas.org/api/send-email`

Keep the admin web app open and signed in so Firestore listeners can send emails when new data arrives.
