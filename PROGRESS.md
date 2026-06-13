# NEET Prep Admin Web — Progress & Pitfalls

Tracks admin-only work so sessions do not re-debug the same issues. Pair with mobile app `neetprep_flutter/PROGRESS.md` for end-to-end Content Library flow.

## Content architecture (do not confuse APIs)

| Layer | Source | Used by |
|--------|--------|---------|
| **Tree (API 1)** | `GET …/self-study/api/tree/content/neet/neet-planning` | CL Import → Firestore `content_library_import_nodes`; mobile library index |
| **Body (CMS)** | Admin HTML editor → **Publish** | Firestore `content_library_published_nodes/{websiteNodeId}` — fields `contentSource`, `status: "published"` |
| **Body (fallback API 2)** | `GET …/self-study/api/content/{nodeId}` | Mobile + **CL Editor preload** when Firestore empty |
| **PDF URLs** | Admin CL Import hierarchy | Firestore `cms_content_library/main` → `nodePdfUrls` |
| **Lock / free** | Admin CL Import | `cms_content_library/main` gating lists |

Mobile read order for section HTML: **published Firestore** → cache → **API 2**.

---

## Update — 2026-06-12 (Content Library Editor rebuild + Unsubscribe table fix)

- **Current status:** CL Editor no longer uses CKEditor. **Visual edit** (default tab) + **Edit HTML** (paste/raw source). Publish flow unchanged (`contentSource` → Firestore).
- **CL Editor — what changed:**
  - [x] Removed CKEditor stack (`ckeditor/*`, `ckeditor_bridge.js`, `ckeditor_frame.html`, CDN in `index.html`) after repeated Flutter web pointer/scroll/destroy failures.
  - [x] **Visual edit** tab — iframe `web/content_library_visual_editor.html` with `contenteditable` body + toolbar (bold, italic, underline, H2/H3, lists, link, divider). Edits sync to `TextEditingController` via `postMessage`.
  - [x] **Edit HTML** tab — scrollable monospace `TextField` + snippet toolbar (best for paste / fine-tuning tags).
  - [x] `content_library_editor_page.dart` — helper copy updated.
- **Unsubscribe requests table (2026-06-12):**
  - [x] Fixed `RenderFlex` overflow on **Date** column (`unsubscribe_requests_page.dart`) — fixed 168px column width + `Expanded` + ellipsis on timestamp.
- **Files changed:**
  - `lib/src/widgets/content_library_html_editor.dart`
  - `lib/src/widgets/content_library_visual_editor_web.dart`
  - `lib/src/widgets/content_library_visual_editor_stub.dart`
  - `web/content_library_visual_editor.html`
  - `web/index.html`
  - `lib/src/pages/content_library_editor_page.dart`
  - `lib/src/pages/unsubscribe_requests_page.dart`
- **Deleted:** `lib/src/widgets/ckeditor/*`, `lib/src/widgets/content_library_html_preview_*.dart`, `web/ckeditor_bridge.js`, `web/ckeditor_frame.html`
- **Verify:** Hard refresh admin web (Ctrl+Shift+R) → CL Editor → Stage 1 → **Visual edit** (click, type, scroll, toolbar) → **Edit HTML** (paste) → Publish → mobile shows body. Unsubscribe page — no yellow/black stripe on Date column.
- **Production deploy (required after 2026-06-12 editor change):** Rebuild `powershell -File tool/build_admin_web.ps1` and upload **entire** `build/web/` to Satlas (includes `content_library_visual_editor.html`, `index.html`, `.htaccess`). After deploy: hard refresh; UI should show **Edit HTML** / **Visual edit** tabs (not CKEditor).
- **Stale cache (2026-06-13):** If production still shows CKEditor + `Null check operator` after upload, the server may have new files but the **browser service worker** is serving old `main.dart.js`. Fix: `index.html` now unregisters service workers on load; build uses `--pwa-strategy=none`; `.htaccess` sets no-cache on `.js`/`.html`. User one-time: Chrome DevTools → Application → Clear site data, or test in Incognito.
- **Historical:** CKEditor debugging notes kept below (superseded by this update).

---

## Update — 2026-06-08 (TPK app icon — browser tab + PWA)

