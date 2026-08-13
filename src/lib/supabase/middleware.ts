import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Protected routes — redirect to landing if not signed in
  const protectedPaths = [
    "/onboarding",
    "/requests",
    "/kids",
    "/village",
    "/messages",
    "/calendar",
    "/profile",
    "/emergency",
    "/admin",
  ];

  const isProtected = protectedPaths.some((p) =>
    request.nextUrl.pathname.startsWith(p)
  );

  if (isProtected && !user) {
    const url = request.nextUrl.clone();
    url.pathname = "/";
    return NextResponse.redirect(url);
  }

  // If signed in and on landing or auth, redirect to onboarding or app
  if (user && (request.nextUrl.pathname === "/" || request.nextUrl.pathname === "/auth")) {
    // Check if user has a profile with a village
    const { data: profile } = await supabase
      .from("profiles")
      .select("current_village_id, village_id")
      .eq("id", user.id)
      .maybeSingle();

    const hasVillage =
      (profile?.current_village_id || profile?.village_id) ? true : false;

    if (!profile) {
      const url = request.nextUrl.clone();
      url.pathname = "/onboarding";
      return NextResponse.redirect(url);
    }

    if (!hasVillage) {
      const url = request.nextUrl.clone();
      url.pathname = "/onboarding";
      return NextResponse.redirect(url);
    }

    const url = request.nextUrl.clone();
    url.pathname = "/requests";
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}
