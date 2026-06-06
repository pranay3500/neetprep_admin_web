TestprepKart — public account deletion page (Google Play)
============================================================

Upload this folder to your main website so users never see the admin domain.

Recommended public URL:
  https://www.testprepkart.com/unsubscribe/
  (upload index.html into a folder named "unsubscribe" on the server)

Play Console "Delete account URL":
  https://www.testprepkart.com/unsubscribe/

Steps:
1. Upload the file index.html (and this README if you want) to:
     public_html/unsubscribe/index.html
   on www.testprepkart.com hosting (cPanel / FTP).

2. In Firebase Console → Authentication → Settings → Authorized domains:
   Add:  testprepkart.com
   Add:  www.testprepkart.com
   (Required for Firestore from the browser on that domain.)

3. Test: open the URL, submit a test email, then check Admin panel → Unsubscribe.

This is a standalone HTML page (not the Flutter admin app). Same Firestore
collection as the admin /unsubscribe route: account_deletion_requests.

Do NOT upload the full neetprep_admin Flutter build to testprepkart.com —
that would expose the admin sign-in on your public site.
