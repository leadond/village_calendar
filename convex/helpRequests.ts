import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getVillageRequests = query({
  args: { villageId: v.id("villages") },
  returns: v.array(
    v.object({
      id: v.id("helpRequests"),
      title: v.string(),
      description: v.string(),
      date: v.string(),
      time: v.string(),
      status: v.union(v.literal("open"), v.literal("claimed")),
      createdByName: v.string(),
      createdByPhotoUrl: v.optional(v.string()),
      claimedByName: v.optional(v.string()),
      claimedByPhotoUrl: v.optional(v.string()),
      isOwner: v.boolean(),
    })
  ),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    const currentUserId = identity?.subject;

    const requests = await ctx.db
      .query("helpRequests")
      .withIndex("by_villageId", (q: any) => q.eq("villageId", args.villageId))
      .order("desc")
      .collect();

    const results: any[] = [];
    for (const req of requests) {
      // Try resolving creator by 'subject' (new standard) then 'userId' (legacy)
      let creatorProfile = await ctx.db
        .query("profiles")
        .withIndex("by_subject", (q: any) => q.eq("subject", req.createdBy))
        .first();

      if (!creatorProfile) {
        creatorProfile = await ctx.db
          .query("profiles")
          .withIndex("by_userId", (q: any) => q.eq("userId", req.createdBy))
          .first();
      }

      let claimedByPhotoUrl = undefined;
      let claimerName = undefined;

      if (req.claimedBy) {
        let claimerProfile = await ctx.db
          .query("profiles")
          .withIndex("by_subject", (q: any) => q.eq("subject", req.claimedBy))
          .first();

        if (!claimerProfile) {
          claimerProfile = await ctx.db
            .query("profiles")
            .withIndex("by_userId", (q: any) => q.eq("userId", req.claimedBy))
            .first();
        }

        if (claimerProfile) {
          claimerName = claimerProfile.name;
          if (claimerProfile.photoStorageId) {
            claimedByPhotoUrl = await ctx.storage.getUrl(claimerProfile.photoStorageId);
          }
        }
      }

      const createdByPhotoUrl = creatorProfile?.photoStorageId
        ? await ctx.storage.getUrl(creatorProfile.photoStorageId)
        : undefined;

      results.push({
        id: req._id,
        title: req.title,
        description: req.description,
        date: req.date,
        time: req.time,
        status: req.status,
        createdByName: creatorProfile?.name ?? "Unknown",
        createdByPhotoUrl: createdByPhotoUrl ?? undefined,
        claimedByName: claimerName ?? req.claimedByName, // Prefer fresh profile name if found
        claimedByPhotoUrl: claimedByPhotoUrl ?? undefined,
        isOwner: currentUserId === req.createdBy,
      });
    }

    return results;
  },
});

export const createRequest = mutation({
  args: {
    villageId: v.id("villages"),
    title: v.string(),
    description: v.string(),
    date: v.string(),
    time: v.string(),
  },
  returns: v.id("helpRequests"),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const userId = identity.subject;

    const profiles = await ctx.db
      .query("profiles")
      .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
      .collect();

    const profile = profiles.find(p => p.villageId === args.villageId);

    if (!profile) throw new Error("Profile not found for this village");
    if (profile.role !== "parent") throw new Error("Only parents can create help requests");

    return await ctx.db.insert("helpRequests", {
      villageId: args.villageId,
      createdBy: userId,
      title: args.title,
      description: args.description,
      date: args.date,
      time: args.time,
      status: "open",
    });
  },
});

export const claimRequest = mutation({
  args: { requestId: v.id("helpRequests") },
  returns: v.null(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const userId = identity.subject;

    const request = await ctx.db.get(args.requestId);
    if (!request) throw new Error("Request not found");

    const profiles = await ctx.db
      .query("profiles")
      .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
      .collect();

    const profile = profiles.find(p => p.villageId === request.villageId);

    if (!profile) throw new Error("Profile not found for this village");
    if (profile.role !== "helper") throw new Error("Only helpers can claim requests");
    if (request.status === "claimed") throw new Error("Request already claimed");


    await ctx.db.patch(args.requestId, {
      status: "claimed",
      claimedBy: userId,
      claimedByName: profile.name,
    });

    return null;
  },
});

export const unclaimRequest = mutation({
  args: { requestId: v.id("helpRequests") },
  returns: v.null(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const userId = identity.subject;

    const request = await ctx.db.get(args.requestId);
    if (!request) throw new Error("Request not found");

    // Allow unclaim if:
    // 1. claimedBy matches current subject
    // 2. OR claimedBy matches current legacy userId (from profile)
    let isClaimer = request.claimedBy === userId;

    if (!isClaimer) {
      // Fallback check against profile userId
      const profile = await ctx.db
        .query("profiles")
        .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
        .first();
      if (profile && request.claimedBy === profile.userId) {
        isClaimer = true;
      }
    }

    if (!isClaimer) throw new Error("You didn't claim this request");

    await ctx.db.patch(args.requestId, {
      status: "open",
      claimedBy: undefined,
      claimedByName: undefined,
    });

    return null;
  },
});

