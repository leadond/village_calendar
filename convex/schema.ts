import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
import { authTables } from "@convex-dev/auth/server";

export default defineSchema({
  ...authTables,

  profiles: defineTable({
    // Convex Auth identity.subject is a stable string identifier, not a DocId.
    userId: v.string(),
    name: v.string(),
    role: v.union(v.literal("parent"), v.literal("helper")),
    villageId: v.id("villages"),
  })
    .index("by_userId", ["userId"])
    .index("by_villageId", ["villageId"]),

  villages: defineTable({
    name: v.string(),
    code: v.string(), // Join code for the village
    createdBy: v.optional(v.string()),
    // Monetization (per-village)
    plan: v.optional(v.union(v.literal("free"), v.literal("pro"))),
    subscriptionStatus: v.optional(
      v.union(v.literal("inactive"), v.literal("trial"), v.literal("active"), v.literal("expired"))
    ),
    subscriptionExpiresAt: v.optional(v.number()),
    trialEndsAt: v.optional(v.number()),
  }).index("by_code", ["code"]),

  invites: defineTable({
    code: v.string(),
    villageId: v.id("villages"),
    createdBy: v.string(),
    createdAt: v.number(),
    revokedAt: v.optional(v.number()),
  })
    .index("by_code", ["code"])
    .index("by_villageId", ["villageId"]),

  villageEvents: defineTable({
    villageId: v.id("villages"),
    createdBy: v.string(),
    title: v.string(),
    description: v.string(),
    date: v.string(),
    time: v.string(),
    createdAt: v.number(),
  }).index("by_villageId", ["villageId"]),

  helpRequests: defineTable({
    villageId: v.id("villages"),
    createdBy: v.string(),
    title: v.string(),
    description: v.string(),
    date: v.string(),
    time: v.string(),
    status: v.union(v.literal("open"), v.literal("claimed")),
    claimedBy: v.optional(v.string()),
  })
    .index("by_villageId", ["villageId"])
    .index("by_createdBy", ["createdBy"]),

  messages: defineTable({
    requestId: v.id("helpRequests"),
    senderId: v.string(),
    senderName: v.string(),
    text: v.string(),
    createdAt: v.number(),
  }).index("by_requestId", ["requestId"]),

  appAdmins: defineTable({
    userId: v.string(),
    role: v.union(v.literal("owner"), v.literal("admin")),
    createdAt: v.number(),
  }).index("by_userId", ["userId"]),
});