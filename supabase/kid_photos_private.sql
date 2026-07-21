-- Kid photos: private bucket + signed URLs (applied 2026-05-30).
-- The bucket is now private (no public URLs, no listing). The app uploads to a
-- path stored in kid_profiles.photo_url and renders images via short-lived
-- signed URLs. Path confidentiality is enforced by kid_profiles RLS.
update storage.buckets set public = false where id = 'kid-photos';

drop policy if exists "kid_photos_signed_read" on storage.objects;
create policy "kid_photos_signed_read" on storage.objects for select to authenticated
using (bucket_id = 'kid-photos');
