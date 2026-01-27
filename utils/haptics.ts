import * as Haptics from 'expo-haptics';
import { Platform } from 'react-native';

const triggerVibrate = (pattern: number | number[]) => {
  if (Platform.OS === 'web' && 'vibrate' in navigator) {
    navigator.vibrate(pattern);
  }
};

export const triggerSuccessHaptic = () => {
  if (Platform.OS === 'web') {
    triggerVibrate(200);
  } else {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  }
};

export const triggerWarningHaptic = () => {
  if (Platform.OS === 'web') {
    triggerVibrate([100, 50, 100]);
  } else {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
  }
};

export const triggerErrorHaptic = () => {
  if (Platform.OS === 'web') {
    triggerVibrate([200, 100, 200]);
  } else {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
  }
};

export const triggerLightImpact = () => {
  if (Platform.OS === 'web') {
    triggerVibrate(50);
  } else {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  }
};

export const triggerMediumImpact = () => {
  if (Platform.OS === 'web') {
    triggerVibrate(100);
  } else {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
  }
};

export const triggerHeavyImpact = () => {
  if (Platform.OS === 'web') {
    triggerVibrate(150);
  } else {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
  }
};
