const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');

const serviceAccount = require('./serviceAccountKey.json');

if (!getApps().length) {
  initializeApp({ credential: cert(serviceAccount) });
}

const db = getFirestore();
const DOMAIN = "https://gamfeiglintzadak.co.il";

const template = `<!DOCTYPE html>
<html lang="he">
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{TITLE}}</title>
  <meta property="og:title" content="{{TITLE}}">
  <meta property="og:image" content="{{IMAGE}}">
</head>
<body>
<script src="flutter_bootstrap.js?v253" async></script>
</body>
</html>`;

async function buildPages() {
  try {
    const snapshot = await db.collection('feeds').get();
    snapshot.forEach(doc => {
      const data = doc.data();
      const title = data.title || "צפו בסרטון המלא";
      const imageUrl = data.thumb || data.image || "";
      const slug = data.slug || doc.id;

      const finalHtml = template
        .replace(/{{TITLE}}/g, title)
        .replace(/{{IMAGE}}/g, imageUrl);

      fs.writeFileSync(`${slug}.html`, finalHtml, 'utf8');
      console.log(`✅ Generated: ${slug}.html -> ${title}`);
    });
    console.log("🎉 All HTML pages built successfully!");
  } catch (err) {
    console.error("Error building pages:", err);
  } finally {
    process.exit(0);
  }
}

buildPages();