import 'react-native-gesture-handler';
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StyleSheet, ActivityIndicator, View, TouchableOpacity, Platform } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { ConvexProvider, ConvexReactClient, Authenticated, Unauthenticated, AuthLoading } from 'convex/react';
import { ConvexAuthProvider } from '@convex-dev/auth/react';
import { useQuery } from 'convex/react';
import { api } from './convex/_generated/api';

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

const Stack = createStackNavigator();
const Tab = createBottomTabNavigator();

interface Profile {
  id: string;
  userId: string;
  name: string;
  role: 'parent' | 'helper';
  villageId: string;
  villageName: string;
  villageCode: string;
}

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

function MainTabs({ profile, navigation }: { profile: Profile; navigation: any }) {
  return (
    <View style={{ flex: 1 }}>
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
        <TouchableOpacity style={styles.fab} onPress={() => navigation.navigate('CreateRequest')}>
          <Ionicons name="add" size={28} color={theme.colors.white} />
        </TouchableOpacity>
      )}
    </View>
  );
}

function MainApp({ profile }: { profile: Profile }) {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="MainTabs">
        {(props: any) => <MainTabs profile={profile} navigation={props.navigation} />}
      </Stack.Screen>
      <Stack.Screen name="CreateRequest" options={{ presentation: 'modal' }}>
        {({ navigation }: { navigation: any }) => (
          <CreateRequestScreen profile={profile} navigation={navigation} />
        )}
      </Stack.Screen>

      <Stack.Screen name="CreateEvent" options={{ presentation: 'modal' }}>
        {({ navigation }: { navigation: any }) => (
          <CreateEventScreen profile={profile} navigation={navigation} />
        )}
      </Stack.Screen>

      <Stack.Screen name="Admin" options={{ presentation: 'card' }}>
        {({ navigation }: { navigation: any }) => <AdminScreen navigation={navigation} />}
      </Stack.Screen>

      <Stack.Screen name="Chat" options={{ presentation: 'card' }}>
        {({ route, navigation }: { route: any; navigation: any }) => (
          <ChatScreen route={route} navigation={navigation} />
        )}
      </Stack.Screen>
    </Stack.Navigator>
  );
}

function AuthenticatedApp() {
  const profile = useQuery(api.profiles.getMyProfile as any, {});

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

// Initialize Convex client
// TODO: Replace with your actual Convex deployment URL from environment variable
const convex = new ConvexReactClient(
  process.env.EXPO_PUBLIC_CONVEX_URL || 'https://placeholder.convex.cloud'
);

export default function MobileApp() {
  // Check if we're on web - ConvexAuthProvider doesn't work on web
  const isWeb = Platform.OS === 'web';

  if (isWeb) {
    // Web version - skip ConvexAuthProvider to avoid crash
    return (
      <ConvexProvider client={convex}>
        <SafeAreaProvider style={styles.container}>
          <NavigationContainer>
            <AuthLoading>
              <LoadingStack />
            </AuthLoading>

            <Unauthenticated>
              <AuthStack />
            </Unauthenticated>

            <Authenticated>
              <AuthenticatedApp />
            </Authenticated>
          </NavigationContainer>
        </SafeAreaProvider>
      </ConvexProvider>
    );
  }

  // Native (iOS/Android) - full auth support
  return (
    <ConvexAuthProvider client={convex}>
      <SafeAreaProvider style={styles.container}>
        <NavigationContainer>
          <AuthLoading>
            <LoadingStack />
          </AuthLoading>

          <Unauthenticated>
            <AuthStack />
          </Unauthenticated>

          <Authenticated>
            <AuthenticatedApp />
          </Authenticated>
        </NavigationContainer>
      </SafeAreaProvider>
    </ConvexAuthProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: theme.colors.background,
  },
  fab: {
    position: 'absolute',
    bottom: 100,
    right: 20,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: theme.colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
});
