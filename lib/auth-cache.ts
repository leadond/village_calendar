import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';

export const tokenCache = {
    async getToken(key: string) {
        try {
            const item = await SecureStore.getItemAsync(key);
            return item;
        } catch (error) {
            console.error('SecureStore get item error: ', error);
            await SecureStore.deleteItemAsync(key);
            return null;
        }
    },
    async saveToken(key: string, value: string) {
        try {
            return SecureStore.setItemAsync(key, value);
        } catch (err) {
            return;
        }
    },
};

// For web, Clerk uses its own internal storage mechanism by default,
// but we'll export this consistently.
export const authCache = Platform.OS === 'web' ? undefined : tokenCache;
