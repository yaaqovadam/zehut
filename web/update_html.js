const fs = require('fs');
const path = require('path');

const newStyle = `<style>
    body { background-color: #ffffff; margin: 0; }
        flt-text-field, input, textarea { background-color: transparent !important; color: white !important; }
        input:-webkit-autofill, input:-webkit-autofill:hover, input:-webkit-autofill:focus { -webkit-box-shadow: 0 0 0 1000px #1E293B inset !important; -webkit-text-fill-color: white !important; }

        .splash-container { display: flex; justify-content: center; align-items: center; position: fixed; top: 0; left: 0; right: 0; bottom: 0; width: 100%; height: 100%; z-index: 2147483647; background-color: #ffffff; transition: opacity 0.5s ease-out; }
        .splash-logo { width: 150px; height: auto; animation: splashPulse 1.2s infinite alternate; }
        @keyframes splashPulse { 0% { transform: scale(1); } 100% { transform: scale(1.1); } }
  </style>`;

const newBody = `<body>
<div class="splash-container" id="splash-screen">
  <img class="splash-logo" src="zehut-logo.png" alt="Loading Zehut..." />
</div>

<script>
  // 1. THE SCALPEL: Kills the zombie Service Worker
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function(registrations) {
      for(let registration of registrations) { registration.unregister(); }
    });
  }

  // 2. Fade out the splash screen once Flutter is ready
  window.addEventListener('flutter-first-frame', function() {
    var splash = document.getElementById('splash-screen');
    if (splash) {
      splash.style.pointerEvents = 'none';
      splash.style.opacity = '0';
      setTimeout(() => splash.remove(), 500);
    }
  });

  // 3. WEBKIT LOCK: Forces the browser to wait 100ms to paint the logo before freezing the processor with Flutter
  setTimeout(function() {
    var script = document.createElement('script');
    script.src = "flutter_bootstrap.js?v286";
    script.async = true;
    document.body.appendChild(script);
  }, 100);
</script>
</body>`;

const dir = __dirname;
const files = fs.readdirSync(dir).filter(f => f.endsWith('.html'));

files.forEach(file => {
  const filePath = path.join(dir, file);
  let content = fs.readFileSync(filePath, 'utf8');
  
  content = content.replace(/<style>[\s\S]*?<\/style>/gi, newStyle);
  content = content.replace(/<body>[\s\S]*?<\/body>/gi, newBody);

  fs.writeFileSync(filePath, content, 'utf8');
  console.log('Updated: ' + file);
});

console.log("All files updated successfully! Ready for Cloudflare.");
