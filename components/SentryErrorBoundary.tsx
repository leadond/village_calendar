import React from 'react';
import ErrorBoundary from 'react-native-error-boundary';
import * as Sentry from '@sentry/react-native';
import { ErrorBoundaryFallback } from './ErrorBoundary';
import { Platform } from 'react-native';

interface Props {
  children: React.ReactNode;
}

// Type guard to check if value is an Error
function isError(error: unknown): error is Error {
  return error instanceof Error;
}

const errorHandler = (error: Error, stackTrace: string) => {
  Sentry.captureException(error, {
    extra: {
      stackTrace,
    },
  });
};

// Custom fallback component for Sentry.ErrorBoundary
const SentryFallback = ({ error }: { error: unknown }) => {
  const errorObj = isError(error) ? error : new Error(String(error));
  return (
    <ErrorBoundaryFallback 
      error={errorObj} 
      resetError={() => {
        if (typeof window !== 'undefined' && window.location) {
          window.location.reload();
        }
      }} 
    />
  );
};

const SentryErrorBoundary = ({ children }: Props) => {
  if (Platform.OS === 'web') {
    // For web, use @sentry/react's ErrorBoundary
    return (
      <Sentry.ErrorBoundary fallback={SentryFallback}>
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
