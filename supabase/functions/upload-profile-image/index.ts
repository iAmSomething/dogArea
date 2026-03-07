import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { resolveEdgeAuthContext } from "../_shared/edge_auth.ts";
import { requireSupabaseRuntimeEnv } from "../_shared/edge_runtime.ts";
import { errorJson, json, methodNotAllowed, parseJsonBody } from "../_shared/http.ts";
import { asString } from "../_shared/parsers.ts";
import {
  resolveProfileImageObjectPath,
  uploadPublicStorageObject,
} from "../_shared/storage_upload.ts";

type RequestDTO = {
  ownerId?: string;
  imageBase64?: string;
  imageKind?: "user" | "pet";
  contentType?: "image/jpeg" | "image/png";
};

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

const sanitizeOwnerId = (value: string): string | null => {
  const trimmed = value.trim().toLowerCase();
  if (trimmed.length < 3 || trimmed.length > 128) return null;
  if (!/^[a-z0-9._-]+$/.test(trimmed)) return null;
  return trimmed;
};

const decodeBase64 = (raw: string): Uint8Array | null => {
  const normalized = raw.replace(/^data:.*;base64,/, "");
  try {
    const binary = atob(normalized);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  } catch {
    return null;
  }
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return methodNotAllowed();
  }

  const runtime = requireSupabaseRuntimeEnv({ serviceRole: true });
  if (!runtime.ok) return runtime.response;
  const { supabaseURL, supabaseAnonKey } = runtime.value;
  const supabaseServiceRoleKey = runtime.value.supabaseServiceRoleKey!;

  const auth = await resolveEdgeAuthContext({
    req,
    policy: {
      functionName: "upload-profile-image",
      kind: "member_or_anon",
    },
    supabaseURL,
    supabaseAnonKey,
    supabaseServiceRoleKey,
  });
  if (!auth.ok) {
    return auth.response;
  }

  const parsedBody = await parseJsonBody<RequestDTO>(req);
  if (!parsedBody.ok) return parsedBody.response;
  const body = parsedBody.body;

  const ownerIdRaw = asString(body.ownerId);
  if (!ownerIdRaw) {
    return errorJson("OWNER_ID_REQUIRED", 400);
  }
  const ownerId = sanitizeOwnerId(ownerIdRaw);
  if (!ownerId) {
    return errorJson("INVALID_OWNER_ID", 400);
  }

  const imageBase64 = asString(body.imageBase64);
  if (!imageBase64) {
    return errorJson("IMAGE_BASE64_REQUIRED", 400);
  }

  const imageBytes = decodeBase64(imageBase64);
  if (!imageBytes) {
    return errorJson("INVALID_IMAGE_BASE64", 400);
  }
  if (imageBytes.byteLength == 0 || imageBytes.byteLength > MAX_IMAGE_BYTES) {
    return errorJson("INVALID_IMAGE_SIZE", 400);
  }

  const imageKind = body.imageKind === "pet" ? "pet" : "user";
  const contentType = body.contentType === "image/png" ? "image/png" : "image/jpeg";
  const objectPath = resolveProfileImageObjectPath(ownerId, imageKind, contentType);

  const serviceClient = createClient(supabaseURL, supabaseServiceRoleKey);
  const storageResult = await uploadPublicStorageObject(serviceClient, {
    bucket: "profiles",
    path: objectPath,
    bytes: imageBytes,
    contentType,
    upsert: true,
  });

  if (!storageResult.ok) {
    return errorJson(storageResult.code, 500, { detail: storageResult.message });
  }

  return json({
    ok: true,
    bucket: storageResult.bucket,
    path: storageResult.path,
    publicUrl: storageResult.publicUrl,
  });
});
