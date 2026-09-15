begin;

create extension if not exists pgcrypto;

-- Enumerated values prevent client-side strings from becoming authorization or
-- workflow states that the application does not understand.
do $$
begin
  create type public.app_role as enum ('user', 'admin');
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.job_status as enum ('draft', 'published', 'closed', 'archived');
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  create type public.application_status as enum (
    'submitted',
    'under_review',
    'interview',
    'offered',
    'rejected',
    'withdrawn'
  );
exception
  when duplicate_object then null;
end;
$$;

-- Existing installs may already have the first, profile-only schema.  The
-- CREATE/ALTER combination makes this safe both for a new project and as an
-- in-place migration from that schema.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  fullname text not null default '',
  phone text,
  course text,
  skills text,
  experience_summary text,
  photo_data_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists email text,
  add column if not exists fullname text,
  add column if not exists phone text,
  add column if not exists course text,
  add column if not exists skills text,
  add column if not exists experience_summary text,
  add column if not exists photo_data_url text,
  add column if not exists resume_data_url text,
  add column if not exists resume_file_name text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  company text not null,
  category text not null,
  location text,
  employment_type text,
  description text,
  skills text[] not null default '{}',
  application_url text,
  status public.job_status not null default 'draft',
  is_featured boolean not null default false,
  published_at timestamptz,
  closes_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete restrict,
  applicant_id uuid not null references auth.users(id) on delete cascade,
  status public.application_status not null default 'submitted',
  cover_letter text,
  resume_path text,
  portfolio_url text,
  applicant_note text,
  admin_note text,
  status_updated_at timestamptz not null default now(),
  withdrawn_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint applications_one_per_job_per_user unique (job_id, applicant_id)
);

create table if not exists public.application_events (
  id bigint generated always as identity primary key,
  application_id uuid not null references public.applications(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  old_status public.application_status,
  new_status public.application_status not null,
  note text,
  created_at timestamptz not null default now()
);

-- Add validation to new writes without failing an installation that has legacy
-- rows.  Admins can clean legacy data and validate these constraints later.
do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_fullname_length_check'
  ) then
    alter table public.profiles add constraint profiles_fullname_length_check
      check (char_length(fullname) <= 160) not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_institutional_email_check'
  ) then
    alter table public.profiles add constraint profiles_institutional_email_check
      check (email ~* '^[^@[:space:]]+@imcc[.]edu[.]ph$') not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_phone_length_check'
  ) then
    alter table public.profiles add constraint profiles_phone_length_check
      check (phone is null or char_length(phone) <= 50) not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_course_length_check'
  ) then
    alter table public.profiles add constraint profiles_course_length_check
      check (course is null or char_length(course) <= 200) not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_skills_length_check'
  ) then
    alter table public.profiles add constraint profiles_skills_length_check
      check (skills is null or char_length(skills) <= 5000) not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_experience_length_check'
  ) then
    alter table public.profiles add constraint profiles_experience_length_check
      check (experience_summary is null or char_length(experience_summary) <= 10000) not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_photo_size_check'
  ) then
    alter table public.profiles add constraint profiles_photo_size_check
      check (photo_data_url is null or octet_length(photo_data_url) <= 2000000) not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.jobs'::regclass
      and conname = 'jobs_category_check'
  ) then
    alter table public.jobs add constraint jobs_category_check
      check (category = any (array[
        'IT', 'Healthcare', 'Business', 'CCJE', 'Social Work', 'CHTM', 'Education'
      ])) not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.jobs'::regclass
      and conname = 'jobs_application_url_check'
  ) then
    alter table public.jobs add constraint jobs_application_url_check
      check (application_url is null or application_url ~* '^https://') not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.applications'::regclass
      and conname = 'applications_cover_letter_length_check'
  ) then
    alter table public.applications add constraint applications_cover_letter_length_check
      check (cover_letter is null or char_length(cover_letter) <= 8000) not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.applications'::regclass
      and conname = 'applications_admin_note_length_check'
  ) then
    alter table public.applications add constraint applications_admin_note_length_check
      check (admin_note is null or char_length(admin_note) <= 8000) not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.applications'::regclass
      and conname = 'applications_portfolio_url_check'
  ) then
    alter table public.applications add constraint applications_portfolio_url_check
      check (portfolio_url is null or portfolio_url ~* '^https://') not valid;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.applications'::regclass
      and conname = 'applications_resume_path_check'
  ) then
    alter table public.applications add constraint applications_resume_path_check
      check (resume_path is null or resume_path like (applicant_id::text || '/%')) not valid;
  end if;
