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
  ScrollView,
  Dimensions,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useSignUp } from '@clerk/clerk-expo';
import { theme } from '../lib/theme';
import { trackUserSignup } from '../utils/analytics';
import { showAlert } from '../utils/alerts';
import { getFriendlyErrorMessage } from '../utils/errors';
import { Ionicons } from '@expo/vector-icons';

interface Props {
  navigation: any;
}

export default function SignupScreen({ navigation }: Props) {
  const { isLoaded, signUp, setActive } = useSignUp();
  const [email, setEmail] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [pendingVerification, setPendingVerification] = useState(false);
  const [code, setCode] = useState('');

  const normalizedEmail = useMemo(() => email.toLowerCase().trim(), [email]);
  const passwordRef = useRef<TextInput>(null);
  const confirmPasswordRef = useRef<TextInput>(null);

  const showError = (title: string, message: string) => {
    setErrorMessage(message);
    showAlert(title, message);
  };

  const handleSignup = async () => {
    if (!isLoaded) return;

    if (!normalizedEmail || !password || !confirmPassword || !username) {
      showError('Error', 'Please fill in all fields');
      return;
    }

    if (password.length < 8) {
      showError('Error', 'Password must be at least 8 characters');
      return;
    }

    if (password !== confirmPassword) {
      showError('Error', 'Passwords do not match');
      return;
    }

    setLoading(true);
    setErrorMessage(null);
    try {
      console.log("[SignupScreen] Creating sign up attempt for:", normalizedEmail);
      await signUp.create({
        emailAddress: normalizedEmail,
        password,
        username,
      });

      console.log("[SignupScreen] Preparing email verification");
      await signUp.prepareEmailAddressVerification({ strategy: 'email_code' });

      setPendingVerification(true);
      trackUserSignup();
    } catch (error: any) {
      console.error("[SignupScreen] signUp error:", JSON.stringify(error, null, 2));
      const message = error.errors?.[0]?.longMessage || error.message || 'Signup failed';
      showError('Signup Failed', message);
    } finally {
      setLoading(false);
    }
  };

  const handleVerify = async () => {
    if (!isLoaded) return;
    if (!code) {
      showError('Error', 'Please enter the verification code');
      return;
    }

    setLoading(true);
    try {
      console.log("[SignupScreen] Attempting email verification");
      const emailAttempt = await signUp.attemptEmailAddressVerification({
        code,
      });

      await handleCompleteSignUp(emailAttempt);
    } catch (error: any) {
      console.error("[SignupScreen] Verification error:", JSON.stringify(error, null, 2));
      const message = error.errors?.[0]?.longMessage || error.message || 'Verification failed';
      showError('Verification Failed', message);
      // Handle "already verified" case gracefully
      if (error.errors?.[0]?.code === 'verification_already_verified') {
        console.log("[SignupScreen] Email already verified. Checking status...");
        if (signUp.status === 'complete' && signUp.createdSessionId) {
          console.log("[SignupScreen] Sign up complete, setting session...");
          await setActive({ session: signUp.createdSessionId });
          return;
        }
      }

      // Handle "session already exists" case
      if (error.errors?.[0]?.code === 'session_exists') {
        console.log("[SignupScreen] Session already exists. Redirecting...");
        // If we can't get the sessionId easily from the error, user is likely already active.
        // We can try to navigate, or just let the AuthGate handle it on refresh.
        // But optimally, we check if there's a current session.
        if (signUp.createdSessionId) {
          await setActive({ session: signUp.createdSessionId });
        }
        return;
      }
    } finally {
      setLoading(false);
    }
  };

  const handleCompleteSignUp = async (completeSignUp: any) => {
    if (completeSignUp.status === 'complete') {
      console.log("[SignupScreen] Verification complete, setting active session");
      await setActive({ session: completeSignUp.createdSessionId });
    } else {
      console.error("[SignupScreen] Verification incomplete:", JSON.stringify(completeSignUp, null, 2));
      const missing = completeSignUp.missingFields?.join(', ') || 'unknown requirements';
      const unverified = completeSignUp.unverifiedFields?.join(', ') || 'none';
      showError('Verification Incomplete', `Status: ${completeSignUp.status}\nMissing: ${missing}\nUnverified: ${unverified}`);
    }
  };

  if (pendingVerification) {
    return (
      <SafeAreaView style={styles.container}>
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={styles.content}
        >
          <View style={styles.scrollContent}>
            <View style={styles.header}>
              <Text style={styles.title}>Verify Email</Text>
              <Text style={styles.subtitle}>
                Enter the code sent to {email}
              </Text>
            </View>

            <View style={styles.form}>
              <TextInput
                style={styles.input}
                placeholder="Verification Code"
                value={code}
                onChangeText={setCode}
                keyboardType="number-pad"
                placeholderTextColor={theme.colors.gray.medium}
                autoFocus
              />

              <TouchableOpacity
                style={[styles.button, loading && styles.buttonDisabled]}
                onPress={handleVerify}
                disabled={loading}
              >
                {loading ? (
                  <ActivityIndicator color={theme.colors.white} />
                ) : (
                  <Text style={styles.buttonText}>
                    Verify Email
                  </Text>
                )}
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.linkButton}
                onPress={() => {
                  setPendingVerification(false);
                }}
              >
                <Text style={styles.linkText}>Back to Sign Up</Text>
              </TouchableOpacity>
            </View>
          </View>
        </KeyboardAvoidingView>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={styles.content}
      >
        <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.scrollContent}>
          <TouchableOpacity
            style={styles.backButton}
            onPress={() => navigation.goBack()}
          >
            <Ionicons name="arrow-back" size={24} color={theme.colors.primary} />
          </TouchableOpacity>

          <View style={styles.header}>
            <Text style={styles.title}>Create Account</Text>
            <Text style={styles.subtitle}>Join your village community</Text>
          </View>

          <View style={styles.form}>
            <TextInput
              style={styles.input}
              placeholder="Username"
              value={username}
              onChangeText={setUsername}
              autoCapitalize="none"
              placeholderTextColor={theme.colors.gray.medium}
            />

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
              returnKeyType="next"
              onSubmitEditing={() => passwordRef.current?.focus()}
            />

            <TextInput
              ref={passwordRef}
              style={styles.input}
              placeholder="Password (min 8 characters)"
              value={password}
              onChangeText={(value) => {
                setPassword(value);
                if (errorMessage) setErrorMessage(null);
              }}
              secureTextEntry
              placeholderTextColor={theme.colors.gray.medium}
              returnKeyType="next"
              onSubmitEditing={() => confirmPasswordRef.current?.focus()}
            />

            <TextInput
              ref={confirmPasswordRef}
              style={styles.input}
              placeholder="Confirm Password"
              value={confirmPassword}
              onChangeText={(value) => {
                setConfirmPassword(value);
                if (errorMessage) setErrorMessage(null);
              }}
              secureTextEntry
              placeholderTextColor={theme.colors.gray.medium}
              returnKeyType="go"
              onSubmitEditing={handleSignup}
            />

            {errorMessage ? <Text style={styles.errorText}>{errorMessage}</Text> : null}

            <TouchableOpacity
              style={[styles.button, loading && styles.buttonDisabled]}
              onPress={handleSignup}
              disabled={loading}
            >
              {loading ? (
                <ActivityIndicator color={theme.colors.white} />
              ) : (
                <Text style={styles.buttonText}>Create Account</Text>
              )}
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.linkButton}
              onPress={() => navigation.navigate('Login')}
            >
              <Text style={styles.linkText}>
                Already have an account? <Text style={styles.linkTextBold}>Sign In</Text>
              </Text>
            </TouchableOpacity>
          </View>
        </ScrollView>
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
  },
  scrollContent: {
    padding: 24,
    justifyContent: 'center',
    flexGrow: 1,
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
  backButton: {
    marginBottom: 20,
  }
});
