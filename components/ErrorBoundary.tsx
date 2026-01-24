import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { theme } from '../lib/theme';
import { Ionicons } from '@expo/vector-icons';

interface FallbackProps {
  error: Error;
  resetError: () => void;
}

export const ErrorBoundaryFallback = ({ error, resetError }: FallbackProps) => (
  <View style={styles.container}>
    <Ionicons name="alert-circle-outline" size={64} color={theme.colors.accent} />
    <Text style={styles.title}>Something went wrong</Text>
    <Text style={styles.errorText}>{error.message}</Text>
    <TouchableOpacity style={styles.button} onPress={resetError}>
      <Text style={styles.buttonText}>Try again</Text>
    </TouchableOpacity>
  </View>
);

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: theme.colors.background,
    padding: 20,
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    color: theme.colors.text.primary,
    marginTop: 20,
    marginBottom: 10,
  },
  errorText: {
    fontSize: 16,
    color: theme.colors.text.secondary,
    textAlign: 'center',
    marginBottom: 20,
  },
  button: {
    backgroundColor: theme.colors.primary,
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 8,
  },
  buttonText: {
    color: theme.colors.white,
    fontSize: 16,
    fontWeight: 'bold',
  },
});