end;
$$;

-- Security-definer helper used by RLS.  Roles live in a table which browser
-- users cannot mutate, rather than in editable profile data or local storage.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles as user_role
    where user_role.user_id = auth.uid()
      and user_role.role = 'admin'::public.app_role
  );
$$;

-- Only the database owner (SQL Editor) or a server using the service-role key
-- can call this.  It is intentionally not granted to authenticated users.
create or replace function public.set_app_role(
  target_user_id uuid,
  target_role public.app_role
)
returns public.user_roles
language plpgsql
security definer
set search_path = ''
as $$
declare
  updated_role public.user_roles;
begin
  insert into public.user_roles (user_id, role)
  values (target_user_id, target_role)
  on conflict (user_id) do update
    set role = excluded.role,
        updated_at = pg_catalog.now()
  returning * into updated_role;

  return updated_role;
end;
$$;

-- Keep an auth-created profile compatible with the current frontend's column
-- names.  Metadata is bounded so a maliciously large signup payload cannot
-- make the auth trigger fail or create an unbounded profile row.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  display_name text;
  avatar_data text;
begin
  if coalesce(new.email, '') !~* '^[^@[:space:]]+@imcc[.]edu[.]ph$' then
    raise exception 'Only @imcc.edu.ph institutional email addresses are allowed';
  end if;

  display_name := coalesce(
    nullif(left(btrim(coalesce(
      new.raw_user_meta_data ->> 'fullname',
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      ''
    )), 160), ''),
    'User'
  );

  avatar_data := nullif(new.raw_user_meta_data ->> 'photo_data_url', '');
  if avatar_data is not null and octet_length(avatar_data) > 2000000 then
    avatar_data := null;
  end if;

  -- The profile write guard permits this trusted auth synchronization only.
  perform pg_catalog.set_config('app.profile_email_sync', 'true', true);

  insert into public.profiles (
    id, email, fullname, phone, course, skills, experience_summary, photo_data_url
  )
  values (
    new.id,
    coalesce(new.email, ''),
    display_name,
    nullif(left(btrim(coalesce(new.raw_user_meta_data ->> 'phone', '')), 50), ''),
    nullif(left(btrim(coalesce(new.raw_user_meta_data ->> 'course', '')), 200), ''),
    nullif(left(btrim(coalesce(new.raw_user_meta_data ->> 'skills', '')), 5000), ''),
    nullif(left(btrim(coalesce(new.raw_user_meta_data ->> 'experience_summary', '')), 10000), ''),
    avatar_data
  )
  on conflict (id) do update
    set email = excluded.email;

  insert into public.user_roles (user_id, role)
  values (new.id, 'user')
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- Auth email changes are mirrored into the private profile.  The local setting
-- lets the profile guard distinguish this trusted trigger from a client edit.
create or replace function public.sync_profile_email_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.email, '') !~* '^[^@[:space:]]+@imcc[.]edu[.]ph$' then
    raise exception 'Only @imcc.edu.ph institutional email addresses are allowed';
  end if;

  if new.email is distinct from old.email then
    perform pg_catalog.set_config('app.profile_email_sync', 'true', true);
    update public.profiles
      set email = coalesce(new.email, '')
    where id = new.id
      and email is distinct from coalesce(new.email, '');
  end if;

  return new;
end;
$$;

