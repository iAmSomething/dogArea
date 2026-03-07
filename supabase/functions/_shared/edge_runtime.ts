import { errorJson } from "./http.ts";

export type SupabaseRuntimeEnv = {
  supabaseURL: string;
  supabaseAnonKey: string;
  supabaseServiceRoleKey?: string;
};

type RequireSupabaseRuntimeEnvOptions = {
  serviceRole?: boolean;
};

export function requireSupabaseRuntimeEnv(
  options: RequireSupabaseRuntimeEnvOptions = {},
):
  | { ok: true; value: SupabaseRuntimeEnv }
  | { ok: false; response: Response } {
  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseURL || !supabaseAnonKey || (options.serviceRole && !supabaseServiceRoleKey)) {
    return { ok: false, response: errorJson("SERVER_MISCONFIGURED", 500) };
  }

  return {
    ok: true,
    value: {
      supabaseURL,
      supabaseAnonKey,
      supabaseServiceRoleKey: options.serviceRole ? supabaseServiceRoleKey! : undefined,
    },
  };
}
