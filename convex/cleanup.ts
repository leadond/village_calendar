import { mutation, query } from "./_generated/server";

/**
 * Query to preview what will be deleted
 */
export const previewCleanup = query({
    args: {},
    handler: async (ctx) => {
        const ADMIN_EMAIL = "leadond@gmail.com";

        // Get all profiles
        const allProfiles = await ctx.db.query("profiles").collect();
        const adminProfile = allProfiles.find(p => p.email === ADMIN_EMAIL);
        const profilesToDelete = allProfiles.filter(p => p.email !== ADMIN_EMAIL);

        // Get all villages
        const allVillages = await ctx.db.query("villages").collect();


        return {
            summary: {
                totalProfiles: allProfiles.length,
                profilesToKeep: adminProfile ? 1 : 0,
                profilesToDelete: profilesToDelete.length,
                totalVillages: allVillages.length,
                villagesToDelete: allVillages.length,
            },
            adminProfile: adminProfile ? {
                id: adminProfile._id,
                email: adminProfile.email,
                name: adminProfile.name,
            } : null,
            profilesToDelete: profilesToDelete.map(p => ({
                id: p._id,
                email: p.email,
                name: p.name,
            })),
            villagesToDelete: allVillages.map(v => ({
                id: v._id,
                name: v.name,
                code: v.code,
            })),
        };
    },
});

/**
 * Mutation to clean up all data except admin account
 */
export const cleanupDatabase = mutation({
    args: {},
    handler: async (ctx) => {
        const ADMIN_EMAIL = "leadond@gmail.com";

        // Get all profiles
        const allProfiles = await ctx.db.query("profiles").collect();
        const adminProfile = allProfiles.find(p => p.email === ADMIN_EMAIL);

        // Delete all profiles except admin
        let deletedProfiles = 0;
        for (const profile of allProfiles) {
            if (profile.email !== ADMIN_EMAIL) {
                await ctx.db.delete(profile._id);
                deletedProfiles++;
            }
        }

        // Delete all villages
        const allVillages = await ctx.db.query("villages").collect();
        for (const village of allVillages) {
            await ctx.db.delete(village._id);
        }


        // Delete all village events
        const allEvents = await ctx.db.query("villageEvents").collect();
        for (const event of allEvents) {
            await ctx.db.delete(event._id);
        }

        // Delete all help requests
        const allRequests = await ctx.db.query("helpRequests").collect();
        for (const request of allRequests) {
            await ctx.db.delete(request._id);
        }

        // Delete all messages
        const allMessages = await ctx.db.query("messages").collect();
        for (const message of allMessages) {
            await ctx.db.delete(message._id);
        }

        // Delete all invites
        const allInvites = await ctx.db.query("invites").collect();
        for (const invite of allInvites) {
            await ctx.db.delete(invite._id);
        }

        return {
            success: true,
            deletedCounts: {
                profiles: deletedProfiles,
                villages: allVillages.length,
                users: 0,
                villageEvents: allEvents.length,
                helpRequests: allRequests.length,
                messages: allMessages.length,
                invites: allInvites.length,
            },
            preserved: {
                adminProfile: adminProfile ? {
                    id: adminProfile._id,
                    email: adminProfile.email,
                    name: adminProfile.name,
                } : null,
            },
        };
    },
});