-- Protect immutable identity/audit fields while preserving the frontend's
-- existing profile upsert flow for a signed-in user.
create or replace function public.profiles_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null then
      new.created_at := pg_catalog.now();
    end if;
  else
    if new.id is distinct from old.id then
      raise exception 'Profile ownership cannot be changed' using errcode = '42501';
    end if;

    new.created_at := old.created_at;

    if new.email is distinct from old.email
       and coalesce(pg_catalog.current_setting('app.profile_email_sync', true), '') <> 'true' then
      raise exception 'Change an email address through Supabase Auth, not profiles'
        using errcode = '42501';
    end if;
  end if;

  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

create or replace function public.jobs_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null then
      new.created_by := auth.uid();
      new.updated_by := auth.uid();
    end if;
  else
    new.id := old.id;
    new.created_at := old.created_at;
    new.created_by := old.created_by;
    if auth.uid() is not null then
      new.updated_by := auth.uid();
    end if;
  end if;

  if new.status = 'published'::public.job_status and new.published_at is null then
    new.published_at := pg_catalog.now();
  end if;

  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

-- A candidate can edit an application while it is submitted or withdraw it;
-- a candidate cannot reassign it, change it to an admin-only status, or revive
-- a withdrawn application.  Admins retain workflow control through RLS.
create or replace function public.applications_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null then
      new.applicant_id := auth.uid();
      new.created_at := pg_catalog.now();

      -- Internal notes and workflow timestamps are server/admin-owned fields.
      if not public.is_admin() then
        new.admin_note := null;
        new.status_updated_at := pg_catalog.now();
        new.withdrawn_at := null;
      end if;
    end if;
  else
    if new.id is distinct from old.id
       or new.job_id is distinct from old.job_id
       or new.applicant_id is distinct from old.applicant_id then
      raise exception 'Application job and applicant are immutable' using errcode = '42501';
    end if;

    new.created_at := old.created_at;

    if auth.uid() is not null and not public.is_admin() then
      if new.admin_note is distinct from old.admin_note then
        raise exception 'Applicants cannot change internal admin notes'
          using errcode = '42501';
      end if;

      if old.status <> 'submitted'::public.application_status
         or new.status not in ('submitted'::public.application_status, 'withdrawn'::public.application_status) then
        raise exception 'Only a submitted application can be updated or withdrawn'
          using errcode = '42501';
      end if;
    end if;
  end if;

  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    new.status_updated_at := pg_catalog.now();
    if new.status = 'withdrawn'::public.application_status then
      new.withdrawn_at := pg_catalog.now();
    elsif old.status = 'withdrawn'::public.application_status then
      new.withdrawn_at := null;
    end if;
  elsif tg_op = 'UPDATE' then
    new.status_updated_at := old.status_updated_at;
    new.withdrawn_at := old.withdrawn_at;
  end if;

  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

-- Status history is database-written, so neither applicants nor admins can
-- forge the audit trail through the public API.
create or replace function public.record_application_status_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.application_events (
      application_id, actor_id, old_status, new_status
    ) values (
      new.id, auth.uid(), null, new.status
    );
  elsif new.status is distinct from old.status then
    insert into public.application_events (
      application_id, actor_id, old_status, new_status
    ) values (
      new.id, auth.uid(), old.status, new.status
    );
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_before_write on public.profiles;
create trigger profiles_before_write
  before insert or update on public.profiles
  for each row execute function public.profiles_before_write();

drop trigger if exists jobs_before_write on public.jobs;
create trigger jobs_before_write
  before insert or update on public.jobs
  for each row execute function public.jobs_before_write();

drop trigger if exists applications_before_write on public.applications;
create trigger applications_before_write
  before insert or update on public.applications
  for each row execute function public.applications_before_write();

drop trigger if exists applications_record_status_event on public.applications;
create trigger applications_record_status_event
  after insert or update of status on public.applications
  for each row execute function public.record_application_status_event();

-- Replace the original minimal profile trigger with the paired profile/role
-- bootstrap and keep profiles in sync when an Auth email changes.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

drop trigger if exists on_auth_user_email_updated on auth.users;
create trigger on_auth_user_email_updated
  after update of email on auth.users
  for each row execute function public.sync_profile_email_from_auth();

