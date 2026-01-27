import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getMessages = query({
    args: { requestId: v.id("helpRequests") },
    returns: v.array(
        v.object({
            id: v.id("messages"),
            senderId: v.string(),
            senderName: v.string(),
            senderPhotoUrl: v.optional(v.string()),
            text: v.string(),
            createdAt: v.number(),
            isMe: v.boolean(),
        })
    ),
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        const currentUserId = identity?.subject;

        const messages = await ctx.db
            .query("messages")
            .withIndex("by_requestId", (q) => q.eq("requestId", args.requestId))
            .collect();

        const results = [];
        for (const msg of messages) {
            let sender = await ctx.db
                .query("profiles")
                .withIndex("by_subject", (q: any) => q.eq("subject", msg.senderId))
                .first();

            if (!sender) {
                sender = await ctx.db
                    .query("profiles")
                    .withIndex("by_userId", (q: any) => q.eq("userId", msg.senderId))
                    .first();
            }

            const senderPhotoUrl = sender?.photoStorageId
                ? await ctx.storage.getUrl(sender.photoStorageId)
                : undefined;

            results.push({
                id: msg._id,
                senderId: msg.senderId,
                senderName: sender?.name ?? msg.senderName,
                senderPhotoUrl: senderPhotoUrl ?? undefined,
                text: msg.text,
                createdAt: msg.createdAt,
                isMe: currentUserId === msg.senderId,
            });
        }

        return results;
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
        // Get sender's profile name in this village
        const profiles = await ctx.db
            .query("profiles")
            .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
            .collect();

        // We already validated the request exists above, so we know the villageId via request (implicit)
        // Actually we need the villageId to find the right profile name.
        // The previous code didn't use villageId, just userId. But now names differ per profile? 
        // Wait, name is copied to profile. Let's find the profile matching the request's village context if possible.
        // However, helpRequests don't store villageId? Yes they do.

        // We need to fetch the request *before* this? 
        // Yes, the code fetched 'const request' at line 56.

        // But 'request' object isn't available in this scope?
        // It is available. `const request = await ctx.db.get(args.requestId)` was called at line 56.

        const profile = profiles.find(p => p.villageId === request.villageId);

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
