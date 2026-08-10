importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyD_JYh4QnaWk3Q0XBZYByPEokdsYP1NY2A',
  authDomain: 'shuttleprohero-dev.firebaseapp.com',
  projectId: 'shuttleprohero-dev',
  storageBucket: 'shuttleprohero-dev.firebasestorage.app',
  messagingSenderId: '296331998953',
  appId: '1:296331998953:web:9843637a752548640ee278',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle =
    payload.notification?.title || payload.data?.title || 'My Village Pro';
  const notificationOptions = {
    body:
      payload.notification?.body ||
      payload.data?.body ||
      'You have a new update.',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