-- Existing accounts outside the institutional domain must not remain usable.
-- Review these accounts before permanently deleting them from Auth.
update auth.users
set banned_until = 'infinity'::timestamptz
where email is null
   or email !~* '^[^@[:space:]]+@imcc[.]edu[.]ph$';

-- Remove legacy profiles that cannot satisfy the institutional-email rule.
-- Their Auth accounts are banned above, so these rows must not be retained or
-- synchronized back into the constrained profiles table.
delete from public.profiles as profile
where coalesce(profile.email, '') !~* '^[^@[:space:]]+@imcc[.]edu[.]ph$'
   or not exists (
     select 1
     from auth.users as auth_user
     where auth_user.id = profile.id
       and coalesce(auth_user.email, '') ~* '^[^@[:space:]]+@imcc[.]edu[.]ph$'
   );

-- Backfill accounts created before this migration.  Existing profile content is
-- preserved; only a missing profile is created and email is synchronized with
-- Auth, which is the source of truth.
insert into public.profiles (
  id, email, fullname, phone, course, skills, experience_summary, photo_data_url
)
select
  auth_user.id,
  coalesce(auth_user.email, ''),
  coalesce(
    nullif(left(btrim(coalesce(
      auth_user.raw_user_meta_data ->> 'fullname',
      auth_user.raw_user_meta_data ->> 'full_name',
      auth_user.raw_user_meta_data ->> 'name',
      ''
    )), 160), ''),
    'User'
  ),
  nullif(left(btrim(coalesce(auth_user.raw_user_meta_data ->> 'phone', '')), 50), ''),
  nullif(left(btrim(coalesce(auth_user.raw_user_meta_data ->> 'course', '')), 200), ''),
  nullif(left(btrim(coalesce(auth_user.raw_user_meta_data ->> 'skills', '')), 5000), ''),
  nullif(left(btrim(coalesce(auth_user.raw_user_meta_data ->> 'experience_summary', '')), 10000), ''),
  case
    when octet_length(coalesce(auth_user.raw_user_meta_data ->> 'photo_data_url', '')) <= 2000000
      then nullif(auth_user.raw_user_meta_data ->> 'photo_data_url', '')
    else null
  end
from auth.users as auth_user
where coalesce(auth_user.email, '') ~* '^[^@[:space:]]+@imcc[.]edu[.]ph$'
on conflict (id) do nothing;

select pg_catalog.set_config('app.profile_email_sync', 'true', true);

update public.profiles as profile
set email = coalesce(auth_user.email, '')
from auth.users as auth_user
where profile.id = auth_user.id
  and profile.email is distinct from coalesce(auth_user.email, '');

insert into public.user_roles (user_id, role)
select auth_user.id, 'user'
from auth.users as auth_user
on conflict (user_id) do nothing;

-- Avoid retaining weaker policies from the initial schema or an earlier run.
do $$
declare
  table_name text;
  policy_row record;
begin
  foreach table_name in array array[
    'profiles', 'user_roles', 'jobs', 'applications', 'application_events'
  ] loop
    for policy_row in
      select policyname
      from pg_catalog.pg_policies
      where schemaname = 'public' and tablename = table_name
    loop
      execute pg_catalog.format(
        'drop policy if exists %I on public.%I', policy_row.policyname, table_name
      );
    end loop;
  end loop;
end;
$$;

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;
alter table public.application_events enable row level security;

-- Start from explicit table privileges.  RLS is the second, row-level gate.
revoke all on table public.profiles from public, anon, authenticated;
revoke all on table public.user_roles from public, anon, authenticated;
revoke all on table public.jobs from public, anon, authenticated;
revoke all on table public.applications from public, anon, authenticated;
revoke all on table public.application_events from public, anon, authenticated;

grant select, insert, update on table public.profiles to authenticated;
grant select on table public.user_roles to authenticated;
grant select on table public.jobs to anon, authenticated;
grant insert, update, delete on table public.jobs to authenticated;
grant select, insert, update, delete on table public.applications to authenticated;
grant select on table public.application_events to authenticated;

