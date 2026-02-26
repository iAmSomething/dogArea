import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type ProviderName = "gemini" | "openai";
type ProviderHint = "auto" | ProviderName;
type Style = "cute_cartoon" | "line_illustration" | "watercolor";

type RequestDTO = {
  petId: string;
  sourceImagePath?: string;
  sourceImageUrl?: string;
  style?: Style;
  providerHint?: ProviderHint;
  requestId?: string;
};

const TIMEOUT_MS = 25_000;
const MAX_RETRY = 2;
const SUPPORTED_STYLES = new Set<Style>([
  "cute_cartoon",
  "line_illustration",
  "watercolor",
]);

const json = (body: unknown, status = 200) =>
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
      return "Turn this dog photo into a clean line illustration profile image.";
    case "watercolor":
      return "Turn this dog photo into a soft watercolor portrait profile image.";
    default:
      return "Turn this dog photo into a cute cartoon profile image.";
  }
};

const providerOrder = (hint: ProviderHint): ProviderName[] => {
  if (hint === "gemini") return ["gemini", "openai"];
  if (hint === "openai") return ["openai", "gemini"];
  return ["gemini", "openai"];
};

const callGemini = async (
  sourceImage: Uint8Array,
  style: Style,
): Promise<Uint8Array> => {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new Error("gemini key missing");
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${key}`;
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
  if (req.method !== "POST") return json({ errorCode: "METHOD_NOT_ALLOWED" }, 405);

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return json({ errorCode: "SERVER_MISCONFIGURED" }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ errorCode: "UNAUTHORIZED" }, 401);
  }
  const token = authHeader.replace("Bearer ", "").trim();

  const userClient = createClient(supabaseURL, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const serviceClient = createClient(supabaseURL, supabaseServiceRoleKey);

  const { data: userResult, error: userError } = await userClient.auth.getUser();
  if (userError || !userResult?.user) {
    return json({ errorCode: "UNAUTHORIZED" }, 401);
  }
  const user = userResult.user;

  let body: RequestDTO;
  try {
    body = await req.json();
  } catch {
    return json({ errorCode: "INVALID_REQUEST", message: "invalid json" }, 400);
  }

  if (!body?.petId) {
    return json({ errorCode: "INVALID_REQUEST", message: "petId is required" }, 400);
  }
  if (!body.sourceImagePath && !body.sourceImageUrl) {
    return json(
      { errorCode: "INVALID_REQUEST", message: "sourceImagePath or sourceImageUrl is required" },
      400,
    );
  }

  const style: Style = SUPPORTED_STYLES.has(body.style as Style)
    ? body.style as Style
    : "cute_cartoon";
  const providerHint: ProviderHint = ["gemini", "openai"].includes(body.providerHint ?? "")
    ? body.providerHint as ProviderHint
    : "auto";
  const chain = providerOrder(providerHint);
  const requestId = body.requestId ?? crypto.randomUUID();

  const { data: job, error: jobError } = await serviceClient
    .from("caricature_jobs")
    .insert({
      user_id: user.id,
      pet_id: body.petId,
      style,
      provider_chain: chain.join(">"),
      status: "queued",
      retry_count: 0,
    })
    .select("id")
    .single();

  if (jobError || !job?.id) {
    return json({ errorCode: "DB_UPDATE_FAILED", message: "failed to create job" }, 500);
  }
  const jobId = job.id as string;

  await serviceClient
    .from("pets")
    .update({
      caricature_status: "processing",
      caricature_style: style,
      updated_at: new Date().toISOString(),
    })
    .eq("id", body.petId)
    .eq("owner_user_id", user.id);
  await serviceClient
    .from("caricature_jobs")
    .update({ status: "processing", updated_at: new Date().toISOString() })
    .eq("id", jobId);

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
    await serviceClient.from("caricature_jobs").update({
      status: "failed",
      error_message: String(error),
      updated_at: new Date().toISOString(),
    }).eq("id", jobId);
    await serviceClient.from("pets").update({
      caricature_status: "failed",
      updated_at: new Date().toISOString(),
    }).eq("id", body.petId).eq("owner_user_id", user.id);
    return json({ errorCode: "SOURCE_IMAGE_NOT_FOUND", requestId, jobId }, 404);
  }

  let generatedImage: Uint8Array | null = null;
  let usedProvider: ProviderName | null = null;
  let failureMessage = "ALL_PROVIDERS_FAILED";

  for (const provider of chain) {
    for (let attempt = 1; attempt <= MAX_RETRY; attempt += 1) {
      try {
        generatedImage = await withTimeout(
          runProvider(provider, sourceImage, style),
          TIMEOUT_MS,
        );
        usedProvider = provider;
        break;
      } catch (error) {
        failureMessage = `${provider}:${String(error)}`;
      }
    }
    if (generatedImage && usedProvider) break;
  }

  if (!generatedImage || !usedProvider) {
    await serviceClient
      .from("caricature_jobs")
      .update({
        status: "failed",
        error_message: failureMessage,
        retry_count: MAX_RETRY,
        updated_at: new Date().toISOString(),
      })
      .eq("id", jobId);
    await serviceClient.from("pets").update({
      caricature_status: "failed",
      updated_at: new Date().toISOString(),
    }).eq("id", body.petId).eq("owner_user_id", user.id);
    return json({
      errorCode: "ALL_PROVIDERS_FAILED",
      message: failureMessage,
      requestId,
      jobId,
    }, 502);
  }

  const caricaturePath = `${user.id}/${body.petId}/${jobId}.png`;
  const upload = await serviceClient.storage.from("caricatures").upload(
    caricaturePath,
    generatedImage,
    { contentType: "image/png", upsert: true },
  );
  if (upload.error) {
    await serviceClient.from("caricature_jobs").update({
      status: "failed",
      error_message: `storage upload failed: ${upload.error.message}`,
      updated_at: new Date().toISOString(),
    }).eq("id", jobId);
    await serviceClient.from("pets").update({
      caricature_status: "failed",
      updated_at: new Date().toISOString(),
    }).eq("id", body.petId).eq("owner_user_id", user.id);
    return json({ errorCode: "STORAGE_UPLOAD_FAILED", requestId, jobId }, 500);
  }

  const { data: publicData } = serviceClient.storage.from("caricatures").getPublicUrl(caricaturePath);
  const caricatureUrl = publicData.publicUrl;

  await serviceClient.from("pets").update({
    caricature_url: caricatureUrl,
    caricature_status: "ready",
    caricature_provider: usedProvider,
    caricature_style: style,
    updated_at: new Date().toISOString(),
  }).eq("id", body.petId).eq("owner_user_id", user.id);
  await serviceClient.from("caricature_jobs").update({
    status: "ready",
    provider_chain: chain.join(">"),
    updated_at: new Date().toISOString(),
  }).eq("id", jobId);

  return json({
    jobId,
    petId: body.petId,
    status: "ready",
    provider: usedProvider,
    fallbackUsed: usedProvider !== chain[0],
    caricaturePath,
    caricatureUrl,
  });
});
