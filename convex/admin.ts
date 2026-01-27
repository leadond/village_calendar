import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { assertAdmin } from "./adminAuth";

// ==========================================
// ADMIN ANALYTICS QUERIES
// ==========================================
// Run these from the Convex dashboard or create an admin screen.
// For production: add role check to ensure only admins can call these.

export const getVillageCount = query({
  args: {},
  returns: v.number(),
  handler: async (ctx) => {
    const villages = await ctx.db.query("villages").collect();
    return villages.length;
  },
});

export const getProfileCount = query({
  args: {},
  returns: v.number(),
  handler: async (ctx) => {
    const profiles = await ctx.db.query("profiles").collect();
    return profiles.length;
  },
});

export const getRequestCount = query({
  args: {},
  returns: v.number(),
  handler: async (ctx) => {
    const requests = await ctx.db.query("helpRequests").collect();
    return requests.length;
  },
});

export const getStats = query({
  args: {},
  returns: v.object({
    totalVillages: v.number(),
    totalProfiles: v.number(),
    totalHelpRequests: v.number(),
    openRequests: v.number(),
    claimedRequests: v.number(),
    parentCount: v.number(),
    helperCount: v.number(),
  }),
  handler: async (ctx) => {
    await assertAdmin(ctx);

    const villages = await ctx.db.query("villages").collect();
    const profiles = await ctx.db.query("profiles").collect();
    const requests = await ctx.db.query("helpRequests").collect();

    const parentCount = profiles.filter((p: any) => p.role === "parent").length;
    const helperCount = profiles.filter((p: any) => p.role === "helper").length;
    const openRequests = requests.filter((r: any) => r.status === "open").length;
    const claimedRequests = requests.filter((r: any) => r.status === "claimed").length;

    return {
      totalVillages: villages.length,
      totalProfiles: profiles.length,
      totalHelpRequests: requests.length,
      openRequests,
      claimedRequests,
      parentCount,
      helperCount,
    };
  },
});

export const getAllVillages = query({
  args: {},
  returns: v.array(
    v.object({
      id: v.id("villages"),
      name: v.string(),
      code: v.string(),
      memberCount: v.number(),
      requestCount: v.number(),
      createdAt: v.number(),
    })
  ),
  handler: async (ctx) => {
    await assertAdmin(ctx);

    const villages = await ctx.db.query("villages").order("desc").collect();

    const result = await Promise.all(
      villages.map(async (village: any) => {
        const members = await ctx.db
          .query("profiles")
          .withIndex("by_villageId", (q: any) => q.eq("villageId", village._id))
          .collect();

        const requests = await ctx.db
          .query("helpRequests")
          .withIndex("by_villageId", (q: any) => q.eq("villageId", village._id))
          .collect();

        return {
          id: village._id,
          name: village.name,
          code: village.code,
          memberCount: members.length,
          requestCount: requests.length,
          createdAt: village._creationTime,
        };
      })
    );

    return result;
  },
});

export const getVillageDetails = query({
  args: { villageId: v.id("villages") },
  returns: v.union(
    v.null(),
    v.object({
      id: v.id("villages"),
      name: v.string(),
      code: v.string(),
      createdAt: v.number(),
      members: v.array(
        v.object({
          id: v.id("profiles"),
          name: v.string(),
          role: v.union(v.literal("parent"), v.literal("helper")),
          userId: v.string(),
        })
      ),
      requests: v.array(
        v.object({
          id: v.id("helpRequests"),
          title: v.string(),
          status: v.union(v.literal("open"), v.literal("claimed")),
          date: v.string(),
          time: v.string(),
          createdByName: v.string(),
        })
      ),
    })
  ),
  handler: async (ctx, args) => {
    await assertAdmin(ctx);

    const village = await ctx.db.get(args.villageId);
    if (!village) return null;

    const profiles = await ctx.db
      .query("profiles")
      .withIndex("by_villageId", (q: any) => q.eq("villageId", args.villageId))
      .collect();

    const requests = await ctx.db
      .query("helpRequests")
      .withIndex("by_villageId", (q: any) => q.eq("villageId", args.villageId))
      .collect();

    const members = profiles.map((p: any) => ({
      id: p._id,
      name: p.name,
      role: p.role,
      userId: p.userId,
    }));

    const requestsWithCreator = await Promise.all(
      requests.map(async (req: any) => {
        const creator = await ctx.db
          .query("profiles")
          .withIndex("by_userId", (q: any) => q.eq("userId", req.createdBy))
          .first();

        return {
          id: req._id,
          title: req.title,
          status: req.status,
          date: req.date,
          time: req.time,
          createdByName: creator?.name ?? "Unknown",
        };
      })
    );

    return {
      id: village._id,
      name: village.name,
      code: village.code,
      createdAt: village._creationTime,
      members,
      requests: requestsWithCreator,
    };
  },
});

