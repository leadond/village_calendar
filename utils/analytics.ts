// A simple analytics utility for logging key events.
// This can be expanded to integrate with a third-party analytics service like
// Amplitude, Mixpanel, or Expo's built-in analytics.

type EventName =
  | 'user_signup'
  | 'user_login'
  | 'user_logout'
  | 'request_created'
  | 'request_claimed'
  | 'request_deleted'
  | 'request_unclaimed'
  | 'event_created'
  | 'village_joined'
  | 'village_created'
  | 'invite_sent'
  | 'screen_view';

interface EventProperties {
  [key: string]: any;
}

const logEvent = (eventName: EventName, properties: EventProperties = {}) => {
  if (process.env.NODE_ENV === 'development') {
    console.log(`[Analytics] Event: ${eventName}`, properties);
  }
  // In a production environment, you would send this to your analytics service
  // For example:
  // analytics().logEvent(eventName, properties);
};

export const trackScreenView = (screenName: string) => {
  logEvent('screen_view', { screenName });
};

export const trackUserSignup = () => {
  logEvent('user_signup');
};

export const trackUserLogin = () => {
  logEvent('user_login');
};

export const trackRequestCreated = (properties: { villageId: string; requestId: string }) => {
  logEvent('request_created', properties);
};

export const trackRequestClaimed = (properties: { villageId: string; requestId: string }) => {
  logEvent('request_claimed', properties);
};

export const trackRequestDeleted = (properties: { villageId: string; requestId: string }) => {
  logEvent('request_deleted', properties);
};

export const trackRequestUnclaimed = (properties: { villageId: string; requestId: string }) => {
  logEvent('request_unclaimed', properties);
};

export const trackEventCreated = (properties: { villageId: string; eventId: string }) => {
  logEvent('event_created', properties);
};

export const trackVillageJoined = (properties: { villageId: string; inviteCode: string }) => {
  logEvent('village_joined', properties);
};

export const trackVillageCreated = (properties: { villageId: string }) => {
  logEvent('village_created', properties);
};

export const trackInviteSent = (properties: { villageId: string; inviteCode: string }) => {
  logEvent('invite_sent', properties);
};

export const trackUserLogout = () => {
  logEvent('user_logout');
};

// Export an analytics object for convenience
export const analytics = {
  track: (eventName: EventName, properties?: EventProperties) => {
    logEvent(eventName, properties);
  },
  trackScreenView,
  trackUserSignup,
  trackUserLogin,
  trackUserLogout,
  trackRequestCreated,
  trackRequestClaimed,
  trackRequestDeleted,
  trackRequestUnclaimed,
  trackEventCreated,
  trackVillageJoined,
  trackVillageCreated,
  trackInviteSent,
};
