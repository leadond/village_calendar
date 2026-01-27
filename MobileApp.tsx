// Version: 1.0.2 - Production deployment (Fixed Profile Auth)
import 'react-native-gesture-handler';
import React, { useEffect, useRef } from 'react';
import { NavigationContainer, NavigationContainerRef } from '@react-navigation/native';
import { createStackNavigator, StackScreenProps, StackNavigationProp } from '@react-navigation/stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StyleSheet, ActivityIndicator, View, TouchableOpacity, Platform, Text } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { ConvexReactClient, Authenticated, Unauthenticated, AuthLoading, useConvexAuth, ConvexProvider } from 'convex/react';
import { useQuery, useMutation } from 'convex/react';
import { api } from './convex/_generated/api';
import { initSentry, setSentryUser } from './config/sentry';
import SentryErrorBoundary from './components/SentryErrorBoundary';
import { trackScreenView, analytics } from './utils/analytics';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { getEnvConfig } from './config/env';
import { ClerkProvider, useAuth } from '@clerk/clerk-expo';
import { ConvexProviderWithClerk } from 'convex/react-clerk';
import { authCache } from './lib/auth-cache';
import { useFonts } from 'expo-font';


import { theme } from './lib/theme';

// Screens
import LoginScreen from './screens/LoginScreen';
import SignupScreen from './screens/SignupScreen';
import OnboardingScreen from './screens/OnboardingScreen';
import HomeScreen from './screens/HomeScreen';
import CalendarScreen from './screens/CalendarScreen';
import CreateRequestScreen from './screens/CreateRequestScreen';
import CreateEventScreen from './screens/CreateEventScreen';
import MyItemsScreen from './screens/MyItemsScreen';
import ProfileScreen from './screens/ProfileScreen';
import AdminScreen from './screens/AdminScreen';
import ChatScreen from './screens/ChatScreen';

import { RootStackParamList, Profile } from './types';

const Stack = createStackNavigator<RootStackParamList>();
const Tab = createBottomTabNavigator();

function LoadingScreen() {
  return (
    <View style={styles.loadingContainer}>
      <ActivityIndicator size="large" color={theme.colors.primary} />
    </View>
  );
}

function LoadingStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="Loading" component={LoadingScreen} />
    </Stack.Navigator>
  );
}

function OnboardingStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="Onboarding" component={OnboardingScreen} />
    </Stack.Navigator>
  );
}

function MainTabs({
  profile,
  navigation,
}: {
  profile: Profile;
  navigation: StackNavigationProp<RootStackParamList>;
}) {
  return (
    <View style={styles.flex1}>
      <Tab.Navigator
        screenOptions={{
          headerShown: false,
          tabBarActiveTintColor: theme.colors.primary,
          tabBarInactiveTintColor: theme.colors.gray.medium,
          tabBarStyle: {
            backgroundColor: theme.colors.white,
            borderTopWidth: 1,
            borderTopColor: theme.colors.gray.light,
            height: 85,
            paddingBottom: 25,
            paddingTop: 10,
          },
          tabBarLabelStyle: {
            fontSize: 12,
            fontWeight: '500',
          },
        }}
      >
        <Tab.Screen
          name="Home"
          options={{
            tabBarLabel: 'Home',
            tabBarIcon: ({ color, size }: { color: string; size: number }) => (
              <Ionicons name="home" size={size} color={color} />
            ),
          }}
        >
          {() => <HomeScreen profile={profile} />}
        </Tab.Screen>

        <Tab.Screen
          name="Calendar"
          options={{
            tabBarLabel: 'Calendar',
            tabBarIcon: ({ color, size }: { color: string; size: number }) => (
              <Ionicons name="calendar" size={size} color={color} />
            ),
          }}
        >
          {() => <CalendarScreen profile={profile} />}
        </Tab.Screen>

        <Tab.Screen
          name="MyItems"
          options={{
            tabBarLabel: profile.role === 'parent' ? 'My Requests' : 'Commitments',
            tabBarIcon: ({ color, size }: { color: string; size: number }) => (
              <Ionicons
                name={profile.role === 'parent' ? 'document-text' : 'checkmark-circle'}
                size={size}
                color={color}
              />
            ),
          }}
        >
          {() => <MyItemsScreen profile={profile} />}
        </Tab.Screen>

        <Tab.Screen
          name="Profile"
          options={{
            tabBarLabel: 'Profile',
            tabBarIcon: ({ color, size }: { color: string; size: number }) => (
              <Ionicons name="person" size={size} color={color} />
            ),
          }}
        >
          {() => <ProfileScreen profile={profile} navigation={navigation} />}
        </Tab.Screen>
      </Tab.Navigator>

      {/* Floating Action Button for Parents */}
      {profile.role === 'parent' && (
        <TouchableOpacity
          style={styles.fab}
          onPress={() => navigation.navigate('CreateRequest')}
          accessibilityLabel="Create request"
          accessibilityHint="Create a new help request"
          accessibilityRole="button"
        >
          <Ionicons name="add" size={20} color={theme.colors.white} />
          <Text style={styles.fabText}>Ask for Help</Text>
        </TouchableOpacity>
      )}
    </View>
  );
}

