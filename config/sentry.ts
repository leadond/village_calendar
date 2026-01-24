import * as Sentry from '@sentry/react-native';
import { Platform } from 'react-native';

const SENTRY_DSN = process.env.EXPO_PUBLIC_SENTRY_DSN;

export const initSentry = () => {
  if (!SENTRY_DSN) {
    console.log('Sentry DSN not found, skipping initialization.');
    return;
  }

  if (Platform.OS === 'web') {
    // For web, use @sentry/react
    import('@sentry/react').then((SentryWeb) => {
      SentryWeb.init({
        dsn: SENTRY_DSN,
        debug: process.env.NODE_ENV === 'development',
        environment: process.env.NODE_ENV,
        release: 'village-calendar@1.0.0', // Replace with your app version
        dist: 'web',
        tracesSampleRate: 1.0,
      });
    });
  } else {
    // For native, use @sentry/react-native
    Sentry.init({
      dsn: SENTRY_DSN,
      debug: process.env.NODE_ENV === 'development',
      environment: process.env.NODE_ENV,
      release: 'village-calendar@1.0.0', // Replace with your app version
      dist: Platform.OS,
      tracesSampleRate: 1.0,
    });
  }
};

export const setSentryUser = (user: { id: string; email: string; name: string } | null) => {
  if (!SENTRY_DSN) return;
  if (user) {
    Sentry.setUser({
      id: user.id,
      email: user.email,
      username: user.name,
    });
  } else {
    Sentry.setUser(null);
  }
};
