import { moderateScale } from './font-scaling';

export const theme = {
  colors: {
    primary: '#4AA9D9', // Vibrant "Village Blue" from mockup
    background: '#F0F8FC', // Very light blue background
    card: '#FFFFFF',
    accent: '#8BC34A', // Green for help/action
    white: '#FFFFFF',
    black: '#000000',
    primaryLight: '#E1F5FE', // Very light blue for secondary backgrounds
    primaryExtraLight: '#E1F5FE',
    errorLight: '#FFEBEE',
    gray: {
      light: '#E0E0E0',
      medium: '#9E9E9E',
      dark: '#424242',
    },
    text: {
      primary: '#1A3B5C', // Dark blue-gray for high contrast
      secondary: '#546E7A', // Blue-gray for secondary text
      inverse: '#FFFFFF',
    },
    status: {
      open: '#4AA9D9', // Blue for open
      claimed: '#8BC34A', // Green for claimed
      openBackground: '#E1F5FE',
      claimedBackground: '#F1F8E9',
    },
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
  },
  borderRadius: {
    sm: 4,
    md: 8,
    lg: 12,
    xl: 16,
  },
  fonts: {
    regular: 'Inter_400Regular',
    medium: 'Inter_500Medium',
    semibold: 'Inter_600SemiBold',
    bold: 'Inter_700Bold',
  },
  fontSizes: {
    xs: moderateScale(10),
    sm: moderateScale(12),
    md: moderateScale(14),
    lg: moderateScale(16),
    xl: moderateScale(20),
    xxl: moderateScale(24),
  },
  buttonHeight: 44, // Minimum tap target for mobile
};

export type Theme = typeof theme;