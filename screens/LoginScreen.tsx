import React, { useState, useRef, useMemo } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Dimensions,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useSignIn, useAuth } from '@clerk/clerk-expo';
import { theme } from '../lib/theme';
import { trackUserLogin } from '../utils/analytics';
import { showAlert } from '../utils/alerts';
import { getFriendlyErrorMessage } from '../utils/errors';

interface Props {
  navigation: any;
}

export default function LoginScreen({ navigation }: Props) {
  const { signIn, setActive, isLoaded } = useSignIn();
  const { isSignedIn } = useAuth(); // Need to import useAuth
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const passwordRef = useRef<TextInput>(null);
  const signInButtonRef = useRef<any>(null);

  const normalizedEmail = useMemo(() => email.toLowerCase().trim(), [email]);

  const showError = (title: string, message: string) => {
    setErrorMessage(message);
    showAlert(title, message);
  };

  const [pendingMFA, setPendingMFA] = useState(false);
  const [code, setCode] = useState('');

  /* eslint-disable react-hooks/exhaustive-deps */
  const { client } = useAuth() as any; // Cast to access client for session inspection

  // Auto-redirect if already signed in
  React.useEffect(() => {
    if (isSignedIn) {
      console.log("[LoginScreen] User is already signed in. Auto-redirecting...");
      // AuthGate will handle the navigation upon re-render
    }
  }, [isSignedIn]);

  const handleLogin = async () => {
    if (!isLoaded) return;

    if (!normalizedEmail || !password) {
      showError('Error', 'Please enter email and password');
      return;
    }

    setLoading(true);
    setErrorMessage(null);
    try {
      console.log("[LoginScreen] Attempting sign in for:", normalizedEmail);
      const signInAttempt = await signIn.create({
        identifier: normalizedEmail,
        password,
      });

      if (signInAttempt.status === 'complete') {
        console.log("[LoginScreen] Sign in complete, setting active session");
        await setActive({ session: signInAttempt.createdSessionId });
        trackUserLogin();
        // Navigation auto-handled by AuthGate in MobileApp.tsx
      } else if (signInAttempt.status === 'needs_second_factor') {
        console.log("[LoginScreen] MFA required. Preparing second factor...");
        const emailFactor = signInAttempt.supportedSecondFactors?.find((f: any) => f.strategy === 'email_code');

        if (emailFactor) {
          await signInAttempt.prepareSecondFactor({ strategy: 'email_code', emailAddressId: emailFactor.emailAddressId });
          setPendingMFA(true);
          showAlert('Verification Code Sent', 'Please check your email for the verification code.');
        } else {
          showError('Login Failed', 'Unsupported MFA method. Please contact support.');
          console.error("Unsupported MFA factors:", signInAttempt.supportedSecondFactors);
        }
      } else {
        console.error("[LoginScreen] Sign in incomplete:", JSON.stringify(signInAttempt, null, 2));
        showError('Login Failed', 'Unable to complete sign in. Please verify your account.');
      }
    } catch (error: any) {
      console.error("[LoginScreen] Sign in error:", JSON.stringify(error, null, 2));

      // Handle "session already exists" case
      if (error.errors?.[0]?.code === 'session_exists') {
        console.log("[LoginScreen] Session already exists. Redirecting...");

        let sessionToActivate = signIn.createdSessionId;

        // Fallback: Check if client has any sessions if signIn didn't return one
        if (!sessionToActivate && client && client.sessions && client.sessions.length > 0) {
          console.log("[LoginScreen] Recovering existing session from client...");
          // Use the last created session or the first one known
          sessionToActivate = client.sessions[client.sessions.length - 1].id;
        }

        if (sessionToActivate) {
          await setActive({ session: sessionToActivate });
        }
        return;
      }

      const message = error.errors?.[0]?.longMessage || error.message || 'Login failed';
      showError('Login Failed', message);
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyMFA = async () => {
    if (!isLoaded || !code) return;
    setLoading(true);
    try {
      const attempt = await signIn.attemptSecondFactor({
        strategy: 'email_code',
        code,
      });

      if (attempt.status === 'complete') {
        await setActive({ session: attempt.createdSessionId });
        trackUserLogin();
      } else {
        console.error(JSON.stringify(attempt, null, 2));
        showError('Verification Failed', 'Invalid code. Please try again.');
        setCode('');
      }
    } catch (err: any) {
      console.error('MFA Verification error:', JSON.stringify(err, null, 2));
      showError('Verification Failed', err.errors?.[0]?.longMessage || err.message);
      setCode('');
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.content}
      >
        <View style={styles.header}>
          <Image
            source={require('../assets/logo.png')}
            style={{ width: 200, height: 200, marginBottom: 16 }}
            resizeMode="contain"
          />
          <Text style={styles.title}>Village Calendar</Text>
          <Text style={styles.subtitle}>Your community, connected</Text>
        </View>

        <View style={styles.form}>
          {pendingMFA ? (
            <>
              <TextInput
                style={styles.input}
                placeholder="Verification Code"
                value={code}
                onChangeText={setCode}
                keyboardType="numeric"
                autoCapitalize="none"
                placeholderTextColor={theme.colors.gray.medium}
              />
              {errorMessage ? <Text style={styles.errorText}>{errorMessage}</Text> : null}
              <TouchableOpacity
                style={[styles.button, loading && styles.buttonDisabled]}
                onPress={handleVerifyMFA}
                disabled={loading}
              >
                {loading ? (
                  <ActivityIndicator color={theme.colors.white} />
                ) : (
                  <Text style={styles.buttonText}>Verify Login</Text>
                )}
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.linkButton}
                onPress={() => setPendingMFA(false)}
              >
                <Text style={styles.linkText}>Back to Login</Text>
              </TouchableOpacity>
            </>
          ) : (
            <>
              <TextInput
                style={styles.input}
                placeholder="Email"
                value={email}
                onChangeText={(value) => {
                  setEmail(value);
                  if (errorMessage) setErrorMessage(null);
                }}
                autoCapitalize="none"
                keyboardType="email-address"
                placeholderTextColor={theme.colors.gray.medium}
                accessibilityLabel="Email input"
                accessibilityHint="Enter the email address you used to sign up"
                returnKeyType="next"
                onSubmitEditing={() => passwordRef.current?.focus()}
              />

              <TextInput
                ref={passwordRef}
                style={styles.input}
                placeholder="Password"
                value={password}
                onChangeText={(value) => {
                  setPassword(value);
                  if (errorMessage) setErrorMessage(null);
                }}
                secureTextEntry
                placeholderTextColor={theme.colors.gray.medium}
                accessibilityLabel="Password input"
                accessibilityHint="Enter your account password"
                returnKeyType="go"
                onSubmitEditing={handleLogin}
              />

              {errorMessage ? <Text style={styles.errorText}>{errorMessage}</Text> : null}

              <TouchableOpacity
                ref={signInButtonRef}
                style={[styles.button, loading && styles.buttonDisabled]}
                onPress={handleLogin}
                disabled={loading}
                accessibilityRole="button"
                accessibilityLabel="Sign In"
                accessibilityHint="Signs you into your Village Calendar account"
              >
                {loading ? (
                  <ActivityIndicator color={theme.colors.white} />
                ) : (
                  <Text style={styles.buttonText}>Sign In</Text>
                )}
              </TouchableOpacity>
            </>
          )}

          <TouchableOpacity
            style={styles.linkButton}
            onPress={() => navigation.navigate('Signup')}
            accessibilityRole="link"
            accessibilityLabel="Create an account"
            accessibilityHint="Navigates to the account creation screen"
            hitSlop={{ top: 20, bottom: 20, left: 20, right: 20 }}
          >
            <Text style={styles.linkText}>
              New here? <Text style={styles.linkTextBold}>Create an account</Text>
            </Text>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const { width } = Dimensions.get('window');
const maxFormWidth = Math.min(width - 48, 400);

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
  },
  content: {
    flex: 1,
    padding: 24,
    justifyContent: 'center',
  },
  header: {
    alignItems: 'center',
    marginBottom: 48,
  },
  title: {
    fontSize: theme.fontSizes.xxl,
    fontWeight: 'bold',
    color: theme.colors.primary,
    marginBottom: 8,
  },
  subtitle: {
    fontSize: theme.fontSizes.md,
    color: theme.colors.text.secondary,
  },
  form: {
    width: '100%',
    maxWidth: maxFormWidth,
    alignSelf: 'center',
  },
  input: {
    backgroundColor: theme.colors.white,
    borderRadius: 12,
    padding: 16,
    fontSize: theme.fontSizes.md,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: theme.colors.gray.light,
  },
  button: {
    backgroundColor: theme.colors.primary,
    borderRadius: 12,
    height: 52,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 8,
  },
  buttonDisabled: {
    opacity: 0.7,
  },
  buttonText: {
    color: theme.colors.white,
    fontSize: theme.fontSizes.lg,
    fontWeight: '600',
  },
  linkButton: {
    marginTop: 24,
    alignItems: 'center',
  },
  linkText: {
    color: theme.colors.text.secondary,
    fontSize: theme.fontSizes.sm,
  },
  linkTextBold: {
    color: theme.colors.primary,
    fontWeight: '600',
  },
  errorText: {
    color: theme.colors.accent,
    fontSize: theme.fontSizes.sm,
    marginBottom: 8,
  },
});
