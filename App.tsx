import React from 'react';
import { StyleSheet } from 'react-native';
declare const require: any;

export default function App() {
  // Load the full app on all platforms
  const MobileApp = require('./MobileApp').default;
  return <MobileApp />;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    backgroundColor: '#fff',
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 14,
    lineHeight: 20,
    textAlign: 'center',
    color: '#444',
    maxWidth: 420,
  },
});