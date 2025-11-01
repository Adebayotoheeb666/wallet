import type { RequestHandler } from "express";

/**
 * This endpoint serves public environment variables to the client.
 * IMPORTANT: Only expose ANON keys and public configuration here.
 * NEVER expose SERVICE_ROLE_KEY, CRON_API_KEY, or any other server-only secrets.
 */
export const handleEnvJs: RequestHandler = (_req, res) => {
  const publicEnv: Record<string, string | undefined> = {
    // Only expose the anon key, never the service role key
    VITE_SUPABASE_URL:
      process.env.VITE_SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL,
    VITE_SUPABASE_ANON_KEY:
      process.env.VITE_SUPABASE_ANON_KEY ||
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  };

  // Explicitly remove all server-side secrets before sending to client
  delete (publicEnv as any).NEXT_SUPABASE_SERVICE_ROLE_KEY;
  delete (publicEnv as any).SUPABASE_SERVICE_ROLE_KEY;
  delete (publicEnv as any).CRON_API_KEY;

  res.setHeader("Content-Type", "application/javascript; charset=utf-8");
  res.setHeader(
    "Cache-Control",
    "no-store, no-cache, must-revalidate, private",
  );

  const payload = `window.__env__ = Object.assign(window.__env__ || {}, ${JSON.stringify(
    publicEnv,
  )});`;

  res.status(200).send(payload);
};
