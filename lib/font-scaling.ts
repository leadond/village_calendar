import { Dimensions, Platform } from 'react-native';
const { width: windowWidth, height: windowHeight } = Dimensions.get('window');

// Cap width and height for scaling on web/large screens
const width = Platform.OS === 'web' ? Math.min(windowWidth, 500) : windowWidth;
const height = Platform.OS === 'web' ? Math.min(windowHeight, 812) : windowHeight;

// Guideline sizes are based on standard ~5" screen mobile device
const guidelineBaseWidth = 375;
const guidelineBaseHeight = 812;

// More conservative scaling for better readability
const scale = (size: number) => (width / guidelineBaseWidth) * size;
const verticalScale = (size: number) => (height / guidelineBaseHeight) * size;

// Dampen scaling even more on web (factor 0.15 instead of 0.3)
const moderateScale = (size: number, factor = Platform.OS === 'web' ? 0.15 : 0.3) =>
    size + (scale(size) - size) * factor;

export { scale, verticalScale, moderateScale };
