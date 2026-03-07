import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

export type EdgeAuthPolicyKind =
  | "member_required"
  | "member_or_anon"
  | "service_role_internal";

export type EdgeResolvedAuthMode =
  | "authenticated"
  | "anon"
  | "service_role_internal";

type EdgeRejectedAuthMode = EdgeResolvedAuthMode | "unknown";

type EdgeAuthErrorCode =
  | "AUTH_HEADER_MISSING"
  | "AUTH_TOKEN_EMPTY"
  | "AUTH_SESSION_INVALID"
  | "AUTH_MODE_NOT_ALLOWED"
  | "UNAUTHORIZED_USER_MISMATCH";

type EdgeAuthFailureStatus = 401 | 403;

const EDGE_AUTH_VERSION = "2026-03-07.v1";

export type EdgeAuthPolicy = {
  functionName: string;
  kind: EdgeAuthPolicyKind;
  version?: string;
};

export type EdgeAuthContext = {
  functionName: string;
  requestId: string;
  version: string;
  policy: EdgeAuthPolicyKind;
  authMode: EdgeResolvedAuthMode;
  authHeader: string;
  accessToken: string;
  userId: string | null;
  userClient: ReturnType<typeof createClient> | null;
};

type EdgeAuthSuccess = {
  ok: true;
  context: EdgeAuthContext;
};

type EdgeAuthFailure = {
  ok: false;
  response: Response;
};

export type EdgeAuthResult = EdgeAuthSuccess | EdgeAuthFailure;

type EdgeAuthOptions = {
  req: Request;
  policy: EdgeAuthPolicy;
  supabaseURL: string;
  supabaseAnonKey?: string;
  supabaseServiceRoleKey?: string;
};

