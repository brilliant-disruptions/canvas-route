insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('visit-photos', 'visit-photos', false, 10485760, array['image/jpeg','image/png','image/webp']),
       ('pin-photos',   'pin-photos',   true,  10485760, array['image/jpeg','image/png','image/webp']),
       ('avatars',      'avatars',      true,   5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- Visit photos: private, path must start with the owner's uid.
create policy "visit-photos: own" on storage.objects for all
  using (bucket_id = 'visit-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'visit-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Pin photos and avatars: public read, owner-folder write.
create policy "pin-photos: read" on storage.objects for select using (bucket_id = 'pin-photos');
create policy "pin-photos: own write" on storage.objects for insert
  with check (bucket_id = 'pin-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "pin-photos: own delete" on storage.objects for delete
  using (bucket_id = 'pin-photos' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

create policy "avatars: read" on storage.objects for select using (bucket_id = 'avatars');
create policy "avatars: own write" on storage.objects for all
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
