/**
 * Utility to map technical error messages (especially from Convex Auth)
 * to user-friendly strings.
 */
export function getFriendlyErrorMessage(error: any): string {
    const message = error?.message || '';

    // Handle common Convex Auth error codes
    if (message.includes('InvalidAccountId')) {
        return 'Account not found. Please sign up first.';
    }

    if (message.includes('InvalidPassword')) {
        return 'Incorrect password. Please try again.';
    }

    if (message.includes('TooManyRequests')) {
        return 'Too many login attempts. Please try again in a few minutes.';
    }

    if (message.includes('InvalidEmail')) {
        return 'Please enter a valid email address.';
    }

    if (message.includes('EmailAlreadyExists') || message.includes('user already exists')) {
        return 'An account with this email already exists.';
    }

    // Handle generic network or server issues
    if (message.includes('Failed to fetch') || message.includes('Network request failed')) {
        return 'Network error. Please check your internet connection.';
    }

    if (message.includes('Server Error')) {
        return 'Unable to connect to the server. Please try again later.';
    }

    // Return a generic user-friendly message for unknown errors
    return 'An unexpected error occurred. Please try again.';
}