type EdgeAuthResponseOptions = {
  status: EdgeAuthFailureStatus;
  error: string;
  code: EdgeAuthErrorCode | string;
  message: string;
  functionName: string;
  requestId: string;
  version: string;
  authMode: EdgeRejectedAuthMode;
  policy: EdgeAuthPolicyKind;
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const extractProjectRef = (supabaseURL: string): string | null => {
  try {
    const hostname = new URL(supabaseURL).hostname;
    const projectRef = hostname.split(".")[0]?.trim();
    return projectRef && projectRef.length > 0 ? projectRef : null;
  } catch {
    return null;
  }
};

const decodeJWTClaims = (token: string): Record<string, unknown> | null => {
  const parts = token.split(".");
  if (parts.length < 2) return null;
  const payload = parts[1]
    .replace(/-/g, "+")
    .replace(/_/g, "/")
    .padEnd(Math.ceil(parts[1].length / 4) * 4, "=");
  try {
    const decoded = atob(payload);
    return JSON.parse(decoded) as Record<string, unknown>;
  } catch {
    return null;
  }
};

const isAllowedAnonToken = (
  accessToken: string,
  supabaseURL: string,
  normalizedAnonKey: string | undefined,
): boolean => {
  if (normalizedAnonKey && accessToken === normalizedAnonKey) {
    return true;
  }

  const claims = decodeJWTClaims(accessToken);
  const expectedRef = extractProjectRef(supabaseURL);
  if (!claims || !expectedRef) {
    return false;
  }

  return claims.role === "anon" && claims.ref === expectedRef;
};

const resolveRequestId = (req: Request): string =>
  req.headers.get("x-request-id")?.trim() ||
  req.headers.get("x-client-request-id")?.trim() ||
  req.headers.get("x-correlation-id")?.trim() ||
  crypto.randomUUID();

const buildAuthFailureResponse = (options: EdgeAuthResponseOptions): Response => {
  console.warn("[EdgeAuth]", {
    function_name: options.functionName,
    request_id: options.requestId,
    version: options.version,
    policy: options.policy,
    auth_mode: options.authMode,
    status: options.status,
    code: options.code,
    message: options.message,
  });

  return json({
    ok: false,
    error: options.error,
    code: options.code,
    message: options.message,
    function_name: options.functionName,
    request_id: options.requestId,
    version: options.version,
    auth_mode: options.authMode,
    policy: options.policy,
    fallback_used: false,
  }, options.status);
};

const parseBearerToken = (
  authHeader: string | null,
): { ok: true; authHeader: string; accessToken: string } | {
  ok: false;
  code: EdgeAuthErrorCode;
  message: string;
} => {
  if (!authHeader?.startsWith("Bearer ")) {
    return {
      ok: false,
      code: "AUTH_HEADER_MISSING",
      message: "authorization header required",
    };
  }

  const accessToken = authHeader.replace("Bearer ", "").trim();
  if (!accessToken) {
    return {
      ok: false,
      code: "AUTH_TOKEN_EMPTY",
      message: "empty bearer token",
    };
  }

  return {
    ok: true,
    authHeader,
    accessToken,
  };
};

const resolveMemberContext = async (
  supabaseURL: string,
  supabaseAnonKey: string,
  authHeader: string,
  accessToken: string,
): Promise<{ userId: string; userClient: ReturnType<typeof createClient> } | null> => {
  const userClient = createClient(supabaseURL, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userResult, error: userError } = await userClient.auth.getUser(accessToken);
  if (userError || !userResult?.user) {
    return null;
  }

  return {
    userId: userResult.user.id,
    userClient,
  };
};

export async function resolveEdgeAuthContext(
  options: EdgeAuthOptions,
): Promise<EdgeAuthResult> {
  const { req, policy, supabaseURL, supabaseAnonKey, supabaseServiceRoleKey } = options;
  const normalizedAnonKey = supabaseAnonKey?.trim();
  const normalizedServiceRoleKey = supabaseServiceRoleKey?.trim();
  const requestAPIKey = req.headers.get("apikey")?.trim() || undefined;
  const memberValidationKey = requestAPIKey ?? normalizedAnonKey;
  const requestId = resolveRequestId(req);
  const version = policy.version ?? EDGE_AUTH_VERSION;
  const parsedToken = parseBearerToken(req.headers.get("Authorization"));
  if (!parsedToken.ok) {
    return {
      ok: false,
      response: buildAuthFailureResponse({
        status: 401,
        error: "UNAUTHORIZED",
        code: parsedToken.code,
        message: parsedToken.message,
        functionName: policy.functionName,
        requestId,
        version,
        authMode: "unknown",
        policy: policy.kind,
      }),
    };
  }

  const { authHeader, accessToken } = parsedToken;

  if (policy.kind === "service_role_internal") {
    if (!normalizedServiceRoleKey || accessToken !== normalizedServiceRoleKey) {
      return {
        ok: false,
        response: buildAuthFailureResponse({
          status: 401,
          error: "UNAUTHORIZED",
          code: "AUTH_MODE_NOT_ALLOWED",
          message: "service-role authorization required",
          functionName: policy.functionName,
          requestId,
          version,
          authMode: "unknown",
          policy: policy.kind,
        }),
      };
    }

    return {
      ok: true,
      context: {
        functionName: policy.functionName,
        requestId,
        version,
        policy: policy.kind,
        authMode: "service_role_internal",
        authHeader,
        accessToken,
        userId: null,
        userClient: null,
      },
    };
  }

  if (!memberValidationKey) {
    throw new Error(
      `[EdgeAuth] apikey header or SUPABASE_ANON_KEY is required for policy ${policy.kind} (${policy.functionName})`,
    );
  }

  if (policy.kind === "member_or_anon" && isAllowedAnonToken(accessToken, supabaseURL, memberValidationKey)) {
    return {
      ok: true,
      context: {
        functionName: policy.functionName,
        requestId,
        version,
        policy: policy.kind,
        authMode: "anon",
        authHeader,
        accessToken,
        userId: null,
        userClient: null,
      },
    };
  }

  if (policy.kind === "member_required" && isAllowedAnonToken(accessToken, supabaseURL, memberValidationKey)) {
    return {
      ok: false,
      response: buildAuthFailureResponse({
        status: 401,
        error: "UNAUTHORIZED",
        code: "AUTH_MODE_NOT_ALLOWED",
        message: "member authorization required",
        functionName: policy.functionName,
        requestId,
        version,
        authMode: "anon",
        policy: policy.kind,
      }),
    };
  }

  const memberContext = await resolveMemberContext(
    supabaseURL,
    memberValidationKey,
    authHeader,
    accessToken,
  );
  if (!memberContext) {
    return {
      ok: false,
      response: buildAuthFailureResponse({
        status: 401,
        error: "UNAUTHORIZED",
        code: "AUTH_SESSION_INVALID",
        message: "member token validation failed",
        functionName: policy.functionName,
        requestId,
        version,
        authMode: "unknown",
        policy: policy.kind,
      }),
    };
  }

  return {
    ok: true,
    context: {
      functionName: policy.functionName,
      requestId,
      version,
      policy: policy.kind,
      authMode: "authenticated",
      authHeader,
      accessToken,
      userId: memberContext.userId,
      userClient: memberContext.userClient,
    },
  };
}

export function ensureAuthenticatedUserMatch(
  context: EdgeAuthContext,
  requestedUserId: string | null,
): Response | null {
  if (!requestedUserId || !context.userId || requestedUserId === context.userId) {
    return null;
  }

  return buildAuthFailureResponse({
    status: 403,
    error: "UNAUTHORIZED_USER_MISMATCH",
    code: "UNAUTHORIZED_USER_MISMATCH",
    message: "requested user does not match authenticated user",
    functionName: context.functionName,
    requestId: context.requestId,
    version: context.version,
    authMode: context.authMode,
    policy: context.policy,
  });
}
