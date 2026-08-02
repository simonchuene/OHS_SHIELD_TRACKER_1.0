-- path: supabase/migrations/0008_storage_policies.sql
-- Migration 0008: Supabase Storage bucket + access policies for attachments.
-- Object path convention: <company_id>/<owner_type>/<owner_id>/<version_uuid>.<ext>
-- First path segment = company_id, giving tenant isolation on storage.objects.

-- Private bucket (no public URLs; access via signed URLs from the app).
insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', false)
on conflict (id) do nothing;

-- Read: any authenticated user within the owning company.
create policy attachments_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = app.current_company_id()::text
  );

-- Upload: any authenticated user within their own company (rank >= 1).
create policy attachments_upload on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = app.current_company_id()::text
    and app.has_min_rank(1)
  );

-- Update (overwrite/metadata): uploader-or-SO+ within company.
create policy attachments_modify on storage.objects
  for update to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = app.current_company_id()::text
    and (owner = auth.uid() or app.has_min_rank(3))
  );

-- Physical delete: Safety Officer+ only. (Logical delete is app-layer via
-- attachments.is_active; version history is never destroyed.)
create policy attachments_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = app.current_company_id()::text
    and app.has_min_rank(3)
  );