- **Current status:** Admin web favicon and PWA icons regenerated from the same TPK gradient square as mobile `assets/icon/app_icon.png` (orange→pink, white **TPK**). In-app chrome still uses the horizontal wordmark (`assets/images/testprepkart_logo.png`).
- **Files changed:**
  - `web/favicon.png`
  - `web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png`
- **Completed functionality:**
  - Browser tab, bookmark, and “Add to Home Screen” show the TPK app icon after redeploy.
- **Pending cleanup:**
  - Rebuild + upload admin web (`build_admin_daily.bat` or `deploy_admin.ps1`) so production picks up new icons.

---

## Update — 2026-06-05 (Seat Allotment — v1 complete + Mobile Bundle tab)

- **Current status:** MBBS Seats **v1 feature-complete on mobile** (bundled SQLite + local agent; no Claude). Admin **Seat Allotment** has tabs **CSV Import** / **Datasets** / **Mobile Bundle**.
- **Mobile Bundle tab:** Live read of Firestore `cms_seat_allotment/main` — published flag, fingerprint, version, Storage paths, last write. Explains CSV datasets = admin QA only; mobile reads bundled/OTA SQLite.
- **Mobile polish:** Counseling Ask inline result previews → detail sheet (`seat_allotment_counseling_ask_screen.dart`).
- **Publish (optional OTA):** CLI only — see Mobile Bundle tab or `neetprep_flutter/PROGRESS.md` § Optional. Rules: `powershell -File tool/deploy_seat_allotment_rules.ps1`.
- **Files changed:**
  - `lib/src/pages/seat_allotment_page.dart` (Mobile Bundle tab)
  - `neetprep_flutter/lib/features/mbbs_seats/seat_allotment_counseling_ask_screen.dart`
  - `neetprep_flutter/tool/deploy_seat_allotment_rules.ps1`
- **Optional (not blocking v1):**
  - [ ] Deploy seat-allotment Firestore + Storage rules + first bundle publish (OTA)
  - [ ] Rebuild + upload admin web (`build_admin_daily.bat`) so Mobile Bundle tab is live
  - [ ] Claude / `counselingInsightSummarize` (deferred)

---

## Update — 2026-06-03 (Seat Allotment CMS + CSV import)

- **Current status:** Admin nav **Seat Allotment** with tabs **CSV Import** / **Datasets** / **Mobile Bundle**; CSV → Firestore for admin QA; mobile uses SQLite bundle/OTA (see Mobile Bundle tab).
- **Nav:** Left rail **Seat Allotment** (index 10); shifted Courses/Webinar/Settings/Unsubscribe/Users to 11–15.
- **Firestore:**
  - `seat_allotment_datasets/{datasetId}` — metadata, `isPublished`, `filterOptions`, `rowCount`
  - `seat_allotment_datasets/{datasetId}/rows/{rank_serialNo}` — allotment rows
- **Rules:** `neetprep_flutter/firestore.rules` — `seat_allotment_datasets` public read when `isPublished`; `cms_seat_allotment` public read; admin write via `isContentAdmin()`.
- **Files changed:**
  - `lib/src/pages/seat_allotment_page.dart`
  - `lib/src/seat_allotment/seat_allotment_csv.dart`
  - `lib/src/seat_allotment/seat_allotment_import_service.dart`
  - `lib/src/utils/csv_file_pick_web.dart`
  - `lib/src/admin_app.dart`
- **Historical note:** Mobile no longer reads `seat_allotment_datasets` rows — it uses bundled/OTA SQLite (see 2026-06-05 update).
- **22k+ rows:** Do not use browser import — use CLI `neetprep_flutter/tool/import_seat_allotment_csv.mjs` + service account JSON (see script header). Admin web is for small files / publish toggle only.
- **Fix (2026-06-03):** `permission-denied` on import — Firestore rules reordered (`isContentAdmin()` before `get(parent)`); import creates dataset doc before row deletes; rules deployed (`firebase deploy --only firestore:rules`).
- **Local admin run:** Double-click **`start admin app.bat`** or `powershell -File tool\run_admin_web.ps1` (opens **Chrome**). **`start admin app.bat` no longer uses `web-server`.** If terminal shows `Terminate batch job (Y/N)?`, you pressed Ctrl+C — press **Y**, restart. Optional manual URL mode: `start admin app (web-server).bat` then http://127.0.0.1:8081.

---

## Update — 2026-06-02 (Public account deletion URL + admin queue)

