import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type ProviderName = "gemini" | "openai";
type ProviderHint = "auto" | ProviderName;
type Style = "cute_cartoon" | "line_illustration" | "watercolor";
type ErrorCode =
  | "METHOD_NOT_ALLOWED"
  | "UNAUTHORIZED"
  | "INVALID_REQUEST"
  | "SOURCE_IMAGE_NOT_FOUND"
  | "ALL_PROVIDERS_FAILED"
  | "STORAGE_UPLOAD_FAILED"
  | "DB_UPDATE_FAILED"
  | "SERVER_MISCONFIGURED";

type RequestDTO = {
  version?: string;
  petId: string;
  userId?: string;
  sourceImagePath?: string;
  sourceImageUrl?: string;
  style?: Style;
  providerHint?: ProviderHint;
  requestId?: string;
};

type JobInsertDTO = {
  user_id: string;
  pet_id: string;
  style: Style;
  provider_chain: string;
  status: "queued" | "processing" | "ready" | "failed";
  retry_count: number;
  request_id?: string;
  schema_version?: string;
  source_type?: "path" | "url";
  error_code?: string | null;
  provider_used?: string | null;
  fallback_used?: boolean;
  latency_ms?: number | null;
  error_message?: string | null;
};

const SCHEMA_VERSION = "2026-02-26.v1";
const TIMEOUT_MS = 25_000;
const MAX_RETRY = 2;
const SUPPORTED_STYLES = new Set<Style>([
  "cute_cartoon",
  "line_illustration",
  "watercolor",
]);

const json = (
  body: {
    errorCode?: ErrorCode;
    message?: string;
    [key: string]: unknown;
  },
  status = 200,
) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const withTimeout = async <T>(work: Promise<T>, timeoutMs: number): Promise<T> => {
  const timeout = new Promise<never>((_, reject) => {
    const id = setTimeout(() => {
      clearTimeout(id);
      reject(new Error("timeout"));
    }, timeoutMs);
  });
  return await Promise.race([work, timeout]);
};

const bytesToBase64 = (bytes: Uint8Array): string => {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
};

const base64ToBytes = (base64: string): Uint8Array => {
  const normalized = base64.replace(/^data:.*;base64,/, "");
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
};

const stylePrompt = (style: Style) => {
  switch (style) {
    case "line_illustration":
      return "Turn this dog photo into a clean square line illustration profile image.";
    case "watercolor":
      return "Turn this dog photo into a soft square watercolor portrait profile image.";
    default:
      return "Turn this dog photo into a cute square cartoon profile image.";
  }
};

const providerOrder = (hint: ProviderHint): ProviderName[] => {
  if (hint === "gemini") return ["gemini", "openai"];
  if (hint === "openai") return ["openai", "gemini"];
  return ["gemini", "openai"];
};

const asString = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const toUUID = (value: unknown): string | null => {
  const raw = asString(value);
  if (!raw) return null;
  const normalized = raw.toLowerCase();
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
  return uuidPattern.test(normalized) ? normalized : null;
};

const compactMessage = (raw: unknown, maxLen = 400): string => {
  const text = typeof raw === "string" ? raw : String(raw);
  return text.length <= maxLen ? text : text.slice(0, maxLen);
};

