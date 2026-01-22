# The Village Calendar

A mobile app for community childcare coordination. Parents post help requests, helpers volunteer to assist.

## Features

### For Parents
- Create help requests (school pickup, babysitting, etc.)
- Set date and time for needed help
- Track status of your requests
- See who claimed your requests
- Delete unclaimed requests

### For Helpers
- Browse open help requests in your village
- Claim requests with one tap
- View and manage your commitments
- Unclaim if you can no longer help

### Villages
- Create a new village and get a 6-digit code
- Share your village code to invite others
- Join existing villages with a code
- See village member counts

## Tech Stack

- **Frontend**: React Native (Expo SDK 54)
- **Backend**: Convex (real-time database)
- **Auth**: Convex Auth (email/password)
- **UI**: Custom components with theme system

## Screens

1. **Login/Signup** - Email and password authentication
2. **Onboarding** - Name, role (parent/helper), and village setup
3. **Home** - View all help requests in your village
4. **My Items** - Your requests (parents) or commitments (helpers)
5. **Profile** - Account info, village code, and sign out
6. **Create Request** - Post a new help request (parents only)

## Color Palette

- Primary: `#60B2B0` (Soft teal)
- Background: `#E0F4F4` (Light teal)
- Accent: `#F08080` (Soft coral)
- Success/Claimed: `#4CAF50` (Green)

## Getting Started

1. Click **Deploy** to publish the app
2. Create an account with email and password
3. Complete onboarding:
   - Enter your name
   - Select your role (Parent or Helper)
   - Create a new village OR join with a code
4. Start using the app!

## Future Enhancements

- Push notifications when requests are claimed
- Calendar integration with Nylas API
- In-app messaging between parents and helpers
- Recurring help requests
- Village admin roles