-- Profile data is private except to its owner and an authorized admin.  A user
-- can insert only their own row (needed by an upsert client), while Auth's
-- trigger remains the normal profile-creation route.
create policy profiles_select_own_or_admin
  on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());

create policy profiles_insert_own
  on public.profiles for insert to authenticated
  with check (
    id = auth.uid()
    and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

create policy profiles_update_own
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy user_roles_select_own_or_admin
  on public.user_roles for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- A public feed shows only currently open published jobs.  Authenticated admins
-- get an additional policy to manage drafts, closed rows, and all CRUD actions.
create policy jobs_public_read_open
  on public.jobs for select to anon, authenticated
  using (
    status = 'published'::public.job_status
    and published_at <= pg_catalog.now()
    and (closes_at is null or closes_at > pg_catalog.now())
  );

create policy jobs_admin_read_all
  on public.jobs for select to authenticated
  using (public.is_admin());

create policy jobs_admin_insert
  on public.jobs for insert to authenticated
  with check (public.is_admin());

create policy jobs_admin_update
  on public.jobs for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy jobs_admin_delete
  on public.jobs for delete to authenticated
  using (public.is_admin());

create policy applications_select_own_or_admin
  on public.applications for select to authenticated
  using (applicant_id = auth.uid() or public.is_admin());

create policy applications_insert_own_for_open_job
  on public.applications for insert to authenticated
  with check (
    applicant_id = auth.uid()
    and status = 'submitted'::public.application_status
    and exists (
      select 1
      from public.jobs as job
      where job.id = applications.job_id
        and job.status = 'published'::public.job_status
        and job.published_at <= pg_catalog.now()
        and (job.closes_at is null or job.closes_at > pg_catalog.now())
    )
  );

create policy applications_update_own_while_submitted
  on public.applications for update to authenticated
  using (
    applicant_id = auth.uid()
    and status = 'submitted'::public.application_status
  )
  with check (
    applicant_id = auth.uid()
    and status in ('submitted'::public.application_status, 'withdrawn'::public.application_status)
  );

create policy applications_admin_update
  on public.applications for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy applications_admin_delete
  on public.applications for delete to authenticated
  using (public.is_admin());

create policy application_events_select_own_or_admin
  on public.application_events for select to authenticated
  using (
    public.is_admin()
    or exists (
      select 1
      from public.applications as application
      where application.id = application_events.application_id
        and application.applicant_id = auth.uid()
    )
  );

-- The role-check function is callable only where RLS needs it.  Auth/profile
-- trigger functions are not exposed as RPC endpoints.
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

revoke all on function public.set_app_role(uuid, public.app_role) from public, anon, authenticated;
grant execute on function public.set_app_role(uuid, public.app_role) to service_role;

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.sync_profile_email_from_auth() from public, anon, authenticated;
revoke all on function public.profiles_before_write() from public, anon, authenticated;
revoke all on function public.jobs_before_write() from public, anon, authenticated;
revoke all on function public.applications_before_write() from public, anon, authenticated;
revoke all on function public.record_application_status_event() from public, anon, authenticated;

-- Private storage for optional application documents.  The application row can
-- refer only to a path under its applicant UUID, and Storage policies enforce
-- the same directory boundary.  This bucket is private by design.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'application-documents',
  'application-documents',
  false,
  5242880,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists application_documents_insert_own on storage.objects;
drop policy if exists application_documents_select_own_or_admin on storage.objects;
drop policy if exists application_documents_update_own_or_admin on storage.objects;
drop policy if exists application_documents_delete_own_or_admin on storage.objects;

create policy application_documents_insert_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'application-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy application_documents_select_own_or_admin
  on storage.objects for select to authenticated
  using (
    bucket_id = 'application-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin()
    )
  );

create policy application_documents_update_own_or_admin
  on storage.objects for update to authenticated
  using (
    bucket_id = 'application-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin()
    )
  )
  with check (
    bucket_id = 'application-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin()
    )
  );

create policy application_documents_delete_own_or_admin
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'application-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin()
    )
  );

create index if not exists jobs_public_feed_idx
  on public.jobs (category, published_at desc)
  where status = 'published'::public.job_status;

