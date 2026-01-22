import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getMyProfile = query({
  args: {},
  returns: v.union(
    v.null(),
    v.object({
      id: v.id("profiles"),
      userId: v.string(),
      name: v.string(),
      role: v.union(v.literal("parent"), v.literal("helper")),
      villageId: v.id("villages"),
      villageName: v.string(),
      villageCode: v.string(),
    })
  ),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    const userId = identity.subject;
    const profile = await ctx.db
      .query("profiles")
      .withIndex("by_userId", (q: any) => q.eq("userId", userId))
      .first();

    if (!profile) return null;

    const village = await ctx.db.get(profile.villageId);
    if (!village) return null;

    return {
      id: profile._id,
      userId: profile.userId,
      name: profile.name,
      role: profile.role,
      villageId: profile.villageId,
      villageName: village.name,
      villageCode: village.code,
    };
  },
});

export const createProfile = mutation({
  args: {
    name: v.string(),
    role: v.union(v.literal("parent"), v.literal("helper")),
    villageId: v.id("villages"),
    inviteCode: v.optional(v.string()),
  },
  returns: v.id("profiles"),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    const userId = identity.subject;

    // Invite-only enforcement: you can only join a village if you either
    // (a) created it, or (b) present a valid inviteCode for that village.
    const village = await ctx.db.get(args.villageId);
    if (!village) throw new Error("Village not found");

    const isVillageCreator = village.createdBy === userId;
    const inviteCode = args.inviteCode?.trim().toUpperCase();

    if (!isVillageCreator) {
      if (!inviteCode) throw new Error("Invite code required");

      const invite = await ctx.db
        .query("invites")
        .withIndex("by_code", (q: any) => q.eq("code", inviteCode))
        .first();

      if (!invite || invite.revokedAt) throw new Error("Invalid invite code");
      if (invite.villageId !== args.villageId) throw new Error("Invite code does not match this village");
    }

    const existing = await ctx.db
      .query("profiles")
      .withIndex("by_userId", (q: any) => q.eq("userId", userId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        name: args.name,
        role: args.role,
        villageId: args.villageId,
      });
      return existing._id;
    }

    return await ctx.db.insert("profiles", {
      userId,
      name: args.name,
      role: args.role,
      villageId: args.villageId,
    });
  },
});