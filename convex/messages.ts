import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getMessages = query({
args: { requestId: v.id("helpRequests") },
returns: v.array(
v.object({
id: v.id("messages"),
senderId: v.string(),
senderName: v.string(),
text: v.string(),
createdAt: v.number(),
isMe: v.boolean(),
})
),
handler: async (ctx, args) => {
const identity = await ctx.auth.getUserIdentity();
if (!identity) return [];

const request = await ctx.db.get(args.requestId);
if (!request) return [];

// Only parent (creator) or helper (claimer) can view messages
const userId = identity.subject;
if (request.createdBy !== userId && request.claimedBy !== userId) {
return [];
}

const messages = await ctx.db
.query("messages")
.withIndex("by_requestId", (q: any) => q.eq("requestId", args.requestId))
.order("asc")
.collect();

return messages.map((m: any) => ({
id: m._id,
senderId: m.senderId,
senderName: m.senderName,
text: m.text,
createdAt: m.createdAt,
isMe: m.senderId === userId,
}));
},
});

export const sendMessage = mutation({
args: {
requestId: v.id("helpRequests"),
text: v.string(),
},
returns: v.id("messages"),
handler: async (ctx, args) => {
const identity = await ctx.auth.getUserIdentity();
if (!identity) throw new Error("Not authenticated");

const request = await ctx.db.get(args.requestId);
if (!request) throw new Error("Request not found");

const userId = identity.subject;

// Only parent or helper can send messages
if (request.createdBy !== userId && request.claimedBy !== userId) {
throw new Error("You don't have access to this conversation");
}

// Get sender's profile name
const profile = await ctx.db
.query("profiles")
.withIndex("by_userId", (q: any) => q.eq("userId", userId))
.first();

return await ctx.db.insert("messages", {
requestId: args.requestId,
senderId: userId,
senderName: profile?.name ?? "Unknown",
text: args.text.trim(),
createdAt: Date.now(),
});
},
});

export const getUnreadCount = query({
args: { requestId: v.id("helpRequests") },
returns: v.number(),
handler: async (ctx, args) => {
const identity = await ctx.auth.getUserIdentity();
if (!identity) return 0;

const messages = await ctx.db
.query("messages")
.withIndex("by_requestId", (q: any) => q.eq("requestId", args.requestId))
.collect();

// For now just return total - can add read receipts later
return messages.length;
},
});
