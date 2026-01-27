// convex/schema.ts
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({

  profiles: defineTable({
    // ✅ Stable identity keys
    tokenIdentifier: v.optional(v.string()),
    issuer: v.optional(v.string()),
    subject: v.optional(v.string()),

    // ✅ Backward-compatible fields
    userId: v.string(), // legacy (previously identity.subject)
    email: v.optional(v.string()),
    phoneNumber: v.optional(v.string()),
    photoStorageId: v.optional(v.id("_storage")),

    name: v.string(),
    role: v.union(v.literal("parent"), v.literal("helper")),
    villageId: v.id("villages"),

    createdAt: v.optional(v.number()),
    updatedAt: v.optional(v.number()),
    lastActiveAt: v.optional(v.number()),
    status: v.optional(v.union(v.literal("active"), v.literal("pending"), v.literal("rejected"))),
  })
    .index("by_tokenIdentifier", ["tokenIdentifier"])
    .index("by_userId", ["userId"])
    .index("by_email", ["email"])
    .index("by_subject", ["subject"])
    .index("by_villageId", ["villageId"]),

  villages: defineTable({
    name: v.string(),
    code: v.string(),
    createdBy: v.optional(v.string()),
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
    claimedByName: v.optional(v.string()),
  })
    .index("by_villageId", ["villageId"])
    .index("by_createdBy", ["createdBy"])
    .index("by_claimedBy", ["claimedBy"]),

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
