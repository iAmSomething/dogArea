export const json = (body: unknown, status = 200, headers?: HeadersInit) => {
  const resolvedHeaders = new Headers(headers);
  if (!resolvedHeaders.has("Content-Type")) {
    resolvedHeaders.set("Content-Type", "application/json");
  }

  return new Response(JSON.stringify(body), {
    status,
    headers: resolvedHeaders,
  });
};

export const errorJson = (
  error: string,
  status: number,
  extra: Record<string, unknown> = {},
) => json({ error, ...extra }, status);

export const methodNotAllowed = () => errorJson("METHOD_NOT_ALLOWED", 405);

export const invalidJson = () => errorJson("INVALID_JSON", 400);

export async function parseJsonBody<T>(
  req: Request,
): Promise<
  | { ok: true; body: T }
  | { ok: false; response: Response }
> {
  try {
    return { ok: true, body: await req.json() as T };
  } catch {
    return { ok: false, response: invalidJson() };
  }
}
