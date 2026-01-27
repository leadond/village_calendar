// convex/profiles.ts
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

const ProfileReturn = v.union(
  v.null(),
  v.object({
    id: v.id("profiles"),
    userId: v.string(),
    name: v.string(),
    role: v.union(v.literal("parent"), v.literal("helper")),
    villageId: v.id("villages"),
    villageName: v.string(),
    villageCode: v.string(),
    photoUrl: v.optional(v.string()), // Signed URL for display
    status: v.optional(v.union(v.literal("active"), v.literal("pending"), v.literal("rejected"))),
  })
);

function normalizeEmail(email?: string | null) {
  return email?.toLowerCase().trim();
}

async function hydrateProfile(ctx: any, profile: any) {
  try {
    const village = await ctx.db.get(profile.villageId);
    if (!village) return null;
    const photoUrl = profile.photoStorageId
      ? await ctx.storage.getUrl(profile.photoStorageId)
      : null;

    return {
      id: profile._id,
      userId: profile.userId,
      name: profile.name,
      role: profile.role,
      villageId: profile.villageId,
      villageName: village.name,
      villageCode: village.code,
      photoUrl: photoUrl ?? undefined,
      status: profile.status ?? "active", // Default to active for back-compat
    };
  } catch {
    return null;
  }
}

/**
 * ✅ Run after sign-in (and on app start while authenticated).
 * Finds the correct profile and "re-links" it to the current auth identity.
 */
/**
 * ✅ Run after sign-in (and on app start while authenticated).
 * Finds the correct profile and "re-links" it to the current auth identity.
 * UPDATED: Handles multiple profiles (multi-village).
 */
export const syncMyProfileIdentity = mutation({
  args: {},
  returns: ProfileReturn,
  handler: async (ctx) => {
    let identity: any;
    try {
      identity = await ctx.auth.getUserIdentity();
    } catch {
      return null;
    }
    if (!identity) {
      console.log("[syncMyProfileIdentity] No identity found");
      return null;
    }

    const tokenIdentifier = identity.tokenIdentifier; // stable
    console.log("[syncMyProfileIdentity] Syncing for:", tokenIdentifier);
    const subject = identity.subject;
    const issuer = identity.issuer;
    const email = normalizeEmail(identity.email);
    const now = Date.now();

    try {
      // 1) Find ALL profiles for this user by tokenIdentifier
      const profilesByToken = await ctx.db
        .query("profiles")
        .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", tokenIdentifier))
        .collect();

      let allProfiles = [...profilesByToken];

      // 2) If none found by token, look for emails (legacy/recovery)
      if (allProfiles.length === 0 && email) {
        const profileByEmail = await ctx.db
          .query("profiles")
          .withIndex("by_email", (q: any) => q.eq("email", email))
          .collect(); // Could be multiple?

        // Relink them
        for (const p of profileByEmail) {
          await ctx.db.patch(p._id, {
            tokenIdentifier,
            subject,
            issuer,
            updatedAt: now,
          });
          allProfiles.push(p);
        }
      }

      // 3) Fallback: legacy userId
      if (allProfiles.length === 0) {
        const profileByLegacy = await ctx.db
          .query("profiles")
          .withIndex("by_userId", (q: any) => q.eq("userId", subject))
          .collect();

        for (const p of profileByLegacy) {
          await ctx.db.patch(p._id, {
            tokenIdentifier,
            subject,
            issuer,
            email: email ?? p.email,
            updatedAt: now,
          });
          allProfiles.push(p);
        }
      }

      if (allProfiles.length === 0) return null;

      // Update ALL found profiles to ensure they have the latest identity info
      await Promise.all(allProfiles.map(p =>
        ctx.db.patch(p._id, {
          tokenIdentifier,
          subject,
          issuer,
          email: email ?? p.email,
        })
      ));

      // Return the most recently active one
      // Sort by lastActiveAt (desc), then updatedAt (desc)
      allProfiles.sort((a, b) => {
        const activeA = a.lastActiveAt ?? 0;
        const activeB = b.lastActiveAt ?? 0;
        if (activeA !== activeB) return activeB - activeA;
        return (b.updatedAt ?? 0) - (a.updatedAt ?? 0);
      });

      return await hydrateProfile(ctx, allProfiles[0]);
    } catch (e) {
      console.error("Sync Error:", e);
      return null;
    }
  },
});

/**
 * ✅ Used by the app shell guard.
 * NEVER throws; returns null if unknown/unlinked.
 * UPDATED: Returns the most recently active profile.
 */
export const getMyProfile = query({
  args: {},
  returns: ProfileReturn,
  handler: async (ctx) => {
    let identity: any;
    try {
      identity = await ctx.auth.getUserIdentity();
    } catch {
      return null;
    }
    if (!identity) {
      return null;
    }

    const tokenIdentifier = identity.tokenIdentifier;

    // Find all profiles
    let profiles = await ctx.db
      .query("profiles")
      .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", tokenIdentifier))
      .collect();

    // Fallback logic handled in sync, query assumes sync has run or will run. 
    // But for robustness, we can check basic fallback if empty.
    if (profiles.length === 0) {
      // Just return null, client will trigger syncMyProfileIdentity or Onboarding
      return null;
    }

    // Sort by lastActiveAt
    profiles.sort((a, b) => {
      const activeA = a.lastActiveAt ?? 0;
      const activeB = b.lastActiveAt ?? 0;
      return activeB - activeA;
    });

    return await hydrateProfile(ctx, profiles[0]);
  },
});

