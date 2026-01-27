import { mutation } from "./_generated/server";
import { v } from "convex/values";

/**
 * Sync the userId of a profile when the auth system userId changes.
 * This prevents the onboarding loop when a user signs in with a different auth session.
 */
export const syncProfileUserId = mutation({
    args: {},
    returns: v.union(v.null(), v.id("profiles")),
    handler: async (ctx) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) return null;

        const userId = identity.subject;
        const email = identity.email?.toLowerCase().trim();

        if (!email) return null;

        // Find profile by email
        const profile = await ctx.db
            .query("profiles")
            .withIndex("by_email", (q: any) => q.eq("email", email))
            .first();

        if (!profile) return null;

        // If userId doesn't match, update it
        if (profile.userId !== userId) {
            console.log(`[syncProfileUserId] Syncing userId from ${profile.userId} to ${userId} for ${email}`);
            await ctx.db.patch(profile._id, { userId });
        }

        return profile._id;
    },
});
