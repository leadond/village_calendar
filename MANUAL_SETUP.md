# Apple Review Test Account - Manual Setup

## Step 1: Create Clerk User (Manual)

1. **Go to Clerk Dashboard:**
   - Visit: https://dashboard.clerk.com
   - Navigate to "Users" section

2. **Create New User:**
   - Click "Create User"
   - **Email:** `apple.reviewer@example.com`
   - **Password:** `AppleReview2024!`
   - **First Name:** `Apple`
   - **Last Name:** `Reviewer`
   - **Username:** `apple_reviewer`
   - ✅ **Mark email as verified** (important!)

## Step 2: Create Convex Profile

1. **Go to Convex Dashboard:**
   - Visit: https://shocking-lark-950.convex.cloud
   - Navigate to "Functions"

2. **Run Function:**
   - Find: `testUser:createAppleReviewUser`
   - Click "Run"
   - Leave all parameters empty (uses defaults)
   - Click "Run Function"

3. **Note the Village Code** from the response

## Step 3: Test Credentials

**For Apple Reviewers:**
- **Email:** `apple.reviewer@example.com`
- **Password:** `AppleReview2024!`
- **Village Code:** (from Step 2 response)

## Step 4: Test the App

1. Open Village Calendar app
2. Tap "Sign In"
3. Enter the credentials above
4. Should login directly without email verification!

## Features to Test

### Parent Features:
- Create help requests
- Set dates/times
- Track request status
- View claimed requests
- Delete requests

### Village Features:
- View member count
- Browse help requests
- See village code

### Profile:
- View account info
- Village details
- Sign out

---

**Note:** This bypasses normal 2FA for Apple's review process only.