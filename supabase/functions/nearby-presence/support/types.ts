export type Action =
  | "set_visibility"
  | "get_visibility"
  | "upsert_presence"
  | "get_hotspots"
  | "upsert_live_presence"
  | "get_live_presence";

export type RequestDTO = {
  action: Action;
  request_id?: string;
  requestId?: string;
  action_id?: string;
  userId?: string;
  user_id?: string;
  excludedUserIds?: string[];
  deviceKey?: string;
  enabled?: boolean;
  lat?: number;
  lng?: number;
  speedMps?: number;
  sequence?: number;
  idempotency_key?: string;
  idempotencyKey?: string;
  updatedAt?: string;
  ttlSeconds?: number;
  sessionId?: string;
  centerLat?: number;
  centerLng?: number;
  radiusKm?: number;
  minLat?: number;
  maxLat?: number;
  minLng?: number;
  maxLng?: number;
  maxRows?: number;
  privacyMode?: "public" | "private" | "all";
};

export type ResponseHotspotDTO = {
  geohash7: string;
  count: number;
  intensity: number;
  center_lat: number;
  center_lng: number;
  sample_count?: number;
  privacy_mode?: string;
  suppression_reason?: string | null;
  delay_minutes?: number;
  required_min_sample?: number;
};

export type ResponseLivePresenceDTO = {
  owner_user_id: string;
  session_id: string;
  lat_rounded: number;
  lng_rounded: number;
  geohash7: string;
  speed_mps?: number | null;
  sequence?: number;
  idempotency_key?: string;
  updated_at: string;
  expires_at: string;
  write_applied?: boolean;
  privacy_mode?: string;
  suppression_reason?: string | null;
  delay_minutes?: number;
  required_min_sample?: number;
  obfuscation_meters?: number;
  abuse_reason?: string | null;
  abuse_score?: number;
  sanction_level?: string | null;
  sanction_until?: string | null;
};

export type NearbyPresenceClient = any;

export type NearbyPresenceRequestContext = {
  client: NearbyPresenceClient;
  body: RequestDTO;
  requestId: string;
};

export type VisibilitySettingDTO = {
  enabled: boolean;
  updated_at: string | null;
};

export type LivePresenceUpsertPayload = {
  userId: string;
  sessionId?: string;
  deviceKey?: string;
  latitude: number;
  longitude: number;
  speedMps?: number;
  sequence?: number;
  idempotencyKey?: string;
  updatedAt?: string;
  ttlSeconds?: number;
};
