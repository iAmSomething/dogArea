import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const STORAGE_BUCKET = Deno.env.get("CARICATURE_BUCKET") ?? "caricatures";

const jsonHeaders = { "Content-Type": "application/json" };

function badRequest(message: string, status = 400) {
  return new Response(JSON.stringify({ error: message }), { status, headers: jsonHeaders });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return badRequest("method not allowed", 405);
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !OPENAI_API_KEY) {
    return badRequest("server is not configured", 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return badRequest("missing bearer token", 401);
  }

  const token = authHeader.replace("Bearer ", "");
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: authData, error: authError } = await supabase.auth.getUser(token);
  if (authError || !authData.user) {
    return badRequest("unauthorized", 401);
  }

  const body = await req.json().catch(() => null) as {
    petId?: string;
    sourceImagePath?: string;
    prompt?: string;
  } | null;

  if (!body?.petId || !body?.sourceImagePath) {
    return badRequest("petId and sourceImagePath are required");
  }

  const { data: downloadData, error: downloadError } = await supabase.storage
    .from("profiles")
    .download(body.sourceImagePath);

  if (downloadError || !downloadData) {
    return badRequest("failed to load source image", 404);
  }

  const imageBytes = new Uint8Array(await downloadData.arrayBuffer());
  const base64Image = btoa(String.fromCharCode(...imageBytes));
  const prompt = body.prompt ?? "Turn this dog photo into a clean, cute caricature profile portrait.";

  // OpenAI image generation proxy call.
  const openAiResponse = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-image-1",
      prompt,
      size: "1024x1024",
      image: base64Image,
      response_format: "b64_json",
    }),
  });

  if (!openAiResponse.ok) {
    const text = await openAiResponse.text();
    return badRequest(`openai call failed: ${text}`, 502);
  }

  const openAiPayload = await openAiResponse.json() as {
    data?: Array<{ b64_json?: string }>;
  };

  const generatedB64 = openAiPayload.data?.[0]?.b64_json;
  if (!generatedB64) {
    return badRequest("missing generated image data", 502);
  }

  const generatedBytes = Uint8Array.from(atob(generatedB64), (c) => c.charCodeAt(0));
  const objectPath = `${authData.user.id}/${body.petId}/${Date.now()}.png`;

  const { error: uploadError } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(objectPath, generatedBytes, {
      contentType: "image/png",
      upsert: false,
    });

  if (uploadError) {
    return badRequest(`failed to upload generated image: ${uploadError.message}`, 500);
  }

  const { data: publicUrlData } = supabase.storage
    .from(STORAGE_BUCKET)
    .getPublicUrl(objectPath);

  const { error: updateError } = await supabase
    .from("pets")
    .update({ caricature_url: publicUrlData.publicUrl })
    .eq("id", body.petId)
    .eq("owner_user_id", authData.user.id);

  if (updateError) {
    return badRequest(`failed to update pet profile: ${updateError.message}`, 500);
  }

  return new Response(
    JSON.stringify({
      petId: body.petId,
      caricaturePath: objectPath,
      caricatureUrl: publicUrlData.publicUrl,
    }),
    { status: 200, headers: jsonHeaders }
  );
});
