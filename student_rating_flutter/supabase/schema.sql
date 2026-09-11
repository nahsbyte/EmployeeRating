-- Tables
create table if not exists public.student (
  student_id text primary key,
  student_name text not null,
  student_class text default '',
  student_address text default '',
  student_phone text default ''
);

create table if not exists public.class (
  class_id text primary key,
  class_name text,
  wali_user_id uuid references public.profiles(user_id),
  created_at timestamptz default now()
);

create table if not exists public.criteria (
  criteria_id text primary key,
  criteria_name text not null,
  criteria_amount integer not null default 0,
  criteria_desc text not null default 'core' -- core | secondary
);

create table if not exists public.rating (
  rating_id text primary key,
  student_id text references public.student(student_id) on delete cascade,
  rating_value jsonb not null default '{}'::jsonb,
  rating_value2 jsonb not null default '{}'::jsonb
);

-- Row Level Security (optional but recommended)
alter table public.student enable row level security;
alter table public.class enable row level security;
alter table public.criteria enable row level security;
alter table public.rating enable row level security;

-- Simple policies: authenticated users can read/write everything.
do $$ begin
  execute 'create policy "Allow all select" on public.student for select using (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all insert" on public.student for insert with check (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all update" on public.student for update using (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all delete" on public.student for delete using (auth.role() = ''authenticated'')';

  execute 'create policy "Allow all select" on public.criteria for select using (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all insert" on public.criteria for insert with check (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all update" on public.criteria for update using (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all delete" on public.criteria for delete using (auth.role() = ''authenticated'')';

  execute 'create policy "Allow all select" on public.class for select using (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all insert" on public.class for insert with check (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all update" on public.class for update using (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all delete" on public.class for delete using (auth.role() = ''authenticated'')';

  execute 'create policy "Allow all select" on public.rating for select using (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all insert" on public.rating for insert with check (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all update" on public.rating for update using (auth.role() = ''authenticated'')';
  execute 'create policy "Allow all delete" on public.rating for delete using (auth.role() = ''authenticated'')';
exception when others then null;
end $$;

alter table public.student
  add column if not exists class_id text references public.class(class_id);

-- Profiles: link optional student_id for direct mapping.
alter table public.profiles
  add column if not exists student_id text references public.student(student_id);
create index if not exists profiles_student_id_idx on public.profiles(student_id);

-- Profiles: optional detailed fields for wali/admin operational data.
alter table public.profiles
  add column if not exists phone text,
  add column if not exists address text,
  add column if not exists identity_number text,
  add column if not exists gender text,
  add column if not exists is_active boolean default true;
