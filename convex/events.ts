import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const getVillageEvents = query({
    args: { villageId: v.id("villages") },
    returns: v.array(
        v.object({
            id: v.id("villageEvents"),
            title: v.string(),
            description: v.string(),
            date: v.string(),
            time: v.string(),
            createdByName: v.string(),
            createdByPhotoUrl: v.optional(v.string()),
        })
    ),
    handler: async (ctx, args) => {
        const events = await ctx.db
            .query("villageEvents")
            .withIndex("by_villageId", (q: any) => q.eq("villageId", args.villageId))
            .order("desc")
            .collect();

        const results: any[] = [];
        for (const ev of events) {
            let creator = await ctx.db
                .query("profiles")
                .withIndex("by_subject", (q: any) => q.eq("subject", ev.createdBy))
                .first();

            if (!creator) {
                creator = await ctx.db
                    .query("profiles")
                    .withIndex("by_userId", (q: any) => q.eq("userId", ev.createdBy))
                    .first();
            }

            const createdByPhotoUrl = creator?.photoStorageId
                ? await ctx.storage.getUrl(creator.photoStorageId)
                : undefined;

            results.push({
                id: ev._id,
                title: ev.title,
                description: ev.description,
                date: ev.date,
                time: ev.time,
                createdByName: creator?.name ?? "Unknown",
                createdByPhotoUrl: createdByPhotoUrl ?? undefined,
            });
        }

        return results;
    },
});

export const createEvent = mutation({
    args: {
        villageId: v.id("villages"),
        title: v.string(),
        description: v.string(),
        date: v.string(),
        time: v.string(),
    },
    returns: v.id("villageEvents"),
    handler: async (ctx, args) => {
        const identity = await ctx.auth.getUserIdentity();
        if (!identity) throw new Error("Not authenticated");

        const profiles = await ctx.db
            .query("profiles")
            .withIndex("by_tokenIdentifier", (q: any) => q.eq("tokenIdentifier", identity.tokenIdentifier))
            .collect();

        const profile = profiles.find(p => p.villageId === args.villageId);

        if (!profile) throw new Error("Profile not found or not a member of this village");

        return await ctx.db.insert("villageEvents", {
            villageId: args.villageId,
            createdBy: identity.subject,
            title: args.title,
            description: args.description,
            date: args.date,
            time: args.time,
            createdAt: Date.now(),
        });
    },
});
