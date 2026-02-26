-- Create app storage buckets for DogArea assets.
insert into storage.buckets (id, name, public, file_size_limit)
values
  ('profiles', 'profiles', true, 5242880),
  ('caricatures', 'caricatures', true, 10485760),
  ('walk-maps', 'walk-maps', true, 10485760)
on conflict (id) do nothing;
