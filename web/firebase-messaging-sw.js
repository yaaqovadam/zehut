importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyD9TPBWVjMr82C2q1fAhWxOtTH1kHYrm68",
  authDomain: "zehut-engine.firebaseapp.com",
  projectId: "zehut-engine",
  storageBucket: "zehut-engine.firebasestorage.app",
  messagingSenderId: "452934157748",
  appId: "1:452934157748:web:16c96ae346a653083e9ee1"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'זכות - צפת';
  const notificationOptions = {
    body: payload.notification?.body || 'סרטון חדש עלה לאוויר!',
    icon: 'icons/Icon-192.png'
  };
  self.registration.showNotification(notificationTitle, notificationOptions);
});
