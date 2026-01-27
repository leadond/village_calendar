// config/env.ts
export function getEnvConfig() {
  const convexUrl = process.env.EXPO_PUBLIC_CONVEX_URL;
  const clerkPublishableKey = process.env.EXPO_PUBLIC_CLERK_PUBLISHABLE_KEY;
  if (!convexUrl) throw new Error("Missing EXPO_PUBLIC_CONVEX_URL");
  if (!clerkPublishableKey) throw new Error("Missing EXPO_PUBLIC_CLERK_PUBLISHABLE_KEY");
  return { convexUrl, clerkPublishableKey };
}
