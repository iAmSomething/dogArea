import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { resolveEdgeAuthContext } from "../_shared/edge_auth.ts";
import { dispatchNearbyPresenceAction, isSupportedNearbyPresenceAction } from "./handlers/action_dispatcher.ts";
import { json } from "./support/core.ts";
import type { RequestDTO } from "./support/types.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !supabaseAnonKey || !serviceRole) {
    return json({ error: "SERVER_MISCONFIGURED" }, 500);
  }

  const auth = await resolveEdgeAuthContext({
    req,
    policy: {
      functionName: "nearby-presence",
      kind: "member_or_anon",
    },
    supabaseURL,
    supabaseAnonKey,
    supabaseServiceRoleKey: serviceRole,
  });
  if (!auth.ok) {
    return auth.response;
  }

  const client = createClient(supabaseURL, serviceRole);

  let body: RequestDTO;
  try {
    body = await req.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  if (!isSupportedNearbyPresenceAction(body.action)) {
    return json({ error: body.action ? "UNSUPPORTED_ACTION" : "ACTION_REQUIRED" }, 400);
  }

  return dispatchNearbyPresenceAction(body.action, {
    client,
    body,
  });
});
