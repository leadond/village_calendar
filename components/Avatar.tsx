import React from 'react';
import { View, Text, Image, StyleSheet, ImageStyle, StyleProp } from 'react-native';
import { theme } from '../lib/theme';

interface AvatarProps {
    uri?: string | null;
    name: string;
    size?: number;
    style?: StyleProp<ImageStyle>;
}

export default function Avatar({ uri, name, size = 40, style }: AvatarProps) {
    const getInitials = (name: string) => {
        return name
            .split(' ')
            .map((n) => n[0])
            .slice(0, 2)
            .join('')
            .toUpperCase();
    };

    const backgroundColor = theme.colors.primary; // Could alternate colors based on name hash

    if (uri) {
        return (
            <Image
                source={{ uri }}
                style={[
                    styles.image,
                    { width: size, height: size, borderRadius: size / 2 },
                    style,
                ]}
            />
        );
    }

    return (
        <View
            style={[
                styles.container,
                {
                    width: size,
                    height: size,
                    borderRadius: size / 2,
                    backgroundColor,
                },
                style,
            ]}
        >
            <Text style={[styles.text, { fontSize: size * 0.4 }]}>
                {getInitials(name)}
            </Text>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        justifyContent: 'center',
        alignItems: 'center',
        overflow: 'hidden',
    },
    image: {
        backgroundColor: theme.colors.gray.light,
    },
    text: {
        color: theme.colors.white,
        fontWeight: '600',
    },
});