export const getAllProfiles = query({
  args: {},
  returns: v.array(
    v.object({
      id: v.id("profiles"),
      name: v.string(),
      role: v.union(v.literal("parent"), v.literal("helper")),
      userId: v.string(),
      villageName: v.string(),
      createdAt: v.number(),
    })
  ),
  handler: async (ctx) => {
    await assertAdmin(ctx);

    const profiles = await ctx.db.query("profiles").order("desc").collect();

    const result = await Promise.all(
      profiles.map(async (profile) => {
        const village = profile.villageId ? await ctx.db.get(profile.villageId) : null;
        return {
          id: profile._id,
          name: profile.name,
          role: profile.role,
          userId: profile.userId,
          villageName: (village as any)?.name ?? "Unknown",
          createdAt: profile._creationTime,
        };
      })
    );

    return result;
  },
});

export const getActivityReport = query({
  args: { daysBack: v.optional(v.number()) },
  returns: v.object({
    recentProfiles: v.array(
      v.object({
        name: v.string(),
        role: v.union(v.literal("parent"), v.literal("helper")),
        villageName: v.string(),
        createdAt: v.number(),
      })
    ),
    recentRequests: v.array(
      v.object({
        title: v.string(),
        villageName: v.string(),
        status: v.union(v.literal("open"), v.literal("claimed")),
        createdAt: v.number(),
      })
    ),
  }),
  handler: async (ctx, args) => {
    await assertAdmin(ctx);

    const daysBack = args.daysBack ?? 7;
    const cutoff = Date.now() - daysBack * 24 * 60 * 60 * 1000;

    const profiles = await ctx.db.query("profiles").order("desc").collect();
    const recentProfiles = profiles.filter((p: any) => p._creationTime >= cutoff);

    const requests = await ctx.db.query("helpRequests").order("desc").collect();
    const recentRequests = requests.filter((r: any) => r._creationTime >= cutoff);

    const profilesWithVillage = await Promise.all(
      recentProfiles.map(async (p) => {
        const village = p.villageId ? await ctx.db.get(p.villageId) : null;
        return {
          name: p.name,
          role: p.role,
          villageName: (village as any)?.name ?? "Unknown",
          createdAt: p._creationTime,
        };
      })
    );

    const requestsWithVillage = await Promise.all(
      recentRequests.map(async (r) => {
        const village = r.villageId ? await ctx.db.get(r.villageId) : null;
        return {
          title: r.title,
          villageName: (village as any)?.name ?? "Unknown",
          status: r.status,
          createdAt: r._creationTime,
        };
      })
    );

    return {
      recentProfiles: profilesWithVillage,
      recentRequests: requestsWithVillage,
    };
  },
});

