# Apple App Store Review Test Account Setup

This document explains how to create a test user account for Apple's App Store review process without requiring 2FA/email verification.

## Quick Setup (Recommended)

### Option 1: Using the Admin Script

1. **Get your Clerk Secret Key:**
   - Go to [Clerk Dashboard](https://dashboard.clerk.com/last-active?path=api-keys)
   - Copy your Secret Key

2. **Install dependencies:**
   ```bash
   npm install node-fetch
   ```

3. **Run the setup script:**
   ```bash
   CLERK_SECRET_KEY=your_secret_key_here node create-test-user.js
   ```

4. **Test credentials will be:**
   - **Email:** `apple.reviewer@example.com`
   - **Password:** `AppleReview2024!`
   - **Village Code:** (generated automatically)

### Option 2: Using Convex Dashboard

1. **Go to your Convex Dashboard**
2. **Navigate to Functions**
3. **Run the mutation:** `testUser:createAppleReviewUser`
4. **Use default parameters** (leave empty for defaults)

## Test Account Details

- **Email:** apple.reviewer@example.com
- **Password:** AppleReview2024!
- **Name:** Apple Reviewer
- **Role:** Parent
- **Village:** Apple Review Village
- **No 2FA Required:** ✅

## For Apple Reviewers

1. **Download** the Village Calendar app
2. **Tap "Sign In"** on the login screen
3. **Enter credentials:**
   - Email: `apple.reviewer@example.com`
   - Password: `AppleReview2024!`
4. **Direct access** - no email verification needed!

## App Features to Test

### As a Parent:
- ✅ Create help requests (school pickup, babysitting, etc.)
- ✅ Set date and time for needed help
- ✅ Track status of your requests
- ✅ See who claimed your requests
- ✅ Delete unclaimed requests

### Village Features:
- ✅ View village member count
- ✅ See village code for inviting others
- ✅ Browse all help requests in the village

### Profile Features:
- ✅ View account information
- ✅ See village details
- ✅ Sign out functionality

## Troubleshooting

If the test account doesn't work:

1. **Check if user exists:**
   ```bash
   # Run this query in Convex dashboard
   testUser:getAppleReviewUserInfo
   ```

2. **Recreate the account:**
   ```bash
   CLERK_SECRET_KEY=your_key node create-test-user.js
   ```

3. **Manual Clerk setup:**
   - Go to Clerk Dashboard → Users
   - Create user with email `apple.reviewer@example.com`
   - Set password to `AppleReview2024!`
   - Mark email as verified

## Security Note

This test account is specifically created for Apple's review process and uses a fake email domain. It bypasses normal verification flows for review purposes only.