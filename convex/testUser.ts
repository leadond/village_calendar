import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

/**
 * Creates a test user profile for Apple App Store review.
 * This bypasses normal authentication flow by creating a profile directly.
 * 
 * IMPORTANT: This should only be used for testing/review purposes.
 * 
 * To use:
 * 1. Go to your Convex dashboard
 * 2. Navigate to Functions
 * 3. Run this mutation with test data
 * 4. Use the returned credentials for Apple review
 */
export const createAppleReviewUser = mutation({
  args: {
    email: v.optional(v.string()),
    name: v.optional(v.string()),
    role: v.optional(v.union(v.literal("parent"), v.literal("helper"))),
    villageName: v.optional(v.string()),
  },
  returns: v.object({
    profileId: v.id("profiles"),
    villageId: v.id("villages"),
    villageCode: v.string(),
    testCredentials: v.object({
      email: v.string(),
      name: v.string(),
      role: v.string(),
      villageName: v.string(),
      userId: v.string(),
    }),
  }),
  handler: async (ctx, args) => {
    const now = Date.now();
    
    // Default values for Apple review
    const email = args.email || "apple.reviewer@example.com";
    const name = args.name || "Apple Reviewer";
    const role = args.role || "parent";
    const villageName = args.villageName || "Apple Review Village";
    
    // Check if test user already exists
    const existingProfile = await ctx.db
      .query("profiles")
      .withIndex("by_email", (q: any) => q.eq("email", email.toLowerCase().trim()))
      .first();
    
    if (existingProfile) {
      const village = await ctx.db.get(existingProfile.villageId);
      return {
        profileId: existingProfile._id,
        villageId: existingProfile.villageId,
        villageCode: village?.code || "UNKNOWN",
        testCredentials: {
          email: existingProfile.email || email,
          name: existingProfile.name,
          role: existingProfile.role,
          villageName: village?.name || villageName,
          userId: existingProfile.userId,
        },
      };
    }
    
    // Create a test village
    const villageCode = Math.random().toString(36).substring(2, 8).toUpperCase();
    const villageId = await ctx.db.insert("villages", {
      name: villageName,
      code: villageCode,
      createdBy: "apple-review-system",
    });

    // Create test profile with predictable auth data for Apple review
    const testUserId = `apple-review-${Date.now()}`;
    const profileId = await ctx.db.insert("profiles", {
      tokenIdentifier: `apple-review-token-${testUserId}`,
      subject: testUserId,
      issuer: "apple-review",
      userId: testUserId,
      email: email.toLowerCase().trim(),
      name: name,
      role: role,
      villageId,
      createdAt: now,
      updatedAt: now,
    });

    return {
      profileId,
      villageId,
      villageCode,
      testCredentials: {
        email,
        name,
        role,
        villageName,
        userId: testUserId,
      },
    };
  },
});

/**
 * Gets information about the Apple review test user
 */
export const getAppleReviewUserInfo = query({
  args: {},
  returns: v.union(
    v.null(),
    v.object({
      email: v.string(),
      name: v.string(),
      role: v.string(),
      villageName: v.string(),
      villageCode: v.string(),
      created: v.string(),
    })
  ),
  handler: async (ctx) => {
    const profile = await ctx.db
      .query("profiles")
      .withIndex("by_email", (q: any) => q.eq("email", "apple.reviewer@example.com"))
      .first();
    
    if (!profile) return null;
    
    const village = await ctx.db.get(profile.villageId);
    
    return {
      email: profile.email || "apple.reviewer@example.com",
      name: profile.name,
      role: profile.role,
      villageName: village?.name || "Unknown",
      villageCode: village?.code || "UNKNOWN",
      created: new Date(profile.createdAt || 0).toISOString(),
    };
  },
});