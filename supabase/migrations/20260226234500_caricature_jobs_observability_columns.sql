-- #24 caricature proxy observability columns

alter table if exists public.caricature_jobs
  add column if not exists request_id text,
  add column if not exists schema_version text,
  add column if not exists source_type text,
  add column if not exists error_code text,
  add column if not exists provider_used text,
  add column if not exists fallback_used boolean not null default false,
  add column if not exists latency_ms integer,
  add column if not exists completed_at timestamptz;

create index if not exists idx_caricature_jobs_request_id
  on public.caricature_jobs(request_id);

create index if not exists idx_caricature_jobs_completed_at
  on public.caricature_jobs(completed_at desc);
