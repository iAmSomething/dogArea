-- Storage policies for DogArea public asset buckets.

-- Buckets are created as public for direct read access from app.
insert into storage.buckets (id, name, public, file_size_limit)
values
  ('profiles', 'profiles', true, 5242880),
  ('caricatures', 'caricatures', true, 10485760),
  ('walk-maps', 'walk-maps', true, 10485760)
on conflict (id) do nothing;

-- Public read policy
drop policy if exists "Public can read DogArea assets" on storage.objects;
create policy "Public can read DogArea assets"
on storage.objects
for select
to public
using (bucket_id in ('profiles', 'caricatures', 'walk-maps'));

-- Authenticated users can upload only under their own user-id folder.
drop policy if exists "Authenticated can upload own DogArea assets" on storage.objects;
create policy "Authenticated can upload own DogArea assets"
on storage.objects
for insert
to authenticated
with check (
  bucket_id in ('profiles', 'caricatures', 'walk-maps')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Authenticated can update own DogArea assets" on storage.objects;
create policy "Authenticated can update own DogArea assets"
on storage.objects
for update
to authenticated
using (
  bucket_id in ('profiles', 'caricatures', 'walk-maps')
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id in ('profiles', 'caricatures', 'walk-maps')
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Authenticated can delete own DogArea assets" on storage.objects;
create policy "Authenticated can delete own DogArea assets"
on storage.objects
for delete
to authenticated
using (
  bucket_id in ('profiles', 'caricatures', 'walk-maps')
  and (storage.foldername(name))[1] = auth.uid()::text
);