const callGemini = async (
  sourceImage: Uint8Array,
  style: Style,
): Promise<Uint8Array> => {
  const key = Deno.env.get("GEMINI_API_KEY") ?? Deno.env.get("GEMINI_KEY");
  if (!key) throw new Error("gemini key missing");
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp-image-generation:generateContent?key=${key}`;
  const payload = {
    contents: [
      {
        parts: [
          { text: stylePrompt(style) },
          {
            inline_data: {
              mime_type: "image/jpeg",
              data: bytesToBase64(sourceImage),
            },
          },
        ],
      },
    ],
    generationConfig: {
      responseModalities: ["TEXT", "IMAGE"],
    },
  };

  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new Error(`gemini failed: ${response.status}`);
  }
  const data = await response.json();
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  const imagePart = parts.find((part: Record<string, unknown>) =>
    typeof (part?.inlineData as Record<string, unknown>)?.data === "string" ||
    typeof (part?.inline_data as Record<string, unknown>)?.data === "string"
  );
  const encoded = imagePart?.inlineData?.data ?? imagePart?.inline_data?.data;
  if (!encoded || typeof encoded !== "string") {
    throw new Error("gemini did not return image data");
  }
  return base64ToBytes(encoded);
};

const callOpenAI = async (
  sourceImage: Uint8Array,
  style: Style,
): Promise<Uint8Array> => {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) throw new Error("openai key missing");

  const body = new FormData();
  body.append("model", "gpt-image-1");
  body.append("prompt", stylePrompt(style));
  body.append("image", new Blob([sourceImage], { type: "image/jpeg" }), "source.jpg");

  const response = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
    },
    body,
  });
  if (!response.ok) {
    throw new Error(`openai failed: ${response.status}`);
  }
  const data = await response.json();
  const encoded = data?.data?.[0]?.b64_json;
  if (!encoded || typeof encoded !== "string") {
    throw new Error("openai did not return image data");
  }
  return base64ToBytes(encoded);
};

const runProvider = async (
  provider: ProviderName,
  sourceImage: Uint8Array,
  style: Style,
): Promise<Uint8Array> => {
  if (provider === "gemini") {
    return await callGemini(sourceImage, style);
  }
  return await callOpenAI(sourceImage, style);
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ errorCode: "METHOD_NOT_ALLOWED", message: "POST only" }, 405);
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return json({ errorCode: "SERVER_MISCONFIGURED", message: "missing supabase env" }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ errorCode: "UNAUTHORIZED", message: "authorization header required" }, 401);
  }
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) {
    return json({ errorCode: "UNAUTHORIZED", message: "empty bearer token" }, 401);
  }

  const userClient = createClient(supabaseURL, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const serviceClient = createClient(supabaseURL, supabaseServiceRoleKey);

  let body: RequestDTO;
  try {
    body = await req.json();
  } catch {
    return json({ errorCode: "INVALID_REQUEST", message: "invalid json" }, 400);
  }

  const requestVersion = body.version ?? SCHEMA_VERSION;
  const requestId = body.requestId ?? crypto.randomUUID();
  const petId = toUUID(body.petId);
  if (!petId) {
    return json({
      errorCode: "INVALID_REQUEST",
      message: "petId must be UUID",
      version: requestVersion,
      requestId,
    }, 400);
  }
  if (!body.sourceImagePath && !body.sourceImageUrl) {
    return json({
      errorCode: "INVALID_REQUEST",
      message: "sourceImagePath or sourceImageUrl is required",
      version: requestVersion,
      requestId,
    }, 400);
  }

  const style: Style = SUPPORTED_STYLES.has(body.style as Style)
    ? body.style as Style
    : "cute_cartoon";
  const providerHint: ProviderHint = ["gemini", "openai"].includes(body.providerHint ?? "")
    ? body.providerHint as ProviderHint
    : "auto";
  const chain = providerOrder(providerHint);

  let authenticatedUserId: string | null = null;
  try {
    const { data: userResult } = await userClient.auth.getUser(token);
    authenticatedUserId = userResult?.user?.id ?? null;
  } catch {
    authenticatedUserId = null;
  }

  const payloadUserId = toUUID(body.userId);
  const resolvedUserId = authenticatedUserId ?? payloadUserId ?? petId;
  const sourceType: "path" | "url" = body.sourceImageUrl ? "url" : "path";

  const patchPetStatus = async (
    patch: Record<string, unknown>,
  ) => {
    let query = serviceClient
      .from("pets")
      .update({
        ...patch,
        updated_at: new Date().toISOString(),
      })
      .eq("id", petId);
    if (authenticatedUserId) {
      query = query.eq("owner_user_id", authenticatedUserId);
    }
    await query;
  };

  const jobBase: JobInsertDTO = {
    user_id: resolvedUserId,
    pet_id: petId,
    style,
    provider_chain: chain.join(">"),
    status: "queued",
    retry_count: 0,
    request_id: requestId,
    schema_version: requestVersion,
    source_type: sourceType,
    error_code: null,
    provider_used: null,
    fallback_used: false,
    latency_ms: null,
    error_message: null,
  };

  let jobId: string | null = null;
  let extendedJobColumnsEnabled = true;

  const createJobWithPayload = async (payload: Record<string, unknown>) => {
    return await serviceClient
      .from("caricature_jobs")
      .insert(payload)
      .select("id")
      .single();
  };

  let jobResult = await createJobWithPayload(jobBase as unknown as Record<string, unknown>);
  if (jobResult.error || !jobResult.data?.id) {
    extendedJobColumnsEnabled = false;
    const fallbackResult = await createJobWithPayload({
      user_id: resolvedUserId,
      pet_id: petId,
      style,
      provider_chain: chain.join(">"),
      status: "queued",
      retry_count: 0,
    });
    jobResult = fallbackResult;
  }

  if (jobResult.error || !jobResult.data?.id) {
    return json({
      errorCode: "DB_UPDATE_FAILED",
      message: "failed to create caricature job",
      version: requestVersion,
      requestId,
    }, 500);
  }
  jobId = jobResult.data.id as string;

  const updateJob = async (patch: Record<string, unknown>) => {
    const commonPatch = {
      ...patch,
      updated_at: new Date().toISOString(),
    };
    let candidate = commonPatch;
    if (!extendedJobColumnsEnabled) {
      candidate = {
        status: commonPatch.status,
        retry_count: commonPatch.retry_count,
        error_message: commonPatch.error_message,
        provider_chain: commonPatch.provider_chain,
        updated_at: commonPatch.updated_at,
      };
    }
    await serviceClient
      .from("caricature_jobs")
      .update(candidate)
      .eq("id", jobId);
  };

  await patchPetStatus({
    caricature_status: "processing",
    caricature_style: style,
  });
  await updateJob({ status: "processing" });

  const startedAt = Date.now();
  let sourceImage: Uint8Array;
  try {
    if (body.sourceImageUrl) {
      const fetched = await fetch(body.sourceImageUrl);
      if (!fetched.ok) throw new Error(`sourceImageUrl fetch failed: ${fetched.status}`);
      sourceImage = new Uint8Array(await fetched.arrayBuffer());
    } else {
      const { data: imageBlob, error } = await serviceClient
        .storage
        .from("profiles")
        .download(body.sourceImagePath!);
      if (error || !imageBlob) throw new Error("source image download failed");
      sourceImage = new Uint8Array(await imageBlob.arrayBuffer());
    }
  } catch (error) {
    await updateJob({
      status: "failed",
      error_code: "source_image_not_found",
      error_message: compactMessage(error),
      completed_at: new Date().toISOString(),
      latency_ms: Date.now() - startedAt,
    });
    await patchPetStatus({ caricature_status: "failed" });
    return json({
      errorCode: "SOURCE_IMAGE_NOT_FOUND",
      message: "source image is unavailable",
      version: requestVersion,
      requestId,
      jobId,
    }, 404);
  }

  let generatedImage: Uint8Array | null = null;
  let usedProvider: ProviderName | null = null;
  let failureMessage = "ALL_PROVIDERS_FAILED";
  let failureCode: ErrorCode = "ALL_PROVIDERS_FAILED";
  let attemptCount = 0;

  for (const provider of chain) {
    for (let attempt = 1; attempt <= MAX_RETRY; attempt += 1) {
      attemptCount += 1;
      try {
        generatedImage = await withTimeout(
          runProvider(provider, sourceImage, style),
          TIMEOUT_MS,
        );
        usedProvider = provider;
        break;
      } catch (error) {
        failureMessage = compactMessage(`${provider}#${attempt}:${String(error)}`);
        failureCode = "ALL_PROVIDERS_FAILED";
      }
    }
    if (generatedImage && usedProvider) break;
  }

  if (!generatedImage || !usedProvider) {
    await updateJob({
      status: "failed",
      error_code: failureCode.toLowerCase(),
      error_message: failureMessage,
      retry_count: attemptCount,
      completed_at: new Date().toISOString(),
      latency_ms: Date.now() - startedAt,
      fallback_used: false,
      provider_used: null,
    });
    await patchPetStatus({ caricature_status: "failed" });
    return json({
      errorCode: "ALL_PROVIDERS_FAILED",
      message: failureMessage,
      version: requestVersion,
      requestId,
      jobId,
    }, 502);
  }

  const caricaturePath = `${resolvedUserId}/${petId}/${jobId}.png`;
  const upload = await serviceClient.storage.from("caricatures").upload(
    caricaturePath,
    generatedImage,
    { contentType: "image/png", upsert: true },
  );
  if (upload.error) {
    await updateJob({
      status: "failed",
      error_code: "storage_upload_failed",
      error_message: compactMessage(upload.error.message),
      retry_count: attemptCount,
      completed_at: new Date().toISOString(),
      latency_ms: Date.now() - startedAt,
      provider_used: usedProvider,
      fallback_used: usedProvider !== chain[0],
    });
    await patchPetStatus({ caricature_status: "failed" });
    return json({
      errorCode: "STORAGE_UPLOAD_FAILED",
      message: "failed to upload caricature image",
      version: requestVersion,
      requestId,
      jobId,
    }, 500);
  }

  const { data: publicData } = serviceClient.storage.from("caricatures").getPublicUrl(caricaturePath);
  const caricatureUrl = publicData.publicUrl;

  await patchPetStatus({
    caricature_url: caricatureUrl,
    caricature_status: "ready",
    caricature_provider: usedProvider,
    caricature_style: style,
  });
  await updateJob({
    status: "ready",
    provider_chain: chain.join(">"),
    provider_used: usedProvider,
    fallback_used: usedProvider !== chain[0],
    retry_count: attemptCount,
    error_code: null,
    error_message: null,
    completed_at: new Date().toISOString(),
    latency_ms: Date.now() - startedAt,
  });

  return json({
    version: requestVersion,
    requestId,
    jobId,
    petId,
    status: "ready",
    provider: usedProvider,
    fallbackUsed: usedProvider !== chain[0],
    caricaturePath,
    caricatureUrl,
  });
});
