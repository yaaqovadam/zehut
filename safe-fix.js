const fs = require('fs');
const path = require('path');

const webDir = path.join(__dirname, 'web');
// Grab only HTML files, and strictly ignore index.html
const files = fs.readdirSync(webDir).filter(f => f.endsWith('.html') && f !== 'index.html');

const splashCss = `
    .splash-container { display: flex; justify-content: center; align-items: center; position: fixed; top: 0; left: 0; right: 0; bottom: 0; width: 100%; height: 100%; z-index: 2147483647; background-color: #ffffff; transition: opacity 0.5s ease-out; }
    .splash-logo { width: 150px; height: auto; animation: splashPulse 1.2s infinite alternate; }
    @keyframes splashPulse { 0% { transform: scale(1); } 100% { transform: scale(1.1); } }
  </style>`;

const splashHtml = `
  <div class="splash-container" id="splash-screen">
    <img class="splash-logo" src="zehut-logo.png" alt="Loading Zehut..." />
  </div>
  <script>
    window.addEventListener('flutter-first-frame', function() {
      var splash = document.getElementById('splash-screen');
      if (splash) {
        splash.style.opacity = '0';
        setTimeout(() => splash.remove(), 500);
      }
    });
  </script>
`;

let count = 0;

files.forEach(file => {
  const filePath = path.join(webDir, file);
  let html = fs.readFileSync(filePath, 'utf8');

  // Ensure the background stays pristine white
  html = html.replace(/background-color:\s*#[a-zA-Z0-9]{6}/gi, 'background-color: #ffffff');

  // Inject the CSS right before the closing </style> tag (only if it isn't already there)
  if (!html.includes('.splash-container')) {
    html = html.replace('</style>', splashCss);
  }

  // Rips out the bad cache script and drops in the white splash screen
  html = html.replace(/<body>[\s\S]*?(<script src="flutter_bootstrap)/i, '<body>\n' + splashHtml + '\n  $1');

  fs.writeFileSync(filePath, html);
  count++;
});

console.log(`✅ Successfully upgraded ${count} HTML files to the white theme!`);
