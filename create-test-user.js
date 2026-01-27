#!/usr/bin/env node

/**
 * Script to create a test user for Apple App Store review
 * This creates a real Clerk user account without email verification
 * 
 * Prerequisites:
 * 1. Set CLERK_SECRET_KEY environment variable
 * 2. Run: npm install node-fetch
 * 3. Run: node create-test-user.js
 */

const fetch = require('node-fetch');
const { ConvexHttpClient } = require("convex/browser");

// Configuration
const CLERK_SECRET_KEY = process.env.CLERK_SECRET_KEY;
const CONVEX_URL = process.env.CONVEX_URL || "https://shocking-lark-950.convex.cloud";

const TEST_USER = {
  email: "apple.reviewer@example.com",
  password: "AppleReview2024!",
  firstName: "Apple",
  lastName: "Reviewer",
  username: "apple_reviewer"
};

async function createClerkUser() {
  if (!CLERK_SECRET_KEY) {
    console.error("❌ CLERK_SECRET_KEY environment variable is required");
    console.log("Get it from: https://dashboard.clerk.com/last-active?path=api-keys");
    process.exit(1);
  }

  try {
    console.log("🔐 Creating Clerk user account...");
    
    const response = await fetch('https://api.clerk.com/v1/users', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${CLERK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email_address: [TEST_USER.email],
        password: TEST_USER.password,
        first_name: TEST_USER.firstName,
        last_name: TEST_USER.lastName,
        username: TEST_USER.username,
        skip_password_checks: true,
        skip_password_requirement: false,
        // Skip email verification for Apple review
        verify: false
      })
    });

    const userData = await response.json();
    
    if (!response.ok) {
      if (userData.errors?.[0]?.code === 'form_identifier_exists') {
        console.log("✅ User already exists in Clerk");
        return userData;
      }
      throw new Error(`Clerk API error: ${JSON.stringify(userData)}`);
    }

    console.log("✅ Clerk user created successfully!");
    return userData;
    
  } catch (error) {
    console.error("❌ Failed to create Clerk user:", error.message);
    throw error;
  }
}

async function createConvexProfile(clerkUserId) {
  try {
    console.log("📊 Creating Convex profile...");
    
    const client = new ConvexHttpClient(CONVEX_URL);
    
    const result = await client.mutation("testUser:createAppleReviewUser", {
      email: TEST_USER.email,
      name: `${TEST_USER.firstName} ${TEST_USER.lastName}`,
      role: "parent",
      villageName: "Apple Review Village"
    });
    
    console.log("✅ Convex profile created successfully!");
    return result;
    
  } catch (error) {
    console.error("❌ Failed to create Convex profile:", error.message);
    throw error;
  }
}

async function main() {
  try {
    console.log("🍎 Creating Apple Review Test Account...");
    console.log("========================================\n");
    
    // Create Clerk user
    const clerkUser = await createClerkUser();
    
    // Create Convex profile
    const convexProfile = await createConvexProfile(clerkUser.id);
    
    console.log("\n🎉 SUCCESS! Test account created for Apple review:");
    console.log("================================================");
    console.log(`📧 Email: ${TEST_USER.email}`);
    console.log(`🔑 Password: ${TEST_USER.password}`);
    console.log(`👤 Name: ${TEST_USER.firstName} ${TEST_USER.lastName}`);
    console.log(`🏘️ Village: ${convexProfile.testCredentials.villageName}`);
    console.log(`🔢 Village Code: ${convexProfile.villageCode}`);
    console.log("\n📝 Instructions for Apple reviewers:");
    console.log("1. Download the Village Calendar app");
    console.log("2. Tap 'Sign In' on the login screen");
    console.log(`3. Enter email: ${TEST_USER.email}`);
    console.log(`4. Enter password: ${TEST_USER.password}`);
    console.log("5. No email verification required - direct access!");
    
  } catch (error) {
    console.error("\n❌ Failed to create test account:", error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}