create index if not exists jobs_closes_at_idx on public.jobs (closes_at);
create index if not exists applications_applicant_created_idx
  on public.applications (applicant_id, created_at desc);
create index if not exists applications_job_status_idx
  on public.applications (job_id, status, created_at desc);
create index if not exists application_events_application_created_idx
  on public.application_events (application_id, created_at desc);

-- Initial seed data mirrors the app's seven current categories.  It is
-- intentionally idempotent and will never overwrite a job edited by an admin.
insert into public.jobs (
  slug, title, company, category, location, employment_type, description,
  skills, application_url, status, is_featured, published_at
)
values
  (
    'technical-support-engineer-iligan-actionlabs',
    'Technical Support Engineer - Iligan Area',
    'ActionLabs IT',
    'IT',
    'Iligan City',
    'Full-time',
    'Technical support opportunity for students and alumni pursuing information technology careers.',
    array['technical support', 'troubleshooting', 'customer service'],
    'https://www.glassdoor.com/Overview/Working-at-ActionLabs-IT-EI_IE1036441.11,24.htm',
    'published', true, pg_catalog.now()
  ),
  (
    'registered-medical-technologist-bell-medical',
    'Registered Medical Technologist',
    'Bell Medical Laboratory and Xray',
    'Healthcare',
    'Iligan City',
    'Full-time',
    'Healthcare laboratory opportunity for qualified graduates.',
    array['medical technology', 'laboratory', 'patient care'],
    'https://promoteiligan.com/bell-medical-laboratory-and-xray-is-looking-for-a-registered-medical-technologist/',
    'published', true, pg_catalog.now()
  ),
  (
    'bank-teller-asia-united-bank',
    'Bank Teller / Service Associate',
    'Asia United Bank',
    'Business',
    'Iligan City',
    'Full-time',
    'Entry-level banking and customer service opportunity.',
    array['cash handling', 'customer service', 'banking'],
    'https://www.glassdoor.com/Overview/Working-at-Asia-United-Bank-EI_IE575852.11,27.htm',
    'published', false, pg_catalog.now()
  ),
  (
    'english-language-faculty-phinma-cdo',
    'English Language Faculty',
    'PHINMA Cagayan de Oro College',
    'Education',
    'Iligan City, Lanao del Norte',
    'Full-time',
    'Teaching opportunity for education graduates.',
    array['teaching', 'english', 'curriculum development'],
    'https://ph.jobstreet.com/job/93287211',
    'published', false, pg_catalog.now()
  ),
  (
    'aviation-security-officer-private-advertiser',
    'Aviation Security Officer',
    'Private Advertiser',
    'CCJE',
    'Pasay City, Metro Manila',
    'Full-time',
    'Security and public-safety career opportunity.',
    array['security', 'public safety', 'reporting'],
    'https://ph.jobstreet.com/job/93703231',
    'published', false, pg_catalog.now()
  ),
  (
    'social-welfare-assistant-dswd',
    'Social Welfare Assistant',
    'Department of Social Welfare and Development',
    'Social Work',
    'Iligan City, Lanao del Norte',
    'Full-time',
    'Community and social welfare support opportunity.',
    array['case management', 'community engagement', 'social services'],
    'https://www.dswd.gov.ph/',
    'published', true, pg_catalog.now()
  ),
  (
    'hotel-staff-inn-de-avenida',
    'Hotel Staff',
    'Inn De Avenida',
    'CHTM',
    'Makati City, Metro Manila',
    'Full-time',
    'Hospitality and tourism opportunity for CHTM graduates.',
    array['hospitality', 'guest services', 'tourism'],
    'https://ph.jobstreet.com/job/93853440',
    'published', false, pg_catalog.now()
  )
on conflict (slug) do nothing;

comment on table public.user_roles is
  'Authorization roles. Clients can read only their own role; only a server/service role may change roles.';
comment on table public.application_events is
  'Database-written application status audit trail.';
comment on function public.set_app_role(uuid, public.app_role) is
  'Server-only role management. Do not grant this function to browser roles.';

commit;
