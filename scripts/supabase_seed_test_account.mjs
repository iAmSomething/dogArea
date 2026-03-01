#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import crypto from "node:crypto";

function parseArgs(argv) {
  const args = {
    email: "test@test.com",
    password: process.env.TEST_ACCOUNT_PASSWORD || "Test1234!",
    displayName: "DogArea Test User",
    petName: "테스트멍멍이",
    lat: null,
    lng: null,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const key = argv[i];
    const value = argv[i + 1];
    if (!key.startsWith("--")) continue;

    switch (key) {
      case "--email":
        args.email = value;
        i += 1;
        break;
      case "--password":
        args.password = value;
        i += 1;
        break;
      case "--display-name":
        args.displayName = value;
        i += 1;
        break;
      case "--pet-name":
        args.petName = value;
        i += 1;
        break;
      case "--lat":
        args.lat = Number(value);
        i += 1;
        break;
      case "--lng":
        args.lng = Number(value);
        i += 1;
        break;
      default:
        break;
    }
  }

  return args;
}

function parseEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const content = fs.readFileSync(filePath, "utf8");
  const lines = content.split(/\r?\n/);
  const env = {};

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const idx = line.indexOf("=");
    if (idx <= 0) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim().replace(/^['"]|['"]$/g, "");
    if (key) env[key] = value;
  }
  return env;
}

function resolveConfig(cwd) {
  const localEnv = parseEnvFile(path.join(cwd, ".env.supabase.local"));
  const rootXcconfigEnv = parseEnvFile(path.join(cwd, "supabaseConfig.xcconfig"));
  const xcconfigEnv = parseEnvFile(path.join(cwd, "supabase", "supabaseConfig.xcconfig"));

  const supabaseURL = process.env.SUPABASE_URL || localEnv.SUPABASE_URL || rootXcconfigEnv.SUPABASE_URL || xcconfigEnv.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY || localEnv.SUPABASE_ANON_KEY || rootXcconfigEnv.SUPABASE_ANON_KEY || xcconfigEnv.SUPABASE_ANON_KEY;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY || localEnv.SUPABASE_SERVICE_ROLE_KEY || rootXcconfigEnv.SUPABASE_SERVICE_ROLE_KEY || xcconfigEnv.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseURL || !serviceRoleKey) {
    throw new Error("SUPABASE_URL 또는 SUPABASE_SERVICE_ROLE_KEY가 비어 있습니다.");
  }

  return {
    supabaseURL: supabaseURL.replace(/\/$/, ""),
    anonKey,
    serviceRoleKey,
  };
}

async function requestJSON(url, { method = "GET", headers = {}, body = undefined } = {}) {
  const response = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const text = await response.text();
  let json = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = { raw: text };
    }
  }

  return {
    ok: response.ok,
    status: response.status,
    json,
  };
}

function serviceHeaders(config, extra = {}) {
  return {
    apikey: config.serviceRoleKey,
    Authorization: `Bearer ${config.serviceRoleKey}`,
    "Content-Type": "application/json",
    ...extra,
  };
}

function anonHeaders(config, extra = {}) {
  return {
    apikey: config.anonKey || config.serviceRoleKey,
    Authorization: `Bearer ${config.anonKey || config.serviceRoleKey}`,
    "Content-Type": "application/json",
    ...extra,
  };
}

async function detectBaseLocation(config, args) {
  if (Number.isFinite(args.lat) && Number.isFinite(args.lng)) {
    return { lat: args.lat, lng: args.lng, source: "cli" };
  }

  const nearbyURL = `${config.supabaseURL}/rest/v1/nearby_presence?select=lat_rounded,lng_rounded,last_seen_at&order=last_seen_at.desc&limit=1`;
  const nearbyRes = await requestJSON(nearbyURL, {
    headers: serviceHeaders(config),
  });
  if (nearbyRes.ok && Array.isArray(nearbyRes.json) && nearbyRes.json.length > 0) {
    const row = nearbyRes.json[0];
    if (Number.isFinite(row.lat_rounded) && Number.isFinite(row.lng_rounded)) {
      return {
        lat: row.lat_rounded,
        lng: row.lng_rounded,
        source: "nearby_presence",
      };
    }
  }

  const walkPointURL = `${config.supabaseURL}/rest/v1/walk_points?select=lat,lng,recorded_at&order=recorded_at.desc&limit=1`;
  const walkPointRes = await requestJSON(walkPointURL, {
    headers: serviceHeaders(config),
  });
  if (walkPointRes.ok && Array.isArray(walkPointRes.json) && walkPointRes.json.length > 0) {
    const row = walkPointRes.json[0];
    if (Number.isFinite(row.lat) && Number.isFinite(row.lng)) {
      return {
        lat: row.lat,
        lng: row.lng,
        source: "walk_points",
      };
    }
  }

  return { lat: 37.5665, lng: 126.978, source: "default_seoul" };
}