/**
 * ✅ Onboarding/Join submit.
 * UPDATED: Creates a NEW profile for the village if one doesn't exist.
 */
export const createMyProfile = mutation({
  args: {
    name: v.string(),
    role: v.union(v.literal("parent"), v.literal("helper")),
    villageId: v.id("villages"),
    phoneNumber: v.optional(v.string()),
  },
  returns: ProfileReturn,
  handler: async (ctx, args) => {
    let identity: any;
    try {
      identity = await ctx.auth.getUserIdentity();
    } catch {
      return null;
    }
    if (!identity) return null;

    const tokenIdentifier = identity.tokenIdentifier;
    const subject = identity.subject;
    const issuer = identity.issuer;
    const email = normalizeEmail(identity.email);
    const now = Date.now();

    // Check if user already has a profile *for this village*
    // We have to scan because we don't have a compound index on [tokenIdentifier, villageId] yet.
    // (Optimization: Add index later if needed. For now filter in memory is fine for small N)
    const existingProfiles = await ctx.db
      .query("profiles")
      .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", tokenIdentifier))
      .collect();

    const existingForVillage = existingProfiles.find(p => p.villageId === args.villageId);

    if (existingForVillage) {
      // Switch to it
      // Also update phone number if provided? Ideally yes.
      if (args.phoneNumber) {
        await ctx.db.patch(existingForVillage._id, {
          lastActiveAt: now,
          phoneNumber: args.phoneNumber,
        });
      } else {
        await ctx.db.patch(existingForVillage._id, { lastActiveAt: now });
      }
      return await hydrateProfile(ctx, existingForVillage);
    }

    // Create NEW profile for this village
    const initialStatus = args.role === "helper" ? "pending" : "active";

    const profileId = await ctx.db.insert("profiles", {
      tokenIdentifier,
      subject,
      issuer,
      userId: subject,
      email,
      name: args.name,
      role: args.role,
      villageId: args.villageId,
      phoneNumber: args.phoneNumber,
      createdAt: now,
      updatedAt: now,
      lastActiveAt: now,
      status: initialStatus,
    });

    const created = await ctx.db.get(profileId);
    if (!created) return null;
    return await hydrateProfile(ctx, created);
  },
});

export const getMyVillages = query({
  args: {},
  returns: v.array(v.object({
    villageId: v.id("villages"),
    villageName: v.string(),
    role: v.union(v.literal("parent"), v.literal("helper")),
    isActive: v.boolean(),
  })),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const profiles = await ctx.db
      .query("profiles")
      .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
      .collect();

    if (profiles.length === 0) return [];

    // Determine active one
    // Sort same way as getMyProfile
    const sorted = [...profiles].sort((a, b) => (b.lastActiveAt ?? 0) - (a.lastActiveAt ?? 0));
    const activeId = sorted[0]?._id;

    const results = [];
    for (const p of profiles) {
      const village = await ctx.db.get(p.villageId);
      if (village) {
        results.push({
          villageId: p.villageId,
          villageName: village.name,
          role: p.role,
          isActive: p._id === activeId,
        });
      }
    }
    return results;
  }
});

export const switchVillage = mutation({
  args: { villageId: v.id("villages") },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const profiles = await ctx.db
      .query("profiles")
      .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
      .collect();

    const target = profiles.find(p => p.villageId === args.villageId);
    if (!target) throw new Error("Not a member of this village");

    await ctx.db.patch(target._id, { lastActiveAt: Date.now() });
  }
});

export const joinVillageByCode = mutation({
  args: {
    code: v.string(),
    role: v.union(v.literal("parent"), v.literal("helper")),
    name: v.string(),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthorized");

    const village = await ctx.db
      .query("villages")
      .withIndex("by_code", (q: any) => q.eq("code", args.code.toUpperCase()))
      .first();

    if (!village) throw new Error("Invalid village code");

    const tokenIdentifier = identity.tokenIdentifier;
    const subject = identity.subject;
    const issuer = identity.issuer;
    const email = identity.email?.toLowerCase().trim();
    const now = Date.now();
    const initialStatus = args.role === "helper" ? "pending" : "active";

    const existingProfiles = await ctx.db
      .query("profiles")
      .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", tokenIdentifier))
      .collect();

    const existingForVillage = existingProfiles.find(p => p.villageId === village._id);
    if (existingForVillage) {
      await ctx.db.patch(existingForVillage._id, { lastActiveAt: now });
      return existingForVillage._id;
    }

    const profileId = await ctx.db.insert("profiles", {
      tokenIdentifier,
      subject,
      issuer,
      userId: subject,
      email,
      name: args.name,
      role: args.role,
      villageId: village._id,
      createdAt: now,
      updatedAt: now,
      lastActiveAt: now,
      status: initialStatus,
    });

    return profileId;
  }
});

export const generateUploadUrl = mutation(async (ctx) => {
  return await ctx.storage.generateUploadUrl();
});

export const updateProfilePhoto = mutation({
  args: {
    storageId: v.id("_storage"),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Unauthenticated");

    const profiles = await ctx.db
      .query("profiles")
      .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
      .collect();

    // Sort by last active
    profiles.sort((a: any, b: any) => (b.lastActiveAt ?? 0) - (a.lastActiveAt ?? 0));
    const profile = profiles[0];

    if (!profile) throw new Error("Profile not found");

    await ctx.db.patch(profile._id, {
      photoStorageId: args.storageId,
      updatedAt: Date.now(),
    });
  },
});
