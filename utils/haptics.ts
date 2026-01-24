import * as Haptics from 'expo-haptics';

export const triggerSuccessHaptic = () => {
  Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
};

export const triggerWarningHaptic = () => {
  Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
};

export const triggerErrorHaptic = () => {
  Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
};

export const triggerLightImpact = () => {
  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
};

export const triggerMediumImpact = () => {
  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
};

export const triggerHeavyImpact = () => {
  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
};