- **Current status:** Google Play–compliant public page and admin review queue implemented.
- **Public URL (user-facing, recommended):** upload `deploy/testprepkart_unsubscribe/index.html` → `https://www.testprepkart.com/unsubscribe/` (standalone HTML; not the admin Flutter build).
- **Public URL (admin host, optional):** `https://neetappadmin.satlas.org/unsubscribe` — requires `web/.htaccess` SPA rewrite in deployed `build/web/` so the URL does not redirect to `/`.
- **Admin menu:** **Unsubscribe** (nav index 13) — table of requests with status + unread badge.
- **Files changed:**
  - `lib/main.dart` (`usePathUrlStrategy` for `/unsubscribe` path)
  - `lib/src/admin_app.dart` (route gate, nav)
  - `lib/src/pages/unsubscribe_page.dart`
  - `lib/src/pages/unsubscribe_requests_page.dart`
  - `lib/src/services/account_deletion_request_service.dart`
  - `../neetprep_flutter/firestore.rules` (`account_deletion_requests` collection)
- **Pending cleanup:**
  - Deploy Firestore rules: `firebase deploy --only firestore:rules` from `neetprep_flutter` or admin `firebase.json` path.
  - Rebuild + upload admin `build/web/` via `deploy_admin.ps1`.
  - Ensure Satlas serves `index.html` for `/unsubscribe` (SPA fallback), not a static 404.
  - Play Console **Delete account URL:** `https://www.testprepkart.com/unsubscribe/`
  - Firebase **Authorized domains:** add `testprepkart.com` and `www.testprepkart.com`
  - Standalone upload package: `deploy/testprepkart_unsubscribe/`
  - Actual account deletion remains manual (Firebase Auth / App Users) when status = Completed.

---

## Local admin web dev (May 25, 2026)

- **Files:** `tool/flutter_sdk.path`, `tool/flutter_env.ps1`, `tool/run_admin_web.ps1`, `.cursor/rules/flutter-sdk-path.mdc`
- **Flutter SDK (machine):** `E:\New_TPK_2026\Apps\NEET_Flutter_App\SDK\flutter` — stored in `tool/flutter_sdk.path` (do not re-prompt).
- **Folder:** `neetprep_admin_web` (not `neetprep_flutter`).
- **Run:** `powershell -File tool/run_admin_web.ps1` (uses SDK from `tool/flutter_sdk.path`).
- **Release build:** `powershell -File tool/build_admin_web.ps1` → deploy `build/web/` (must run from `neetprep_admin_web`, not `C:\Users\prana`).
- **Avoid** `flutter run -d web-server` unless you manually open **http://127.0.0.1:8081** — it does not launch a browser; “Waiting for debug service” can sit for 45s+ while the server is already up.
- **Firebase Auth → Authorized domains:** add **`localhost` and `127.0.0.1`** (Chrome/`flutter run` often uses `http://127.0.0.1:PORT`, not `localhost`).
- **Sign-in not showing:** fixed May 25 — `AdminAuthGate` no longer blocks on auth-stream spinner; shows `SignInPage` immediately when signed out. If stuck on “Checking admin access”, use **Sign out**. Hot restart after pull: `R` in terminal or re-run `tool/run_admin_web.ps1`.
- **Console `Firestore probe permission-denied`:** fixed — startup probe reads public `cms_dashboard/main` (not `_admin_connectivity_probe`, which requires sign-in).
- **Blank admin shell after login (May 25):** Replaced `NavigationRail` + `SingleChildScrollView` (unbounded height / Expanded conflict on web) with scrollable `ListView` side nav (`_AdminNavigationRail`). Removed nested `Scaffold` in `demo_request_page.dart`.
- **TestprepKart logo (May 29, 2026):** `assets/images/testprepkart_logo.png` + `TestprepKartLogo` widget — top-left on signed-in `AppBar` and sign-in screen.
- **Blank page:** check browser DevTools Console; confirm `lib/firebase_options.dart` exists.

---

## App moderators — panel access (May 25, 2026)