async function ensureAuthUser(config, email, password) {
  const createURL = `${config.supabaseURL}/auth/v1/admin/users`;
  const createRes = await requestJSON(createURL, {
    method: "POST",
    headers: serviceHeaders(config),
    body: {
      email,
      password,
      email_confirm: true,
      user_metadata: {
        source: "dogarea_seed_script",
      },
    },
  });

  if (createRes.ok && createRes.json?.id) {
    return createRes.json.id;
  }

  const tokenURL = `${config.supabaseURL}/auth/v1/token?grant_type=password`;
  const tokenRes = await requestJSON(tokenURL, {
    method: "POST",
    headers: anonHeaders(config),
    body: { email, password },
  });

  if (tokenRes.ok && tokenRes.json?.user?.id) {
    return tokenRes.json.user.id;
  }

  const usersURL = `${config.supabaseURL}/auth/v1/admin/users?page=1&per_page=1000`;
  const usersRes = await requestJSON(usersURL, {
    headers: serviceHeaders(config),
  });

  if (usersRes.ok && Array.isArray(usersRes.json?.users)) {
    const found = usersRes.json.users.find((user) => {
      const target = String(email).toLowerCase();
      return String(user.email || "").toLowerCase() === target;
    });
    if (found?.id) {
      return found.id;
    }
  }

  const reason = createRes.json?.msg || createRes.json?.message || tokenRes.json?.msg || tokenRes.json?.message || "사용자 생성/조회 실패";
  throw new Error(reason);
}

async function upsertProfile(config, userId, displayName) {
  const url = `${config.supabaseURL}/rest/v1/profiles`;
  const res = await requestJSON(url, {
    method: "POST",
    headers: serviceHeaders(config, {
      Prefer: "resolution=merge-duplicates,return=representation",
    }),
    body: [
      {
        id: userId,
        display_name: displayName,
      },
    ],
  });

  if (!res.ok) {
    throw new Error(`profiles upsert 실패(${res.status})`);
  }
}

async function ensurePet(config, userId, petName) {
  const encodedUser = encodeURIComponent(`eq.${userId}`);
  const encodedPetName = encodeURIComponent(`eq.${petName}`);
  const queryURL = `${config.supabaseURL}/rest/v1/pets?select=id,name&owner_user_id=${encodedUser}&name=${encodedPetName}&order=updated_at.desc&limit=1`;
  const queryRes = await requestJSON(queryURL, {
    headers: serviceHeaders(config),
  });

  if (queryRes.ok && Array.isArray(queryRes.json) && queryRes.json.length > 0) {
    return queryRes.json[0].id;
  }

  const insertURL = `${config.supabaseURL}/rest/v1/pets`;
  const insertRes = await requestJSON(insertURL, {
    method: "POST",
    headers: serviceHeaders(config, {
      Prefer: "return=representation",
    }),
    body: [
      {
        owner_user_id: userId,
        name: petName,
        is_active: true,
      },
    ],
  });

  if (!insertRes.ok || !Array.isArray(insertRes.json) || insertRes.json.length === 0) {
    throw new Error(`pets insert 실패(${insertRes.status}): ${JSON.stringify(insertRes.json)}`);
  }

  return insertRes.json[0].id;
}