// Maintenance: find empty villages (no members)
export const getEmptyVillages = query({
  args: {},
  returns: v.array(
    v.object({
      id: v.id("villages"),
      name: v.string(),
      code: v.string(),
      createdAt: v.number(),
    })
  ),
  handler: async (ctx) => {
    await assertAdmin(ctx);

    const villages = await ctx.db.query("villages").collect();

    const empty = [];
    for (const village of villages) {
      const members = await ctx.db
        .query("profiles")
        .withIndex("by_villageId", (q: any) => q.eq("villageId", village._id))
        .first();

      if (!members) {
        empty.push({
          id: village._id,
          name: village.name,
          code: village.code,
          createdAt: village._creationTime,
        });
      }
    }

    return empty;
  },
});

// Maintenance: find inactive villages (no requests in X days)
export const getInactiveVillages = query({
  args: { daysInactive: v.optional(v.number()) },
  returns: v.array(
    v.object({
      id: v.id("villages"),
      name: v.string(),
      code: v.string(),
      memberCount: v.number(),
      lastActivity: v.union(v.number(), v.null()),
    })
  ),
  handler: async (ctx, args) => {
    await assertAdmin(ctx);

    const daysInactive = args.daysInactive ?? 30;
    const cutoff = Date.now() - daysInactive * 24 * 60 * 60 * 1000;

    const villages = await ctx.db.query("villages").collect();

    const result = [];
    for (const village of villages) {
      const members = await ctx.db
        .query("profiles")
        .withIndex("by_villageId", (q: any) => q.eq("villageId", village._id))
        .collect();

      const requests = await ctx.db
        .query("helpRequests")
        .withIndex("by_villageId", (q: any) => q.eq("villageId", village._id))
        .order("desc")
        .first();

      const lastActivity = requests?._creationTime ?? null;

      if (!lastActivity || lastActivity < cutoff) {
        result.push({
          id: village._id,
          name: village.name,
          code: village.code,
          memberCount: members.length,
          lastActivity,
        });
      }
    }

    return result;
  },
});

export const deleteVillage = mutation({
  args: { villageId: v.id("villages") },
  returns: v.null(),
  handler: async (ctx, args) => {
    await assertAdmin(ctx);

    // Delete profiles in village
    const profiles = await ctx.db
      .query("profiles")
      .withIndex("by_villageId", (q: any) => q.eq("villageId", args.villageId))
      .collect();
    for (const p of profiles as any[]) {
      await ctx.db.delete(p._id);
    }

    // Delete requests in village
    const requests = await ctx.db
      .query("helpRequests")
      .withIndex("by_villageId", (q: any) => q.eq("villageId", args.villageId))
      .collect();
    for (const r of requests as any[]) {
      await ctx.db.delete(r._id);
    }

    await ctx.db.delete(args.villageId);
    return null;
  },
});

export const createTestUser = mutation({
  args: {
    name: v.string(),
    email: v.optional(v.string()),
    role: v.union(v.literal("parent"), v.literal("helper")),
    villageId: v.optional(v.id("villages")),
  },
  returns: v.string(), // Returns ID of created profile
  handler: async (ctx, args) => {
    // 1. Verify Admin
    await assertAdmin(ctx);
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    // 2. Determine Village
    let villageId = args.villageId;
    if (!villageId) {
      // Default to the admin's village if not specified
      const adminProfile = await ctx.db
        .query("profiles")
        .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
        .first();

      if (!adminProfile) throw new Error("Admin profile not found");
      villageId = adminProfile.villageId;
    }

    // 3. Generate Mock/Pre-fill Data
    const randomId = Math.random().toString(36).substring(7);
    const mockToken = `test|${randomId}`;
    const mockUserId = `user_test_${randomId}`; // Legacy ID format for compatibility

    // 4. Create Profile
    const profileId = await ctx.db.insert("profiles", {
      name: args.name,
      email: args.email, // If real, syncMyProfileIdentity will claim this later
      role: args.role,
      villageId: villageId!,
      // Mock identity - will be overwritten if/when real user claims it via email match
      tokenIdentifier: mockToken,
      subject: mockToken,
      issuer: "https://mock.verifier.com",
      userId: mockUserId,
      status: "active", // Auto-confirmed
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    return profileId;
  },
});