- [x] **App Users** (`users_page.dart`): owner grants **Grant moderator** / **Revoke**; filters for panel vs app users; instructions card.
- [x] **Subscription requests (May 29, 2026):** Red dot on user row when `subscriptionRequestPending`; filter chip **Subscription requests**; owner tap request icon to approve paid user (`isPremium: true`) and clear pending, with secondary action to mark handled-only. Users nav badge when pending requests exist. Mobile writes flag via `subscription_requests` + user merge (deploy `firestore:default:rules`).
- [x] **New user registrations (Jun 2026):** Mobile signup sets `adminRegistrationUnread: true` on `users/{uid}`. Admin **Users** nav red dot when any unread registration (or pending subscription request). Users table: pink row highlight + red dot; filter **New registrations**; **Mark new registrations seen** batch clear. Deploy `firestore:default:rules` (`userAdminRegistrationFlagUnchanged`). Files: `neetprep_flutter/lib/core/services/auth_service.dart`, `neetprep_admin_web/lib/src/admin_app.dart`, `users_page.dart`, `firestore.rules`.
- [x] **Reset subscription (May 29, 2026):** Owner **Reset** on Users table — clears `isPremium`, `subscriptionExpiry`, pending request flags; user returns to free on next app sync.
- [x] **Users table UX (May 29, 2026):** **Date** first column; **Class** column (`grade` / `currentGrade`); subscription + admin actions as compact icons (request / premium / free + reset, grant/revoke); **From/To** date filters; **Export CSV** for filtered rows. Files: `users_page.dart`, `utils/csv_download_web.dart`.
- [x] **Sign-in:** Moderators use the **same email/password** as the mobile app after owner grants `role: moderator` on their `users/{uid}` doc.
- [x] **Owner-only UI:** `AdminSession.isOwner` — only `pranay3500@gmail.com` / owner UID can grant/revoke; moderators see read-only access column.
- [x] **Firestore rules:** `isPanelModerator()` + `isContentAdmin()` in `neetprep_flutter/firestore.rules` (deploy `firestore:default:rules`). Owner-only writes: `admin_settings`, user role grants.

---

## Admin web email (no Blaze) — May 21, 2026

- [x] **Architecture:** Firestore → admin web listeners (while signed in) → HTTP **email relay** on Satlas → Hostinger SMTP.
- [x] **Relay:** `deploy/email_relay/server.js` — deploy beside admin static site; URL in Settings → **Email Relay URL**.
- [x] **Triggers:** All Settings toggles + `userRegistered` welcome email; dedupe in `admin_email_sent/{key}`; logs in `email_dispatch_logs`.
- [x] **Confirm demo:** Sends immediately from admin via `AdminEmailDispatcher` (not Cloud Functions).
- **Deploy relay on Satlas** (required once): see `deploy/email_relay/README.md`
- **Deploy rules:** `firebase deploy --only firestore:rules` from `neetprep_flutter`
- **Note:** Admin tab must stay open for automatic Firestore-triggered emails (new user, message, inquiry, etc.).

---

## Admin edit dialogs — Save vs Save & Close (May 21, 2026)

- [x] **Save** keeps the popup open; **Save & Close** saves and dismisses.
- **Widget:** `lib/src/widgets/admin_dialog_save_actions.dart`
- **Applied:** Courses, Medical Colleges, Updates, Timeline, How It Works, Support FAQ, Slots (Create), Analysis reschedule/report, Settings email template + FAQ, CL Import PDF URL.

---

## Webinars CMS (May 21, 2026)

- [x] **Webinar** nav tab — create/edit webinars for mobile home + detail pages.
- [x] **Edit fix:** Loads full document by ID on edit (not stale list snapshot); list query without `orderBy` + client sort (docs missing `scheduledAt` no longer break the list).
- [x] **Thumbnail:** `thumbnailImageUrl` + optional `heroImageUrl` for mobile card/detail hero.
- [x] **Nav UI:** `Scaffold` → `Expanded` → `Row` → scrollable `NavigationRail` + `Expanded(page)` (fixes bottom overflow on Settings/Users when viewport is short). Badge streams only on `_AdminNavigationRail`.
- [x] **Demo Request page:** wrapped in inner `Scaffold` so `TabBar`/`TabBarView` get height.
- [x] **Sample analysis report PDFs (May 25, 2026):** `demo_request_page.dart` — `sampleReports` field (`title | HTTPS PDF URL`) saved to `demo_request_config/expected_score`; mobile Expected NEET Score → Sample reports opens URLs in-app.
- **Login:** `SignInPage` when not signed in; use app bar **Sign out** to return to login. First tab title is **Demo Request** by design (not a missing dashboard).
- [x] **Schedule (IST → US):** **Pick IST** date/time; saves UTC `scheduledAt` + auto `timezoneDisplay` (Eastern/Pacific, DST). Read-only US preview in form; list shows IST + US lines. Dep: `timezone` ^0.9.4; init in `main.dart`.
- [x] Fields: duration, highlights, HTML, join URL (premium in app), recordings, assets, session recording.
- [x] **Empty Firestore:** `Publish default webinar` seeds `webinars/default_featured_webinar` (same content mobile preview used). App no longer shows placeholder without Firestore.
- [x] **Disable / enable (May 29, 2026):** List row **Disable** / **Enable** buttons set `isPublished: false` / `true` (confirm before disable). **Visible in app** chip vs session status chip (Upcoming/Live/Past). Mobile `WebinarRepository.watchPublished()` already filters unpublished docs.
- **Files:** `lib/src/pages/webinars_cms_page.dart`, `lib/src/utils/webinar_schedule_timezone.dart`, `lib/main.dart`, `lib/src/admin_app.dart`

