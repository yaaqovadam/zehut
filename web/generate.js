const fs = require('fs');
const path = require('path');

// Explicit output target folder (defaults to the folder where this script lives)
const TARGET_DIR = __dirname;

const DOMAIN = "https://gamfeiglintzadak.co.il";
const CLOUDFLARE = "https://pub-142306085f2b48bda4045cd9efdd0d28.r2.dev";

// 👇 THE MASTER LIST 👇
const videos = [
  {
    htmlName: "moshe-feiglin-intro-zehut",
    imageName: "moshe-feiglin-intro-zehut.jpg",
    title: "הסיפור האמיתי: מה קורה כאן? (צפו)"
  },
  {
    htmlName: "moshe-feiglin-bbc-blitz-hypocrisy",
    imageName: "moshe-feiglin-bbc-blitz-hypocrisy.jpg",
    title: "פייגלין קורע את ה-BBC (צפו)"
  },
  {
    htmlName: "moshe-feiglin-exposes-gadi-eisenkot",
    imageName: "moshe-feiglin-exposes-gadi-eisenkot.jpg",
    title: "האמת על גדי איזנקוט (צפו)"
  },
  {
    htmlName: "moshe-feiglin-gadi-eisenkot-who-is-the-real-enemy",
    imageName: "moshe-feiglin-gadi-eisenkot-who-is-the-real-enemy.jpg",
    title: "גדי איזנקוט: מי האויב האמיתי? (צפו)"
  },
  {
    htmlName: "israel-dont-get-fooled-again",
    imageName: "israel-wont-get-fooled-again.jpg",
    title: "ישראל, לא יעבדו עלינו שוב (צפו)"
  },
  {
    htmlName: "moshe-feiglin-the-burden-of-proof",
    imageName: "moshe-feiglin-the-burden-of-proof-is-on-you.jpg",
    title: "חובת ההוכחה עליכם (צפו)"
  },
  {
    htmlName: "moshe-feiglin-trump-arab-states-strategy",
    imageName: "moshe-feiglin-netanyahu-trump.jpg",
    title: "האסטרטגיה מול מדינות ערב (צפו)"
  },
  {
    htmlName: "idf-combat-veterans-october-7-betrayals",
    imageName: "MISSING_IMAGE_UPLOAD_ME.jpg",
    title: "לוחמי צה״ל מדברים על ה-7 באוקטובר (צפו)"
  },
  {
    htmlName: "moshe-feiglin-bbc-interview-exposed",
    imageName: "MISSING_IMAGE_UPLOAD_ME_2.jpg",
    title: "הראוון המלא ב-BBC (צפו)"
  }
];

// 👇 THE MASTER CODE TEMPLATE 👇
const template = `<!DOCTYPE html>
<html lang="he">
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">

  <meta name="color-scheme" content="dark">
  <meta name="theme-color" content="#010126" media="(prefers-color-scheme: light)">
  <meta name="theme-color" content="#010126" media="(prefers-color-scheme: dark)">

  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="Zehut">

  <title>{{TITLE}}</title>
  <link rel="manifest" href="manifest.json">
  <link rel="icon" type="image/png" href="favicon.png"/>

  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="apple-touch-icon" sizes="512x512" href="icons/Icon-512.png">

  <!-- OPEN GRAPH / FACEBOOK / WHATSAPP TAGS -->
  <meta property="og:type" content="website">
  <meta property="og:url" content="${DOMAIN}/{{HTML_NAME}}.html">
  <meta property="og:title" content="{{TITLE}}">
  <meta property="og:description" content="צפו לפני הכל כדי להבין את התמונה המלאה.">
  <meta property="og:image" itemprop="image" content="${CLOUDFLARE}/{{IMAGE_NAME}}">
  <meta property="og:image:secure_url" itemprop="image" content="${CLOUDFLARE}/{{IMAGE_NAME}}">
  <meta property="og:image:type" content="image/jpeg">

  <!-- TWITTER TAGS -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:url" content="${DOMAIN}/{{HTML_NAME}}.html">
  <meta name="twitter:title" content="{{TITLE}}">
  <meta name="twitter:description" content="צפו לפני הכל כדי להבין את התמונה המלאה.">
  <meta name="twitter:image" content="${CLOUDFLARE}/{{IMAGE_NAME}}">

  <style>
    body, html { margin: 0; padding: 0; width: 100vw; height: 100vh; background-color: #ffffff; overflow: hidden; }
    flt-text-field, input, textarea { background-color: transparent !important; color: white !important; }
    input:-webkit-autofill, input:-webkit-autofill:hover, input:-webkit-autofill:focus { -webkit-box-shadow: 0 0 0 1000px #1E293B inset !important; -webkit-text-fill-color: white !important; }
  </style>
</head>
<body>
<script>
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function(registrations) {
      for(let registration of registrations) { registration.unregister(); }
    });
  }
  if ('caches' in window) {
    caches.keys().then(function(names) {
      for (let name of names) { caches.delete(name); }
    });
  }
</script>
<script src="flutter_bootstrap.js?v253" async></script>
</body>
</html>`;

// 👇 THE GENERATOR 👇
videos.forEach(video => {
  const finalHtml = template
    .replace(/{{TITLE}}/g, video.title)
    .replace(/{{HTML_NAME}}/g, video.htmlName)
    .replace(/{{IMAGE_NAME}}/g, video.imageName);

  const filePath = path.join(TARGET_DIR, `${video.htmlName}.html`);
  fs.writeFileSync(filePath, finalHtml, 'utf8');
  console.log(`✅ Successfully generated: ${filePath}`);
});

console.log("🎉 All files generated successfully!");