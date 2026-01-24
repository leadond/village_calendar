import { moderateScale } from './font-scaling';

export const theme = {
  colors: {
    primary: '#60B2B0', // Soft teal
    background: '#E0F4F4', // Light teal
    accent: '#F08080', // Soft coral for help requests
    white: '#FAFAFA', // Off-white (not pure white)
    black: '#121212', // Deep charcoal (not pure black)
    gray: {
      light: '#F5F5F5',
      medium: '#9E9E9E',
      dark: '#424242',
    },
    text: {
      primary: '#212121',
      secondary: '#757575',
      inverse: '#FFFFFF',
    },
    status: {
      open: '#F08080',
      claimed: '#4CAF50',
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
    xs: moderateScale(12),
    sm: moderateScale(14),
    md: moderateScale(16),
    lg: moderateScale(18),
    xl: moderateScale(24),
    xxl: moderateScale(32),
  },
  buttonHeight: 44, // Minimum tap target for mobile
};

export type Theme = typeof theme;