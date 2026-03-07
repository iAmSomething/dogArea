import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";
import { resolveEdgeAuthContext } from "../_shared/edge_auth.ts";

type RequestDTO = {
  ownerId?: string;
  imageBase64?: string;
  imageKind?: "user" | "pet";
  contentType?: "image/jpeg" | "image/png";
};

const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const asString = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

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
    return json({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return json({ error: "SERVER_MISCONFIGURED" }, 500);
  }

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

  let body: RequestDTO;
  try {
    body = await req.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  const ownerIdRaw = asString(body.ownerId);
  if (!ownerIdRaw) {
    return json({ error: "OWNER_ID_REQUIRED" }, 400);
  }
  const ownerId = sanitizeOwnerId(ownerIdRaw);
  if (!ownerId) {
    return json({ error: "INVALID_OWNER_ID" }, 400);
  }

  const imageBase64 = asString(body.imageBase64);
  if (!imageBase64) {
    return json({ error: "IMAGE_BASE64_REQUIRED" }, 400);
  }

  const imageBytes = decodeBase64(imageBase64);
  if (!imageBytes) {
    return json({ error: "INVALID_IMAGE_BASE64" }, 400);
  }
  if (imageBytes.byteLength == 0 || imageBytes.byteLength > MAX_IMAGE_BYTES) {
    return json({ error: "INVALID_IMAGE_SIZE" }, 400);
  }

  const imageKind = body.imageKind === "pet" ? "pet" : "user";
  const contentType = body.contentType === "image/png" ? "image/png" : "image/jpeg";
  const fileExtension = contentType === "image/png" ? "png" : "jpeg";
  const fileName = imageKind === "pet" ? `petProfile.${fileExtension}` : `userProfile.${fileExtension}`;
  const objectPath = `${ownerId}/${fileName}`;

  const serviceClient = createClient(supabaseURL, supabaseServiceRoleKey);
  const upload = await serviceClient.storage
    .from("profiles")
    .upload(objectPath, imageBytes, {
      contentType,
      upsert: true,
    });

  if (upload.error) {
    return json({ error: "UPLOAD_FAILED", detail: upload.error.message }, 500);
  }

  const { data } = serviceClient.storage.from("profiles").getPublicUrl(objectPath);
  const publicUrl = data?.publicUrl;

  if (!publicUrl) {
    return json({ error: "PUBLIC_URL_FAILED" }, 500);
  }

  return json({
    ok: true,
    bucket: "profiles",
    path: objectPath,
    publicUrl,
  });
});
