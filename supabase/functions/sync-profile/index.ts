import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type SyncStage = "profile" | "pet";
type Action = "sync_profile_stage" | "get_profile_snapshot";

type RequestDTO = {
  action?: Action;
  stage?: SyncStage;
  user_id?: string;
  pet_id?: string;
  idempotency_key?: string;
  payload?: Record<string, unknown>;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const asRecord = (value: unknown): Record<string, unknown> =>
  typeof value === "object" && value !== null ? value as Record<string, unknown> : {};

const asString = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const toBoolean = (value: unknown, fallback: boolean): boolean => {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (normalized === "true" || normalized === "1") return true;
    if (normalized === "false" || normalized === "0") return false;
  }
  return fallback;
};

const toNullableInt = (value: unknown): number | null => {
  if (value === null || value === undefined) return null;
  if (typeof value === "number" && Number.isInteger(value)) return value;
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed.length === 0) return null;
    const parsed = Number(trimmed);
    if (Number.isInteger(parsed)) return parsed;
  }
  return null;
};

const toUUIDOrNull = (value: unknown): string | null => {
  const raw = asString(value);
  if (!raw) return null;
  const normalized = raw.toLowerCase();
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
  return uuidPattern.test(normalized) ? normalized : null;
};

const normalizeGender = (value: unknown): "unknown" | "male" | "female" => {
  const raw = asString(value)?.toLowerCase();
  if (raw === "male" || raw === "female") return raw;
  return "unknown";
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseURL || !supabaseAnonKey) {
    return json({ error: "SERVER_MISCONFIGURED" }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "UNAUTHORIZED" }, 401);
  }
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) return json({ error: "UNAUTHORIZED" }, 401);

  const userClient = createClient(supabaseURL, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userResult, error: userError } = await userClient.auth.getUser(token);
  if (userError || !userResult?.user) {
    return json({ error: "UNAUTHORIZED" }, 401);
  }
  const userId = userResult.user.id;

  let body: RequestDTO;
  try {
    body = await req.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  const action = body.action;
  if (!action) return json({ error: "ACTION_REQUIRED" }, 400);

  const requestedUserId = toUUIDOrNull(body.user_id);
  if (requestedUserId && requestedUserId !== userId) {
    return json({ error: "UNAUTHORIZED_USER_MISMATCH" }, 403);
  }

  if (action === "get_profile_snapshot") {
    const { data: profile, error: profileError } = await userClient
      .from("profiles")
      .select("id,display_name,profile_image_url,profile_message,updated_at")
      .eq("id", userId)
      .maybeSingle();
    if (profileError) return json({ error: profileError.message }, 500);

    const { data: pets, error: petsError } = await userClient
      .from("pets")
      .select("id,owner_user_id,name,photo_url,breed,age_years,gender,is_active,updated_at")
      .eq("owner_user_id", userId)
      .order("created_at", { ascending: true });
    if (petsError) return json({ error: petsError.message }, 500);

    return json({
      snapshot: {
        profile: profile ?? null,
        pets: pets ?? [],
      },
    });
  }

  if (action !== "sync_profile_stage") {
    return json({ error: "UNSUPPORTED_ACTION" }, 400);
  }

  const stage = body.stage;
  const payload = asRecord(body.payload);
  const idempotencyKey = asString(body.idempotency_key) ?? null;

  if (!stage) {
    return json({ error: "STAGE_REQUIRED" }, 400);
  }

  if (stage === "profile") {
    const displayName = asString(payload.display_name) ?? "";
    const profileImageURL = asString(payload.profile_image_url);
    const profileMessage = asString(payload.profile_message);

    const { error } = await userClient
      .from("profiles")
      .upsert({
        id: userId,
        display_name: displayName,
        profile_image_url: profileImageURL,
        profile_message: profileMessage,
        updated_at: new Date().toISOString(),
      }, { onConflict: "id" });

    if (error) return json({ error: error.message }, 500);
    return json({ ok: true, stage, user_id: userId, idempotency_key: idempotencyKey });
  }

  if (stage === "pet") {
    const petId = toUUIDOrNull(body.pet_id ?? payload.pet_id ?? payload.id);
    if (!petId) return json({ error: "INVALID_PET_ID" }, 400);

    const name = asString(payload.name);
    if (!name) return json({ error: "PET_NAME_REQUIRED" }, 400);

    const ageYears = toNullableInt(payload.age_years);
    if (ageYears !== null && (ageYears < 0 || ageYears > 30)) {
      return json({ error: "INVALID_AGE_RANGE" }, 400);
    }

    const { error } = await userClient
      .from("pets")
      .upsert({
        id: petId,
        owner_user_id: userId,
        name,
        photo_url: asString(payload.photo_url),
        breed: asString(payload.breed),
        age_years: ageYears,
        gender: normalizeGender(payload.gender),
        is_active: toBoolean(payload.is_active, true),
        updated_at: new Date().toISOString(),
      }, { onConflict: "id" });

    if (error) return json({ error: error.message }, 500);
    return json({ ok: true, stage, user_id: userId, pet_id: petId, idempotency_key: idempotencyKey });
  }

  return json({ error: "UNSUPPORTED_STAGE" }, 400);
});