export const deleteRequest = mutation({
  args: { requestId: v.id("helpRequests") },
  returns: v.null(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const userId = identity.subject;

    const request = await ctx.db.get(args.requestId);
    if (!request) throw new Error("Request not found");
    let isCreator = request.createdBy === userId;
    if (!isCreator) {
      const profile = await ctx.db
        .query("profiles")
        .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
        .first();
      if (profile && request.createdBy === profile.userId) {
        isCreator = true;
      }
    }

    if (!isCreator) throw new Error("Not your request");

    await ctx.db.delete(args.requestId);
    return null;
  },
});

export const updateRequest = mutation({
  args: {
    requestId: v.id("helpRequests"),
    title: v.string(),
    description: v.string(),
    date: v.string(),
    time: v.string(),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const userId = identity.subject;

    const request = await ctx.db.get(args.requestId);
    if (!request) throw new Error("Request not found");
    let isCreator = request.createdBy === userId;
    if (!isCreator) {
      const profile = await ctx.db
        .query("profiles")
        .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
        .first();
      if (profile && request.createdBy === profile.userId) {
        isCreator = true;
      }
    }

    if (!isCreator) throw new Error("Not your request");

    await ctx.db.patch(args.requestId, {
      title: args.title,
      description: args.description,
      date: args.date,
      time: args.time,
    });
    return null;
  },
});

export const getMyRequests = query({
  args: {},
  returns: v.array(
    v.object({
      id: v.id("helpRequests"),
      title: v.string(),
      description: v.string(),
      date: v.string(),
      time: v.string(),
      status: v.union(v.literal("open"), v.literal("claimed")),
      claimedByName: v.optional(v.string()),
      claimedByPhotoUrl: v.optional(v.string()),
    })
  ),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const userId = identity.subject;

    const requests = await ctx.db
      .query("helpRequests")
      .withIndex("by_createdBy", (q: any) => q.eq("createdBy", userId))
      .order("desc")
      .collect();

    const results = [];
    for (const r of requests) {
      let claimerProfile = null;
      if (r.claimedBy) {
        claimerProfile = await ctx.db
          .query("profiles")
          .withIndex("by_subject", (q: any) => q.eq("subject", r.claimedBy))
          .first();
        if (!claimerProfile) {
          claimerProfile = await ctx.db
            .query("profiles")
            .withIndex("by_userId", (q: any) => q.eq("userId", r.claimedBy))
            .first();
        }
      }

      const claimedByPhotoUrl = claimerProfile?.photoStorageId
        ? await ctx.storage.getUrl(claimerProfile.photoStorageId)
        : undefined;

      results.push({
        id: r._id,
        title: r.title,
        description: r.description,
        date: r.date,
        time: r.time,
        status: r.status,
        claimedByName: claimerProfile?.name ?? r.claimedByName,
        claimedByPhotoUrl: claimedByPhotoUrl ?? undefined,
      });
    }

    return results;
  },
});

export const getMyClaims = query({
  args: {},
  returns: v.array(
    v.object({
      id: v.id("helpRequests"),
      title: v.string(),
      description: v.string(),
      date: v.string(),
      time: v.string(),
      createdByName: v.string(),
      createdByPhotoUrl: v.optional(v.string()),
    })
  ),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return [];

    const userId = identity.subject;

    const requests = await ctx.db
      .query("helpRequests")
      .withIndex("by_claimedBy", (q: any) => q.eq("claimedBy", userId))
      .order("desc")
      .collect();

    const results: any[] = [];
    for (const req of requests) {
      // Try resolving creator by 'subject' (new standard) then 'userId' (legacy)
      let creatorProfile = await ctx.db
        .query("profiles")
        .withIndex("by_subject", (q: any) => q.eq("subject", req.createdBy))
        .first();

      if (!creatorProfile) {
        creatorProfile = await ctx.db
          .query("profiles")
          .withIndex("by_userId", (q: any) => q.eq("userId", req.createdBy))
          .first();
      }

      const createdByPhotoUrl = creatorProfile?.photoStorageId
        ? await ctx.storage.getUrl(creatorProfile.photoStorageId)
        : undefined;

      results.push({
        id: req._id,
        title: req.title,
        description: req.description,
        date: req.date,
        time: req.time,
        createdByName: creatorProfile?.name ?? "Unknown",
        createdByPhotoUrl: createdByPhotoUrl ?? undefined,
      });
    }

    return results;
  },
});