# neetprep_admin_web

A new Flutter project for NEET Prep Admin.

## Running the Admin App

To run the admin app with the specific Flutter SDK path and configuration, use the following commands in PowerShell:

```powershell
cd "e:\New_TPK_2026\Apps\neetprep_admin_web"

# Fetch dependencies
& "E:\New_TPK_2026\Apps\NEET_Flutter_App\SDK\flutter\bin\flutter.bat" pub get

# Run the app
& "E:\New_TPK_2026\Apps\NEET_Flutter_App\SDK\flutter\bin\flutter.bat" run `
  -d web-server `
  --web-hostname 127.0.0.1 `
  --web-port 8081
```

Alternatively, you can run the provided script:
`./run_admin.ps1`

## Deploy to live server (https://neetappadmin.satlas.org/)

Local code is **not** synced to the server automatically. Each release is: **build on PC → upload `build/web` → replace old files on host**.

### 1. Build (every time you change admin code)

```powershell
cd "e:\New_TPK_2026\Apps\neetprep_admin_web"
powershell -ExecutionPolicy Bypass -File .\deploy_admin.ps1
```

Or manually:

```powershell
flutter pub get
flutter build web --release
```

Output: **`build/web/`** — upload the **entire folder** to the server document root for `neetappadmin.satlas.org`.

### 2. Upload to Satlas (how you did the first deploy)

Use the **same method** you used to go live (typical options):

| Method | What you do |
|--------|-------------|
| **Hosting file manager / FTP** | Connect to Satlas → open site root → delete or backup old files → upload all files from `build/web/` |
| **SSH + SCP/rsync** | `scp -r build/web/* user@server:/path/to/site/root/` |
| **Git on server** | Commit `build/web` is usually **not** recommended; prefer build locally and upload artifacts |

We do not store Satlas credentials in this repo. Whoever manages the Satlas account performs the upload.

### 3. Verify

1. Open https://neetappadmin.satlas.org/
2. Hard refresh: **Ctrl+Shift+R** (cached `main.dart.js` is a common issue)
3. Sign in and check the page you changed

### Repeat workflow

```text
Edit Dart/JS in neetprep_admin_web → deploy_admin.ps1 → upload build/web → hard refresh live site
```

### Email (no Firebase Blaze)

1. Deploy `deploy/email_relay` on Satlas (see `deploy/email_relay/README.md`).
2. In admin **Settings → Email Config**, set **Email Relay URL** and SMTP (Hostinger).
3. Keep admin signed in — the app watches Firestore and sends mail.

Deploy Firestore rules from `neetprep_flutter` after pull: `firebase deploy --only firestore:rules`
