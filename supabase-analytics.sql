-- Apply after supabase-backend.sql so public.is_admin() is available.
create table if not exists public.job_events (
  id uuid primary key default gen_random_uuid(),
  job_key text not null,
  category text not null,
  event_type text not null check (event_type in ('view', 'apply_click')),
  user_id uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.job_events enable row level security;

revoke all on table public.job_events from public, anon, authenticated;
grant insert, select on table public.job_events to authenticated;

drop policy if exists job_events_insert_own on public.job_events;
create policy job_events_insert_own
  on public.job_events for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists job_events_select_admin on public.job_events;
create policy job_events_select_admin
  on public.job_events for select to authenticated
  using (public.is_admin());

create index if not exists job_events_clicks_created_at_idx
  on public.job_events (created_at)
  where event_type = 'apply_click';

create index if not exists job_events_clicks_category_idx
  on public.job_events (category, created_at)
  where event_type = 'apply_click';

create index if not exists job_events_clicks_job_key_idx
  on public.job_events (job_key, created_at)
  where event_type = 'apply_click';
