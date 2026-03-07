const asTrimmedTextOrNull = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

const firstNonEmptyText = (
  payload: Record<string, unknown>,
  keys: string[],
): string | null => {
  for (const key of keys) {
    const resolved = asTrimmedTextOrNull(payload[key]);
    if (resolved) {
      return resolved;
    }
  }
  return null;
};

export function resolveCanonicalRequestId(
  payload: Record<string, unknown>,
  fallbackRequestId: string,
): string {
  return firstNonEmptyText(payload, ["request_id", "requestId", "action_id"]) ?? fallbackRequestId;
}

export function resolveCanonicalIdempotencyKey(
  payload: Record<string, unknown>,
  options: {
    keys?: string[];
    fallback?: string | null;
  } = {},
): string | null {
  return firstNonEmptyText(payload, options.keys ?? ["idempotency_key", "idempotencyKey"]) ?? options.fallback ?? null;
}
