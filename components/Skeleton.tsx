import React, { useEffect, useRef, useState } from 'react';
import {
  View,
  StyleSheet,
  Animated,
  ViewStyle,
  LayoutChangeEvent,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { theme } from '../lib/theme';

interface SkeletonProps {
  width: number | string;
  height: number;
  style?: ViewStyle;
}

const Skeleton: React.FC<SkeletonProps> = ({ width, height, style }) => {
  const translateX = useRef(new Animated.Value(-1)).current;
  const [containerWidth, setContainerWidth] = useState(0);

  useEffect(() => {
    if (containerWidth > 0) {
      const animation = Animated.loop(
        Animated.timing(translateX, {
          toValue: 1,
          duration: 1200,
          useNativeDriver: true,
        })
      );
      animation.start();
      return () => animation.stop();
    }
  }, [translateX, containerWidth]);

  const onLayout = (event: LayoutChangeEvent) => {
    setContainerWidth(event.nativeEvent.layout.width);
  };

  const animatedStyle = {
    transform: [
      {
        translateX: translateX.interpolate({
          inputRange: [-1, 1],
          outputRange: [-containerWidth, containerWidth],
        }),
      },
    ],
  };

  return (
    <View
      style={[styles.container, { width, height }, style]}
      onLayout={onLayout}
    >
      <Animated.View style={[styles.gradient, animatedStyle]}>
        <LinearGradient
          colors={['transparent', 'rgba(255, 255, 255, 0.3)', 'transparent']}
          start={{ x: 0.5, y: 0 }}
          end={{ x: 0.5, y: 1 }}
          style={styles.gradient}
        />
      </Animated.View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: theme.colors.gray.light,
    overflow: 'hidden',
    borderRadius: 8,
  },
  gradient: {
    ...StyleSheet.absoluteFillObject,
  },
});

export default Skeleton;
