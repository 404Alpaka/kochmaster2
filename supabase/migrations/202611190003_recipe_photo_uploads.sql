begin;
-- Recipe covers are public; uploading requires the existing recipe admin role.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('recipe-images', 'recipe-images', true, 8388608, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists recipe_admin_photo_insert on storage.objects;
create policy recipe_admin_photo_insert on storage.objects
for insert to authenticated with check (
  bucket_id = 'recipe-images'
  and (select public.is_recipe_admin())
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
commit;