function makePolygonPoints(centerLat, centerLng, offset) {
  return [
    { lat: centerLat + offset, lng: centerLng - offset },
    { lat: centerLat + offset, lng: centerLng + offset },
    { lat: centerLat - offset, lng: centerLng + offset },
    { lat: centerLat - offset, lng: centerLng - offset },
    { lat: centerLat + offset, lng: centerLng - offset },
  ];
}

async function insertWalkSeed(config, userId, petId, baseLat, baseLng) {
  const now = Date.now();
  const sessions = [];
  const points = [];

  for (let i = 0; i < 3; i += 1) {
    const sessionId = crypto.randomUUID();
    const startedAt = new Date(now - (i + 1) * 6 * 60 * 60 * 1000);
    const endedAt = new Date(startedAt.getTime() + 18 * 60 * 1000 + i * 120 * 1000);
    const pointBase = makePolygonPoints(
      baseLat + i * 0.0017,
      baseLng + i * 0.0014,
      0.00055 + i * 0.00008,
    );

    sessions.push({
      id: sessionId,
      owner_user_id: userId,
      pet_id: petId,
      started_at: startedAt.toISOString(),
      ended_at: endedAt.toISOString(),
      duration_sec: Math.floor((endedAt.getTime() - startedAt.getTime()) / 1000),
      area_m2: 1650 + i * 540,
      source_device: i % 2 === 0 ? "ios" : "watchos",
    });

    pointBase.forEach((point, idx) => {
      points.push({
        walk_session_id: sessionId,
        seq_no: idx,
        lat: point.lat,
        lng: point.lng,
        recorded_at: new Date(startedAt.getTime() + idx * 180 * 1000).toISOString(),
      });
    });
  }

  const sessionRes = await requestJSON(`${config.supabaseURL}/rest/v1/walk_sessions`, {
    method: "POST",
    headers: serviceHeaders(config),
    body: sessions,
  });
  if (!sessionRes.ok) {
    throw new Error(`walk_sessions insert 실패(${sessionRes.status}): ${JSON.stringify(sessionRes.json)}`);
  }

  const pointRes = await requestJSON(`${config.supabaseURL}/rest/v1/walk_points`, {
    method: "POST",
    headers: serviceHeaders(config),
    body: points,
  });
  if (!pointRes.ok) {
    throw new Error(`walk_points insert 실패(${pointRes.status}): ${JSON.stringify(pointRes.json)}`);
  }

  const milestonePayload = sessions.map((session, idx) => ({
    owner_user_id: userId,
    pet_id: petId,
    area_name: `테스트 구역 ${idx + 1}`,
    area_m2: session.area_m2,
    achieved_at: session.ended_at,
  }));

  const milestoneRes = await requestJSON(`${config.supabaseURL}/rest/v1/area_milestones`, {
    method: "POST",
    headers: serviceHeaders(config),
    body: milestonePayload,
  });
  if (!milestoneRes.ok) {
    throw new Error(`area_milestones insert 실패(${milestoneRes.status}): ${JSON.stringify(milestoneRes.json)}`);
  }

  return {
    sessionCount: sessions.length,
    pointCount: points.length,
  };
}

async function main() {
  const cwd = process.cwd();
  const args = parseArgs(process.argv);
  const config = resolveConfig(cwd);

  if (!args.email || !args.password) {
    throw new Error("--email, --password 값이 필요합니다.");
  }

  const baseLocation = await detectBaseLocation(config, args);
  const userId = await ensureAuthUser(config, args.email, args.password);
  await upsertProfile(config, userId, args.displayName);
  const petId = await ensurePet(config, userId, args.petName);
  const seedResult = await insertWalkSeed(config, userId, petId, baseLocation.lat, baseLocation.lng);

  console.log("Seed complete");
  console.log(`email=${args.email}`);
  console.log(`user_id=${userId}`);
  console.log(`pet_id=${petId}`);
  console.log(`base_location=${baseLocation.lat},${baseLocation.lng} (${baseLocation.source})`);
  console.log(`sessions=${seedResult.sessionCount}`);
  console.log(`points=${seedResult.pointCount}`);
}

main().catch((error) => {
  console.error(`Seed failed: ${error.message}`);
  process.exit(1);
});