---

## Courses CMS — course detail fields (May 21, 2026)

- [x] **Pricing:** INR current/original only; USD auto on save via `lib/src/services/exchange_rate_service.dart`.
- [x] **Course edit:** HTML content, class videos (4 lines), coupon, enrollment/bank/brochure/payment bodies, feature icons (`title | description | icon`).
- [x] **YouTube:** Video ID normalized from full URL on save (page settings + course video).
- **File:** `lib/src/pages/courses_cms_page.dart`

---

## Admin Messages — mark as read (May 21, 2026)

- [x] Yellow row (`adminUnread`) clears via **Mark as read** icon (envelope) next to View — no reply required.
- **File:** `lib/src/pages/messages_page.dart`

---

## Admin sign-in security (May 21, 2026)

- [x] **Captcha** on sign-in and forgot-password (`AdminCaptchaField` — math challenge).
- [x] **Lockout:** after 3 failed attempts, block sign-in for 60 minutes (`admin_login_security/{emailKey}` in Firestore). **Temporarily off** for local: `AdminAuthConstants.loginLockoutEnabled = false` — set `true` before production.
- [x] **Forgot password:** only sends reset email if email is owner or active admin/moderator in Firestore (no `fetchSignInMethodsForEmail` — broken under enumeration protection).
- [x] **Sign-in fix (May 21):** `AdminAuthEligibility` no longer uses deprecated `fetchSignInMethodsForEmail` (returned empty → false “invalid password” after reset). Post-login gate uses email + `users/{uid}` fallback.
- [x] **Firestore rules** for `admin_login_security` in `neetprep_flutter/firestore.rules` — deploy with `firebase deploy --only firestore:rules`.
- **Files:** `sign_in_page.dart`, `forgot_password_page.dart`, `admin_login_security_service.dart`, `admin_auth_eligibility.dart`, `admin_auth_constants.dart`, `admin_captcha_field.dart`.

---

## Live deployment (May 21, 2026)

