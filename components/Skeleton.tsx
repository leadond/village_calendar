import React, { useEffect, useRef } from 'react';
import { View, StyleSheet, Animated, ViewStyle } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { theme } from '../lib/theme';

interface SkeletonProps {
  width: number | string;
  height: number;
  style?: ViewStyle;
}

const Skeleton: React.FC<SkeletonProps> = ({ width, height, style }) => {
  const translateX = useRef(new Animated.Value(-1)).current;

  useEffect(() => {
    const animation = Animated.loop(
      Animated.timing(translateX, {
        toValue: 1,
        duration: 1200,
        useNativeDriver: true,
      })
    );
    animation.start();
    return () => animation.stop();
  }, [translateX]);

  const animatedStyle = {
    transform: [
      {
        translateX: translateX.interpolate({
          inputRange: [-1, 1],
          outputRange: [-Number(width), Number(width)],
        }),
      },
    ],
  };

  return (
    <View style={[styles.container, { width, height }, style]}>
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
