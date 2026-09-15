create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  fullname text not null,
  phone text,
  course text,
  skills text,
  experience_summary text,
  photo_data_url text,
  resume_data_url text,
  resume_file_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists resume_data_url text,
  add column if not exists resume_file_name text;

alter table public.profiles enable row level security;

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if coalesce(new.email, '') !~* '^[^@[:space:]]+@imcc[.]edu[.]ph$' then
    raise exception 'Only @imcc.edu.ph institutional email addresses are allowed';
  end if;

  insert into public.profiles (id, email, fullname, phone, course, skills, experience_summary, photo_data_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'fullname', ''),
    new.raw_user_meta_data ->> 'phone',
    new.raw_user_meta_data ->> 'course',
    new.raw_user_meta_data ->> 'skills',
    new.raw_user_meta_data ->> 'experience_summary',
    new.raw_user_meta_data ->> 'photo_data_url'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.create_profile_for_new_user();

create policy "Users can read their own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

create policy "Users can create their own profile"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);

create policy "Users can update their own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