- **Production URL:** [https://neetappadmin.satlas.org/](https://neetappadmin.satlas.org/)
- **Firebase project:** `neet-prep-app-fc7fa` (`lib/firebase_options.dart`)
- [x] Email Functions admin links point at live URL (`neetprep_flutter/functions/index.js` → `ADMIN_WEB_BASE_URL`).
- [ ] **Firebase Console:** Authorized domain `neetappadmin.satlas.org`
- [ ] **CORS:** Allow live admin origin on TestprepKart CL APIs if browser import fails
- **Local dev (unchanged):** `run_admin.ps1` / `127.0.0.1:8081` for debugging only
- [x] **Connectivity test (May 21):** `neetprep_flutter/tool/firebase_connection_check.ps1` — admin URL 200; same Firestore CMS docs readable as mobile.
- **Verify:** Sign in on live URL → edit Settings or CL → Publish → mobile Production reflects change

---

## Current workstream

### CL Editor (current — 2026-06-12)

- [x] **Visual edit** + **Edit HTML** tabs — see **Update — 2026-06-12** above.
- [x] Preload from **API 2** when published doc missing or `contentSource` empty (May 16, 2026).
- **Files:** `content_library_editor_page.dart`, `content_library_html_editor.dart`, `content_library_visual_editor_web.dart`, `web/content_library_visual_editor.html`, `content_library_remote_content_service.dart`, `content_library_published_service.dart`.

### CL Editor — historical (CKEditor, superseded 2026-06-12)

### Home dashboard banners (May 16, 2026)

- [x] **Settings → Home Banners:** Publish up to 5 carousel images; set required design width/height (px) and auto-scroll interval; enable/disable carousel.
- [x] **Banner preview on web (May 25, 2026):** `AdminCorsNetworkImage` uses `WebHtmlElementStrategy.prefer` so CDN URLs (e.g. `data.testprepkart.com`) preview in admin without CORS `statusCode: 0` (mobile app was unaffected).
- [x] **Banner in-app tap targets (May 25, 2026):** Admin **On tap** → website or app screen (`linkType` + `appRoute` on Firestore); mobile `DashboardBannerNavigation` opens tabs/screens.
- [x] **Banner form persistence (May 25, 2026):** Wait for Firestore before hydrating; re-load saved URLs when returning to Home Banners tab (fixed one-shot `_loaded` applying placeholders on first empty snapshot).
- **Firestore:** `cms_dashboard/main`
- **Files:** `lib/src/pages/dashboard_banners_settings_tab.dart`, `lib/src/widgets/admin_cors_network_image.dart`

### CL Editor — CKEditor container `tpk-ck-0` not found (May 16, 2026)

**Symptom:** Red error `CKEditor container not found: tpk-ck-0`, blank editor (e.g. Stage 1).

**Cause:** `ckeditor_bridge.js` called `document.getElementById` immediately after `HtmlElementView` `onPlatformViewCreated`. Flutter web platform views mount the host `div` asynchronously; DOM id `tpk-ck-{viewId}` may not exist yet.

**Fix applied:**

- `web/ckeditor_bridge.js` — `waitForElement()` polls with `requestAnimationFrame` (up to 15s) before `ClassicEditor.create`.
- `lib/src/widgets/ckeditor/content_library_ckeditor_web.dart` — 80ms delay before `create`; guard stale `viewId` if widget disposed/remounted.
- `lib/src/pages/content_library_editor_page.dart` — mount CKEditor only after `_loadingDoc == false`; `ValueKey('$_selectedWebsiteId-$_editorMountGeneration')` bumps after each load (not `hashCode` on HTML).

**Verify:** Run admin on web (`flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8081`). Open CL Editor → Stage 1 → toolbar visible, content editable → Publish → mobile shows Firestore body.

**If it regresses:** Hard refresh (Ctrl+Shift+R) so `ckeditor_bridge.js` is not cached; confirm `index.html` loads bridge after CKEditor CDN.

### CL Editor — CKEditor content not scrollable (Jun 2026)

**Symptom:** Long curriculum pages (e.g. Stage 1) appear frozen — bottom content not reachable; editor feels like a static snapshot.

**Cause:** CKEditor editable grew taller than the Flutter `HtmlElementView` viewport with no internal scroll (`overflow` clipped by platform view).

**Fix applied:**

- `web/index.html` — flex column layout on `.tpk-ckeditor-host`; `.ck-editor__editable` gets `overflow-y: auto` and `max-height: 100%`.
- `web/ckeditor_bridge.js` — `applyEditorScrollLayout()` + `ResizeObserver` after editor create; cleanup on destroy.
- `lib/src/widgets/ckeditor/content_library_ckeditor_web.dart` — host `div` uses flex + `overflow: hidden`.

**Verify:** Hard refresh admin web → CL Editor → open Stage 1 → scroll inside the white editor area to the bottom → edit text near the end.

### CL Editor — Source (HTML) toolbar button (Jun 2026)

**Symptom:** No **Source** / raw HTML option in the CKEditor toolbar (classic build was loading first).

**Fix applied:** `web/ckeditor_bridge.js` now loads **CKEditor 5 super-build** first (v41.4.2) — includes `sourceEditing` in toolbar (</> icon, right side). Classic build is emergency fallback only (console warning, no Source).

**Verify:** Hard refresh → CL Editor → toolbar shows extended options + **Source** button → toggle to edit HTML directly.

### CL Editor — frozen / not clickable / no scroll (Jun 2026)

**Symptom:** Content visible but editor feels inactive — cannot click toolbar or body; no scroll to bottom.

**Cause:** CKEditor inside Flutter `HtmlElementView` `<div>` — Flutter web canvas layer intercepted pointer events; flex CSS also collapsed hit area.

**Fix applied (v3 — body overlay):**

- CKEditor super-build loads in `index.html`; editor panel is **`position: fixed` on `document.body`**, aligned to a marker div inside Flutter (bypasses Flutter canvas pointer blocking).
- `web/ckeditor_bridge.js` — simplified toolbar + `sourceEditing`; guards against undefined `editor.model.document`; syncs panel position on resize/scroll.
- `content_library_ckeditor_web.dart` — marker div only (pointer-events none); real editor is the body overlay.

**Verify:** Hard refresh (Ctrl+Shift+R) → CL Editor → toolbar clickable, body editable, scroll works, Source (`</>`) toggles HTML.

### CL Editor — `instances[elementId].destroy is not a function` (Jun 12, 2026)

**Symptom:** Red error `instances[elementId].destroy is not a function` or `NoSuchMethodError: editor.destroy`, blank white editor box (no toolbar).

**Cause:** External `ckeditor_bridge.js` lifecycle + Dart `js_interop` destroy calls raced when switching sections; body-overlay panel also fought Flutter layout.

**Fix applied (v6 — Flutter iframe):**

- `content_library_ckeditor_web.dart` — **pure Flutter** `HtmlElementView` + iframe (`ckeditor_frame.html`); `postMessage` init/change/destroy; no `tpkCkEditor` JS bridge from Dart.
- `web/ckeditor_frame.html` — CKEditor super-build + Source toolbar; safe `typeof editor.destroy` guards.
- `web/index.html` — removed CDN + `ckeditor_bridge.js` (CKEditor loads only inside iframe).

**Verify:** Hard refresh (Ctrl+Shift+R) → CL Editor → Stage 1 → toolbar + scroll + Source work → switch section → no red error.

### CL Import — PDF per node (May 16, 2026)

- [x] PDF icon on hierarchy rows; URLs stored in `cms_content_library/main` → `nodePdfUrls`.
- **File:** `content_library_import_page.dart`.

---

## Known pitfalls

1. **Editor before load** — Do not mount `ContentLibraryHtmlEditor` while `_loadingDoc`; controller must have HTML first.
2. **API 1 vs 2** — Tree import does not populate editor body; only API 2 or Firestore publish does.
3. **Visual vs HTML tabs** — Day-to-day edits on **Visual edit**; paste/raw markup on **Edit HTML**. Both sync to the same `contentSource` on Publish.
4. **Web cache** — After deploying editor HTML/JS changes, hard refresh (Ctrl+Shift+R); hot reload alone may not reload `content_library_visual_editor.html`.

---

## Analysis demo slots (May 29, 2026)

- [x] **Slots tab** (`slots_management_page.dart`): IST-based create/list (matches mobile session date), quick-add panel + time presets, day filter, save/error snackbars, delete confirm; `AdminDialogSaveActions` shows Firestore exceptions.
- [x] **Timezone helper:** `WebinarScheduleTimezone.istDayUtcRangeFromWall` for admin + mobile day queries.
- [x] **Nav badge:** Left menu **Demo Request** red dot when any `analysis_session_requests` has `status == pending_confirmation` (same as mobile booking); **Demo Requests** tab shows “· new” + badge icon.
- [x] **Recurring demo slots (May 29, 2026):** Admin **Slots** tab uses `analysis_slot_templates` (IST time only, no date). App books **IST tomorrow** only; timezone picker + labels like `9:30 PM CST (8:00 AM IST)`. Deploy `firestore.rules` for `analysis_slot_templates`.
- **Test:** Demo Request → Slots → create slot 2–7 days ahead (IST) → mobile **production** (Guest off) → Expected Score → Schedule → pick same IST date → refresh slots icon.

---

## Files (Content Library admin)

| Area | Path |
|------|------|
| Editor page | `lib/src/pages/content_library_editor_page.dart` |
| Import + PDF | `lib/src/pages/content_library_import_page.dart` |
| HTML editor widget | `lib/src/widgets/content_library_html_editor.dart` |
| Visual editor (web) | `lib/src/widgets/content_library_visual_editor_web.dart` |
| Visual editor iframe | `web/content_library_visual_editor.html` |
| API 2 preload | `lib/src/content_library/content_library_remote_content_service.dart` |
| Publish save | `lib/src/content_library/content_library_published_service.dart` |
