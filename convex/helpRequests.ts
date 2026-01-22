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
      claimedByName: v.optional(v.string()),
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
      const creatorProfile = await ctx.db
        .query("profiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", req.createdBy))
        .first();

      results.push({
        id: req._id,
        title: req.title,
        description: req.description,
        date: req.date,
        time: req.time,
        status: req.status,
        createdByName: creatorProfile?.name ?? "Unknown",
        claimedByName: req.claimedByName,
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

    const profile = await ctx.db
      .query("profiles")
      .withIndex("by_userId", (q: any) => q.eq("userId", userId))
      .first();

    if (!profile) throw new Error("Profile not found");
    if (profile.role !== "parent") throw new Error("Only parents can create help requests");
    if (profile.villageId !== args.villageId) throw new Error("Not a member of this village");

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

    const profile = await ctx.db
      .query("profiles")
      .withIndex("by_userId", (q: any) => q.eq("userId", userId))
      .first();

    if (!profile) throw new Error("Profile not found");
    if (profile.role !== "helper") throw new Error("Only helpers can claim requests");

    const request = await ctx.db.get(args.requestId);
    if (!request) throw new Error("Request not found");
    if (request.status === "claimed") throw new Error("Request already claimed");
    if (request.villageId !== profile.villageId) throw new Error("Not in your village");

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
    if (request.claimedBy !== userId) throw new Error("You didn't claim this request");

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
    if (request.createdBy !== userId) throw new Error("Not your request");

    await ctx.db.delete(args.requestId);
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

    return requests.map((r: any) => ({
      id: r._id,
      title: r.title,
      description: r.description,
      date: r.date,
      time: r.time,
      status: r.status,
      claimedByName: r.claimedByName,
    }));
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
      const creatorProfile = await ctx.db
        .query("profiles")
        .withIndex("by_userId", (q: any) => q.eq("userId", req.createdBy))
        .first();

      results.push({
        id: req._id,
        title: req.title,
        description: req.description,
        date: req.date,
        time: req.time,
        createdByName: creatorProfile?.name ?? "Unknown",
      });
    }

    return results;
  },
});