const fs = require('fs');
const path = require('path');

const dir = __dirname;
const BASE_URL = 'https://gamfeiglintzadak.co.il';

const fallbackHebrew = {
  'index.html': 'משה פייגלין ומפלגת זהות — האפליקציה הרשמית (גם פייגלין צדק)',
  'eight-point-plan.html': 'תוכנית 8 הנקודות של משה פייגלין — מצע מפלגת זהות',
  'kitat-konenut.html': 'כיתת כוננות אזרחית — התארגנות ארצית והגנה עצמית',
  'miluim.html': 'מחשבון מגן המילואים — פטור ממס הכנסה ללוחמים',
  'parlor-meetings.html': 'חוגי בית וכנסים עם משה פייגלין — הרשמה ארצית',
  'host-moshe-national.html': 'אירוח חוג בית עם משה פייגלין — מפלגת זהות',
  'host-moshe-beit-shemesh.html': 'חוג בית עם משה פייגלין בבית שמש — מפלגת זהות',
  'moshe-feiglin-intro-zehut.html': 'משה פייגלין: הסיפור האמיתי ומה קורה כאן',
  'moshe-feiglin-bbc-blitz-hypocrisy.html': 'משה פייגלין קורע את הצביעות של ה-BBC',
  'moshe-feiglin-bbc-interview-exposed.html': 'הראיון המלא של משה פייגלין ב-BBC',
  'moshe-feiglin-exposes-gadi-eisenkot.html': 'משה פייגלין חושף את האמת על גדי איזנקוט',
  'moshe-feiglin-gadi-eisenkot-who-is-the-real-enemy.html': 'משה פייגלין על גדי איזנקוט: מי האויב האמיתי?',
  'israel-dont-get-fooled-again.html': 'ישראל, לא יעבדו עלינו שוב — משה פייגלין',
  'israel-wont-get-fooled-again.html': 'ישראל, לא יעבדו עלינו שוב — זהות',
  'moshe-feiglin-the-burden-of-proof-is-on-you.html': 'משה פייגלין: חובת ההוכחה עליכם',
  'moshe-feiglin-trump-arab-states-strategy.html': 'משה פייגלין: האסטרטגיה מול טראמפ ומדינות ערב',
  'idf-combat-veterans-october-7-betrayals.html': 'לוחמי צה״ל מדברים על ה-7 באוקטובר — משה פייגלין',
  'different-future-for-israel.html': 'עתיד אחר לישראל — משה פייגלין ומפלגת זהות',
  'dont-vote-same-thing.html': 'אל תצביעו שוב לאותו דבר — משה פייגלין',
  'enemy-burns-we-build.html': 'האויב שורף ואנחנו בונים — משה פייגלין',
  'i-believe-our-enemies.html': 'אני מאמין לאויבים שלנו — משה פייגלין',
  'if-conquest-gaza-extreme.html': 'אם כיבוש עזה זה קיצוני — משה פייגלין',
  'messianic-not-a-dirty-word.html': 'משיחי זו לא מילה גסה — משה פייגלין',
  'my-voters-not-in-pocket-unite.html': 'המצביעים שלי לא בכיס של אף אחד — משה פייגלין',
  'national-camp-must-unite.html': 'המחנה הלאומי חייב להתאחד — משה פייגלין',
  'proper-country-law-order.html': 'מדינה מתוקנת, חוק וסדר — משה פייגלין',
  'see-you-sunday-expo.html': 'ניפגש ביום ראשון בכנס זהות — משה פייגלין',
  'thirst-for-truth-growing.html': 'הצימאון לאמת רק הולך וגובר — משה פייגלין',
  'unwanted-citizens-idf-command.html': 'אזרחים לא רצויים ופיקוד צה״ל — משה פייגלין',
  'watch-share-subscribe.html': 'צפו, שתפו והצטרפו למהפכת זהות — משה פייגלין',
  'waze-is-not-to-blame.html': 'ווייז לא אשם: האמת על הביטחון — משה פייגלין',
  'who-is-afraid-of-the-temple.html': 'מי מפחד מהר הבית והמקדש? — משה פייגלין',
  'why-so-much-ptsd-just-war.html': 'למה יש כל כך הרבה הלם קרב? מלחמה צודקת — משה פייגלין'
};

const htmlFiles = fs.readdirSync(dir).filter(f => f.endsWith('.html')).sort();

const pagesMeta = htmlFiles.map(file => {
  const filePath = path.join(dir, file);
  const content = fs.readFileSync(filePath, 'utf8');
  const titleMatch = content.match(/<title>(.*?)<\/title>/i);
  let titleText = titleMatch && titleMatch[1] ? titleMatch[1].trim() : '';

  if (!titleText || !/[\u0590-\u05FF]/.test(titleText)) {
    titleText = fallbackHebrew[file] || `משה פייגלין ומפלגת זהות — ${file.replace('.html', '').replace(/-/g, ' ')}`;
  }

  return { file, title: titleText };
});

const navLinksHtml = pagesMeta
  .map(p => `<li><a href="${BASE_URL}/${p.file}">${p.title}</a></li>`)
  .join('');
const newNavBlock = `<nav aria-label="ניווט באתר זהות"><ul>${navLinksHtml}</ul></nav>`;

const safeSeoCss = `#seo-prerender { position: absolute; top: 0; left: 0; z-index: -1; opacity: 0.01; pointer-events: none; width: 100%; height: 100%; overflow: hidden; }`;

htmlFiles.forEach(file => {
  const filePath = path.join(dir, file);
  let content = fs.readFileSync(filePath, 'utf8');

  content = content.replace(/#seo-prerender\s*\{[^}]*\}/gi, safeSeoCss);

  if (/<nav aria-label="ניווט באתר זהות">[\s\S]*?<\/nav>/i.test(content)) {
    content = content.replace(/<nav aria-label="ניווט באתר זהות">[\s\S]*?<\/nav>/gi, newNavBlock);
  }

  fs.writeFileSync(filePath, content, 'utf8');
  console.log(`✅ Updated SEO CSS & Hebrew Nav in: ${file}`);
});

const today = new Date().toISOString().split('T')[0];
const CorePages = ['index.html', 'eight-point-plan.html', 'kitat-konenut.html', 'miluim.html', 'parlor-meetings.html'];

const sitemapUrls = pagesMeta.map(p => {
  const loc = p.file === 'index.html' ? `${BASE_URL}/` : `${BASE_URL}/${p.file}`;
  const priority = p.file === 'index.html' ? '1.0' : (CorePages.includes(p.file) ? '0.9' : '0.8');
  return `  <url>
    <loc>${loc}</loc>
    <lastmod>${today}</lastmod>
    <changefreq>daily</changefreq>
    <priority>${priority}</priority>
  </url>`;
}).join('\n');

const sitemapXml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${sitemapUrls}
</urlset>
`;

fs.writeFileSync(path.join(dir, 'sitemap.xml'), sitemapXml, 'utf8');
console.log(`✅ Generated web/sitemap.xml with ${pagesMeta.length} URLs`);

const robotsTxt = `User-agent: *
Allow: /

Sitemap: ${BASE_URL}/sitemap.xml
`;

fs.writeFileSync(path.join(dir, 'robots.txt'), robotsTxt, 'utf8');
console.log(`✅ Generated web/robots.txt`);
console.log(`🚀 ALL DONE! Ready to build/deploy.`);