function MainApp({ profile }: { profile: Profile }) {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="MainTabs">
        {(props: StackScreenProps<RootStackParamList, 'MainTabs'>) => (
          <MainTabs profile={profile} navigation={props.navigation} />
        )}
      </Stack.Screen>
      <Stack.Screen name="CreateRequest" options={{ presentation: 'modal' }}>
        {({ navigation, route }: StackScreenProps<RootStackParamList, 'CreateRequest'>) => (
          <CreateRequestScreen profile={profile} navigation={navigation} route={route} />
        )}
      </Stack.Screen>

      <Stack.Screen name="CreateEvent" options={{ presentation: 'modal' }}>
        {({ navigation }: StackScreenProps<RootStackParamList, 'CreateEvent'>) => (
          <CreateEventScreen profile={profile} navigation={navigation} />
        )}
      </Stack.Screen>

      <Stack.Screen name="Admin" options={{ presentation: 'card' }}>
        {({ navigation }: StackScreenProps<RootStackParamList, 'Admin'>) => (
          <AdminScreen navigation={navigation} />
        )}
      </Stack.Screen>

      <Stack.Screen name="Chat" options={{ presentation: 'card' }}>
        {({ route, navigation }: StackScreenProps<RootStackParamList, 'Chat'>) => (
          <ChatScreen route={route} navigation={navigation} />
        )}
      </Stack.Screen>
    </Stack.Navigator>
  );
}

function AuthenticatedApp() {
  console.log("[AuthenticatedApp] Mounting...");
  const profile = useQuery(api.profiles.getMyProfile, {});
  const sync = useMutation(api.profiles.syncMyProfileIdentity);

  useEffect(() => {
    console.log("[AuthenticatedApp] Running initial syncMyProfileIdentity");
    sync({}).then((res) => {
      console.log("[AuthenticatedApp] Sync result:", res ? "Profile synced" : "No profile found");
    }).catch((err) => {
      console.error('[AuthenticatedApp] Failed to sync identity:', err);
    });
  }, [sync]);

  useEffect(() => {
    if (profile) {
      console.log("[AuthenticatedApp] Profile loaded:", profile.id);
      setSentryUser(profile);
    } else if (profile === null) {
      console.log("[AuthenticatedApp] No profile found (null)");
      setSentryUser(null);
    } else {
      console.log("[AuthenticatedApp] Profile is still undefined (loading)");
    }
  }, [profile]);

  if (profile === undefined) {
    return <LoadingStack />;
  }

  if (profile === null) {
    return <OnboardingStack />;
  }

  return <MainApp profile={profile as Profile} />;
}

function AuthStack() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="Login" component={LoginScreen} />
      <Stack.Screen name="Signup" component={SignupScreen} />
    </Stack.Navigator>
  );
}

// Initialize Convex client using validated environment configuration.
const { convexUrl, clerkPublishableKey } = getEnvConfig();
const PUBLISHABLE_KEY = clerkPublishableKey;
const convex = new ConvexReactClient(convexUrl);

