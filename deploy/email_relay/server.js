"use strict";

/**
 * Small SMTP/API relay for the Flutter admin web app (browsers cannot speak SMTP).
 * Deploy beside the admin static site on Satlas, e.g. POST /api/send-email
 */
const express = require("express");
const nodemailer = require("nodemailer");

const PORT = Number(process.env.PORT || 8787);
const ALLOWED_ORIGINS = new Set([
  "https://neetappadmin.satlas.org",
  "http://127.0.0.1:8081",
  "http://localhost:8081",
]);

const app = express();
app.use(express.json({ limit: "512kb" }));

app.use((req, res, next) => {
  const origin = req.headers.origin || "";
  if (ALLOWED_ORIGINS.has(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
  }
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});

function text(value, fallback = "") {
  if (value === null || value === undefined) return fallback;
  return String(value).trim() || fallback;
}

function formatFrom(senderName, fromEmail) {
  const name = text(senderName, "TestprepKart");
  const email = text(fromEmail);
  if (!email) throw new Error("fromEmail is required");
  return `"${name.replace(/"/g, "")}" <${email}>`;
}

async function sendSmtp(settings, message) {
  const smtp = settings.smtp || {};
  const host = text(smtp.host);
  if (!host) throw new Error("SMTP host is not configured");
  const port = Number(smtp.port || 587);
  const transport = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    requireTLS: smtp.useSsl !== false && port !== 465,
    auth:
      text(smtp.username) && text(smtp.password)
        ? { user: text(smtp.username), pass: text(smtp.password) }
        : undefined,
  });
  await transport.sendMail({
    from: formatFrom(settings.senderName, settings.fromEmail),
    replyTo: text(settings.replyToEmail) || undefined,
    to: message.to,
    subject: message.subject,
    html: message.html,
  });
}

async function sendSendGrid(settings, message) {
  const api = settings.api || {};
  const apiKey = text(api.apiKey);
  if (!apiKey) throw new Error("SendGrid API key is not configured");
  const endpoint =
    text(api.endpoint) || "https://api.sendgrid.com/v3/mail/send";
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      personalizations: [{ to: [{ email: message.to }] }],
      from: {
        email: text(settings.fromEmail),
        name: text(settings.senderName, "TestprepKart"),
      },
      reply_to: text(settings.replyToEmail)
        ? { email: text(settings.replyToEmail) }
        : undefined,
      subject: message.subject,
      content: [{ type: "text/html", value: message.html }],
    }),
  });
  if (!response.ok) {
    throw new Error(`SendGrid failed: ${response.status} ${await response.text()}`);
  }
}

async function sendCustomApi(settings, message) {
  const api = settings.api || {};
  const endpoint = text(api.endpoint);
  if (!endpoint) throw new Error("Custom API endpoint is not configured");
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(text(api.apiKey) ? { Authorization: `Bearer ${text(api.apiKey)}` } : {}),
    },
    body: JSON.stringify({
      to: message.to,
      subject: message.subject,
      html: message.html,
      fromEmail: text(settings.fromEmail),
      senderName: text(settings.senderName),
      replyToEmail: text(settings.replyToEmail),
    }),
  });
  if (!response.ok) {
    throw new Error(`Custom API failed: ${response.status} ${await response.text()}`);
  }
}

app.post("/api/send-email", async (req, res) => {
  try {
    const body = req.body || {};
    const settings = body.settings || {};
    const to = text(body.to);
    const subject = text(body.subject);
    const html = text(body.html);
    if (!to || !subject || !html) {
      return res.status(400).json({ ok: false, error: "to, subject, html required" });
    }

    const provider = text(settings.provider, "SMTP");
    const message = { to, subject, html };

    if (provider === "SendGrid") {
      await sendSendGrid(settings, message);
    } else if (provider === "Custom API") {
      await sendCustomApi(settings, message);
    } else if (provider === "Firebase Extension") {
      return res.status(400).json({
        ok: false,
        error: "Firebase Extension provider is not supported by this relay. Use SMTP.",
      });
    } else {
      await sendSmtp(settings, message);
    }

    return res.json({ ok: true });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      error: error && error.message ? error.message : String(error),
    });
  }
});

app.get("/api/health", (_req, res) => res.json({ ok: true }));

app.listen(PORT, () => {
  console.log(`NEET admin email relay listening on :${PORT}`);
});
