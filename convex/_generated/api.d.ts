/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as admin from "../admin.js";
import type * as adminAuth from "../adminAuth.js";
import type * as cleanup from "../cleanup.js";
import type * as events from "../events.js";
import type * as helpRequests from "../helpRequests.js";
import type * as invites from "../invites.js";
import type * as messages from "../messages.js";
import type * as profiles from "../profiles.js";
import type * as setup from "../setup.js";
import type * as syncProfile from "../syncProfile.js";
import type * as testUser from "../testUser.js";
import type * as villages from "../villages.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  admin: typeof admin;
  adminAuth: typeof adminAuth;
  cleanup: typeof cleanup;
  events: typeof events;
  helpRequests: typeof helpRequests;
  invites: typeof invites;
  messages: typeof messages;
  profiles: typeof profiles;
  setup: typeof setup;
  syncProfile: typeof syncProfile;
  testUser: typeof testUser;
  villages: typeof villages;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
