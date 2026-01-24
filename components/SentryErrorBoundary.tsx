import React from 'react';
import ErrorBoundary from 'react-native-error-boundary';
import * as Sentry from '@sentry/react-native';
import { ErrorBoundaryFallback } from './ErrorBoundary';
import { Platform } from 'react-native';

interface Props {
  children: React.ReactNode;
}

const errorHandler = (error: Error, stackTrace: string) => {
  Sentry.captureException(error, {
    extra: {
      stackTrace,
    },
  });
};

const SentryErrorBoundary = ({ children }: Props) => {
  if (Platform.OS === 'web') {
    // For web, use @sentry/react's ErrorBoundary
    return (
      <Sentry.ErrorBoundary fallback={({ error }) => <ErrorBoundaryFallback error={error} />}>
        {children}
      </Sentry.ErrorBoundary>
    );
  } else {
    // For native, use react-native-error-boundary
    return (
      <ErrorBoundary FallbackComponent={ErrorBoundaryFallback} onError={errorHandler}>
        {children}
      </ErrorBoundary>
    );
  }
};

export default SentryErrorBoundary;
