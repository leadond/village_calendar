import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const setupTestAccount = mutation({
  args: {},
  handler: async (ctx) => {
    // Create test village
    const villageId = await ctx.db.insert("villages", {
      name: "App Review Test Village",
      code: "REVIEW01",
      createdBy: "test-user-id",
    });

    // Create test profile
    const profileId = await ctx.db.insert("profiles", {
      userId: "test-user-id", 
      email: "reviewer@villagecalendar.app",
      name: "App Reviewer",
      role: "parent",
      villageId: villageId,
    });

    return { villageId, profileId };
  },
});