initSentry();

const linking = {
  prefixes: ['villagecalendar://', Platform.OS === 'web' ? window.location.origin : ' '],
  config: {
    screens: {
      Onboarding: 'invite/:code',
    },
  },
};

function WebViewport({ children }: { children: React.ReactNode }) {
  if (Platform.OS !== 'web') return <>{children}</>;

  return (
    <View style={styles.webOuterContainer}>
      <View style={styles.webInternalContainer}>{children}</View>
    </View>
  );
}


function AuthGate() {
  const { isLoading, isAuthenticated } = useConvexAuth();
  const { isLoaded: isClerkLoaded, isSignedIn } = useAuth();

  useEffect(() => {
    console.log("[AuthGate] Clerk Loaded:", isClerkLoaded, "Convex Loading:", isLoading, "Authenticated:", isAuthenticated);
  }, [isClerkLoaded, isLoading, isAuthenticated]);

  if (!isClerkLoaded || isLoading) {
    return <LoadingStack />;
  }

  if (!isAuthenticated && !isSignedIn) {
    return <AuthStack />;
  }

  return <AuthenticatedApp />;
}

export default function MobileApp() {
  const navigationRef = useRef<NavigationContainerRef<RootStackParamList> | null>(null);
  const routeNameRef = useRef<string | null>(null);

  useEffect(() => {
    console.log("[MobileApp] App mounted. Platform:", Platform.OS);
  }, []);

  // Load Ionicons in background - don't block app rendering
  const [fontsLoaded] = useFonts({
    ...Ionicons.font,
  });

  const handleStateChange = () => {
    const previousRouteName = routeNameRef.current;
    const currentRouteName = navigationRef.current?.getCurrentRoute()?.name;

    if (previousRouteName !== currentRouteName) {
      trackScreenView(currentRouteName);
    }
    routeNameRef.current = currentRouteName;
  };

  // Web-only: suppress noisy unhandled rejections that bypass try/catch
  useEffect(() => {
    if (Platform.OS === 'web' && typeof window !== 'undefined') {
      const handler = (event: PromiseRejectionEvent) => {
        event.preventDefault();
        console.warn('Suppressed unhandled rejection:', event.reason);
      };
      window.addEventListener('unhandledrejection', handler);
      return () => window.removeEventListener('unhandledrejection', handler);
    }
  }, []);

  return (
    <ClerkProvider publishableKey={PUBLISHABLE_KEY} tokenCache={authCache}>
      <ConvexProviderWithClerk client={convex} useAuth={useAuth}>
        <SafeAreaProvider style={styles.container}>
          <SentryErrorBoundary>
            <WebViewport>
              <NavigationContainer
                ref={navigationRef}
                onStateChange={handleStateChange}
                linking={linking}
              >
                <AuthGate />
              </NavigationContainer>
            </WebViewport>
          </SentryErrorBoundary>
        </SafeAreaProvider>
      </ConvexProviderWithClerk>
    </ClerkProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  flex1: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: theme.colors.background,
  },
  webOuterContainer: {
    flex: 1,
    backgroundColor: '#0F172A', // High-contrast professional slate
    justifyContent: 'center',
    alignItems: 'center',
  },
  webInternalContainer: {
    width: '100%',
    maxWidth: 1200, // Standard professional desktop dashboard width
    height: '100%',
    backgroundColor: theme.colors.background,
    // Add a professional shadow instead of a bezel
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.05,
    shadowRadius: 15,
    elevation: 3,
    overflow: 'hidden',
    borderWidth: Platform.OS === 'web' ? 1 : 0,
    borderColor: '#E2E8F0',
  },
  fab: {
    position: 'absolute',
    bottom: 100,
    right: 20,
    height: 56,
    paddingHorizontal: 24,
    borderRadius: 28,
    backgroundColor: theme.colors.primary,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
    gap: 8,
  },
  fabText: {
    color: theme.colors.white,
    fontSize: theme.fontSizes.md,
    fontWeight: '600',
  },
});
