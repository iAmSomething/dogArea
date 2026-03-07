import {
  ensureAuthenticatedUserMatch,
  resolveEdgeAuthContext,
} from "../_shared/edge_auth.ts";
import { requireSupabaseRuntimeEnv } from "../_shared/edge_runtime.ts";
import { errorJson, json, methodNotAllowed, parseJsonBody } from "../_shared/http.ts";
import {
  asRecord,
  asString,
  toBoolean,
  toNullableInt,
  toUUIDOrNull,
} from "../_shared/parsers.ts";

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

const normalizeGender = (value: unknown): "unknown" | "male" | "female" => {
  const raw = asString(value)?.toLowerCase();
  if (raw === "male" || raw === "female") return raw;
  return "unknown";
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return methodNotAllowed();

  const runtime = requireSupabaseRuntimeEnv();
  if (!runtime.ok) return runtime.response;
  const { supabaseURL, supabaseAnonKey } = runtime.value;

  const auth = await resolveEdgeAuthContext({
    req,
    policy: {
      functionName: "sync-profile",
      kind: "member_required",
    },
    supabaseURL,
    supabaseAnonKey,
  });
  if (!auth.ok) {
    return auth.response;
  }
  const userClient = auth.context.userClient!;
  const userId = auth.context.userId!;

  const parsedBody = await parseJsonBody<RequestDTO>(req);
  if (!parsedBody.ok) return parsedBody.response;
  const body = parsedBody.body;

  const action = body.action;
  if (!action) return errorJson("ACTION_REQUIRED", 400);

  const requestedUserId = toUUIDOrNull(body.user_id);
  const userMismatchResponse = ensureAuthenticatedUserMatch(auth.context, requestedUserId);
  if (userMismatchResponse) {
    return userMismatchResponse;
  }

  if (action === "get_profile_snapshot") {
    const { data: profile, error: profileError } = await userClient
      .from("profiles")
      .select("id,display_name,profile_image_url,profile_message,updated_at")
      .eq("id", userId)
      .maybeSingle();
    if (profileError) return errorJson(profileError.message, 500);

    const { data: pets, error: petsError } = await userClient
      .from("pets")
      .select("id,owner_user_id,name,photo_url,breed,age_years,gender,is_active,updated_at")
      .eq("owner_user_id", userId)
      .order("created_at", { ascending: true });
    if (petsError) return errorJson(petsError.message, 500);

    return json({
      snapshot: {
        profile: profile ?? null,
        pets: pets ?? [],
      },
    });
  }

  if (action !== "sync_profile_stage") {
    return errorJson("UNSUPPORTED_ACTION", 400);
  }

  const stage = body.stage;
  const payload = asRecord(body.payload);
  const idempotencyKey = asString(body.idempotency_key) ?? null;

  if (!stage) {
    return errorJson("STAGE_REQUIRED", 400);
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

    if (error) return errorJson(error.message, 500);
    return json({ ok: true, stage, user_id: userId, idempotency_key: idempotencyKey });
  }

  if (stage === "pet") {
    const petId = toUUIDOrNull(body.pet_id ?? payload.pet_id ?? payload.id);
    if (!petId) return errorJson("INVALID_PET_ID", 400);

    const name = asString(payload.name);
    if (!name) return errorJson("PET_NAME_REQUIRED", 400);

    const ageYears = toNullableInt(payload.age_years);
    if (ageYears !== null && (ageYears < 0 || ageYears > 30)) {
      return errorJson("INVALID_AGE_RANGE", 400);
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

    if (error) return errorJson(error.message, 500);
    return json({ ok: true, stage, user_id: userId, pet_id: petId, idempotency_key: idempotencyKey });
  }

  return errorJson("UNSUPPORTED_STAGE", 400);
});
