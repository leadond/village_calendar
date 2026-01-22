import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

function generateInviteCode(): string {
const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
let code = "";
for (let i = 0; i < 8; i++) {
code += chars.charAt(Math.floor(Math.random() * chars.length));
}
return code;
}

export const createInvite = mutation({
args: { villageId: v.id("villages") },
returns: v.object({
code: v.string(),
villageName: v.string(),
}),
handler: async (ctx, args) => {
const identity = await ctx.auth.getUserIdentity();
if (!identity) throw new Error("Not authenticated");

const profile = await ctx.db
.query("profiles")
.withIndex("by_userId", (q: any) => q.eq("userId", identity.subject))
.first();

if (!profile) throw new Error("Profile not found");
if (profile.villageId !== args.villageId) throw new Error("Not a member of this village");

const village = await ctx.db.get(args.villageId);
if (!village) throw new Error("Village not found");

// Generate unique invite code
let code = generateInviteCode();
let existing = await ctx.db
.query("invites")
.withIndex("by_code", (q: any) => q.eq("code", code))
.first();

while (existing) {
code = generateInviteCode();
existing = await ctx.db
.query("invites")
.withIndex("by_code", (q: any) => q.eq("code", code))
.first();
}

await ctx.db.insert("invites", {
code,
villageId: args.villageId,
createdBy: identity.subject,
createdAt: Date.now(),
});

return { code, villageName: village.name };
},
});

export const getInvitePreview = query({
args: { code: v.string() },
returns: v.union(
v.null(),
v.object({
villageId: v.id("villages"),
villageName: v.string(),
})
),
handler: async (ctx, args) => {
const code = args.code.trim().toUpperCase();

const invite = await ctx.db
.query("invites")
.withIndex("by_code", (q: any) => q.eq("code", code))
.first();

if (!invite || invite.revokedAt) return null;

const village = await ctx.db.get(invite.villageId);
if (!village) return null;

return { villageId: invite.villageId, villageName: village.name };
},
});

export const revokeInvite = mutation({
args: { code: v.string() },
returns: v.null(),
handler: async (ctx, args) => {
const identity = await ctx.auth.getUserIdentity();
if (!identity) throw new Error("Not authenticated");

const code = args.code.trim().toUpperCase();
const invite = await ctx.db
.query("invites")
.withIndex("by_code", (q: any) => q.eq("code", code))
.first();

if (!invite) throw new Error("Invite not found");

// Only creator or app admin can revoke (simple: creator)
if (invite.createdBy !== identity.subject) throw new Error("Not allowed");

await ctx.db.patch(invite._id, { revokedAt: Date.now() });
return null;
},
});
