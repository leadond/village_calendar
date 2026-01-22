import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

function generateCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

export const createVillage = mutation({
  args: { name: v.string() },
  returns: v.id("villages"),
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new Error("Not authenticated");

    // Generate unique code
    let code = generateCode();
    let existing = await ctx.db
      .query("villages")
      .withIndex("by_code", (q: any) => q.eq("code", code))
      .first();

    while (existing) {
      code = generateCode();
      existing = await ctx.db
        .query("villages")
        .withIndex("by_code", (q: any) => q.eq("code", code))
        .first();
    }

    return await ctx.db.insert("villages", {
      name: args.name,
      code,
      createdBy: identity.subject,
      plan: "free",
      subscriptionStatus: "inactive",
    });
  },
});

export const joinVillage = query({
  args: { code: v.string() },
  returns: v.union(
    v.null(),
    v.object({
      id: v.id("villages"),
      name: v.string(),
    })
  ),
  handler: async (ctx, args) => {
    const village = await ctx.db
      .query("villages")
      .withIndex("by_code", (q: any) => q.eq("code", args.code.toUpperCase()))
      .first();

    if (!village) return null;

    return {
      id: village._id,
      name: village.name,
    };
  },
});

export const getVillage = query({
  args: { id: v.id("villages") },
  returns: v.union(
    v.null(),
    v.object({
      id: v.id("villages"),
      name: v.string(),
      code: v.string(),
    })
  ),
  handler: async (ctx, args) => {
    const village = await ctx.db.get(args.id);
    if (!village) return null;

    return {
      id: village._id,
      name: village.name,
      code: village.code,
    };
  },
});

export const getVillageMembers = query({
  args: { villageId: v.id("villages") },
  returns: v.array(
    v.object({
      id: v.id("profiles"),
      name: v.string(),
      role: v.union(v.literal("parent"), v.literal("helper")),
    })
  ),
  handler: async (ctx, args) => {
    const profiles = await ctx.db
      .query("profiles")
      .withIndex("by_villageId", (q: any) => q.eq("villageId", args.villageId))
      .collect();

    return profiles.map((p: any) => ({
      id: p._id,
      name: p.name,
      role: p.role,
    }));
  },
});