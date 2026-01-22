import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

type AdminRole = "owner" | "admin";

export async function getAdminRole(ctx: any): Promise<AdminRole | null> {
const identity = await ctx.auth.getUserIdentity();
if (!identity) return null;

const admin = await ctx.db
.query("appAdmins")
.withIndex("by_userId", (q: any) => q.eq("userId", identity.subject))
.first();

return admin?.role ?? null;
}

export async function assertAdmin(ctx: any): Promise<AdminRole> {
const role = await getAdminRole(ctx);
if (!role) throw new Error("Admin access required");
return role;
}

export async function assertOwner(ctx: any): Promise<void> {
const role = await getAdminRole(ctx);
if (role !== "owner") throw new Error("Owner access required");
}

export const getAdminStatus = query({
args: {},
returns: v.object({
role: v.union(v.literal("owner"), v.literal("admin"), v.null()),
hasAnyAdmin: v.boolean(),
}),
handler: async (ctx) => {
const admins = await ctx.db.query("appAdmins").first();
const role = await getAdminRole(ctx);

return {
role,
hasAnyAdmin: !!admins,
};
},
});

export const bootstrapOwner = mutation({
args: {},
returns: v.object({ role: v.literal("owner") }),
handler: async (ctx) => {
const identity = await ctx.auth.getUserIdentity();
if (!identity) throw new Error("Not authenticated");

const existing = await ctx.db.query("appAdmins").first();
if (existing) throw new Error("An owner/admin is already configured");

await ctx.db.insert("appAdmins", {
userId: identity.subject,
role: "owner",
createdAt: Date.now(),
});

return { role: "owner" };
},
});

export const listAdmins = query({
args: {},
returns: v.array(
v.object({
id: v.id("appAdmins"),
userId: v.string(),
name: v.union(v.string(), v.null()),
role: v.union(v.literal("owner"), v.literal("admin")),
createdAt: v.number(),
})
),
handler: async (ctx) => {
await assertAdmin(ctx);
const admins = await ctx.db.query("appAdmins").order("desc").collect();

// Enrich with user details from profiles
const enrichedAdmins = await Promise.all(
admins.map(async (a: any) => {
const profile = await ctx.db
.query("profiles")
.withIndex("by_userId", (q: any) => q.eq("userId", a.userId))
.first();

return {
id: a._id,
userId: a.userId,
name: profile?.name ?? null,
role: a.role,
createdAt: a.createdAt,
};
})
);

return enrichedAdmins;
},
});

export const addAdmin = mutation({
args: {
userId: v.string(),
role: v.optional(v.union(v.literal("owner"), v.literal("admin"))),
},
returns: v.id("appAdmins"),
handler: async (ctx, args) => {
await assertOwner(ctx);

const role = args.role ?? "admin";

// Check if already an admin
const existing = await ctx.db
.query("appAdmins")
.withIndex("by_userId", (q: any) => q.eq("userId", args.userId))
.first();

if (existing) {
throw new Error("User is already an admin");
}

// Verify user exists by checking if they have a profile
const profile = await ctx.db
.query("profiles")
.withIndex("by_userId", (q: any) => q.eq("userId", args.userId))
.first();

if (!profile) {
throw new Error("User not found - they must have a profile first");
}

const adminId = await ctx.db.insert("appAdmins", {
userId: args.userId,
role,
createdAt: Date.now(),
});

return adminId;
},
});

export const removeAdmin = mutation({
args: { adminId: v.id("appAdmins") },
returns: v.null(),
handler: async (ctx, args) => {
await assertOwner(ctx);

const admin = await ctx.db.get(args.adminId);
if (!admin) throw new Error("Admin not found");

// Prevent removing the last owner
if (admin.role === "owner") {
const ownerCount = await ctx.db
.query("appAdmins")
.filter((q: any) => q.eq(q.field("role"), "owner"))
.collect();

if (ownerCount.length <= 1) {
throw new Error("Cannot remove the last owner");
}
}

await ctx.db.delete(args.adminId);
return null;
},
});

export const getAllUsers = query({
args: {},
returns: v.array(
v.object({
userId: v.string(),
name: v.string(),
role: v.union(v.literal("parent"), v.literal("helper")),
villageName: v.string(),
isAdmin: v.boolean(),
})
),
handler: async (ctx) => {
await assertAdmin(ctx);

const profiles = await ctx.db.query("profiles").collect();
const adminUserIds = new Set(
(await ctx.db.query("appAdmins").collect()).map((a: any) => a.userId)
);

const users = await Promise.all(
profiles.map(async (profile: any) => {
const village = await ctx.db.get(profile.villageId);
return {
userId: profile.userId,
name: profile.name,
role: profile.role,
villageName: village?.name ?? "Unknown",
isAdmin: adminUserIds.has(profile.userId),
};
})
);

return users;
},
});