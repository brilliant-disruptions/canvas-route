create table public.feature_requests (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.profiles(id) on delete cascade,
  title            text not null,
  category         text not null,
  problem          text,
  workaround       text,
  vision           text,
  role             text,
  frequency        text,
  impact           text,
  interview_opt_in boolean not null default false,
  interview_email  text,
  status           text not null default 'queued'
                   check (status in ('queued','discarded','merged','backlog','to_do','development','testing','future_release','done')),
  summary          text,
  parent_id        uuid references public.feature_requests(id) on delete set null,
  upvote_count     int not null default 0,
  org_count        int not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create trigger feature_requests_set_updated_at before update on public.feature_requests
  for each row execute function public.set_updated_at();
create index feature_requests_status_idx on public.feature_requests (status, upvote_count desc);

create table public.upvotes (
  request_id uuid not null references public.feature_requests(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (request_id, user_id)
);

create table public.feature_request_comments (
  id         uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.feature_requests(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  body       text not null,
  created_at timestamptz not null default now()
);

-- Recompute denormalized counts; org_count = distinct email domains among upvoters.
create or replace function public.recount_upvotes()
returns trigger language plpgsql security definer set search_path = public as $$
declare rid uuid := coalesce(new.request_id, old.request_id);
begin
  update public.feature_requests fr set
    upvote_count = (select count(*) from public.upvotes u where u.request_id = rid),
    org_count = (select count(distinct split_part(p.email, '@', 2))
                 from public.upvotes u join public.profiles p on p.id = u.user_id
                 where u.request_id = rid and p.email is not null)
  where fr.id = rid;
  return null;
end;
$$;
create trigger upvotes_recount after insert or delete on public.upvotes
  for each row execute function public.recount_upvotes();

alter table public.feature_requests enable row level security;
alter table public.upvotes enable row level security;
alter table public.feature_request_comments enable row level security;

-- Public board: everyone signed in reads published requests; submitters and admins see the rest.
create policy "fr: read published or own or admin" on public.feature_requests for select
  using (status not in ('queued','discarded') or user_id = auth.uid() or public.is_admin());
create policy "fr: paying users submit" on public.feature_requests for insert
  with check (user_id = auth.uid()
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.plan in ('pro','team')));
create policy "fr: admin manages" on public.feature_requests for update
  using (public.is_admin()) with check (public.is_admin());

create policy "upvotes: read" on public.upvotes for select using (true);
create policy "upvotes: own" on public.upvotes for insert with check (user_id = auth.uid());
create policy "upvotes: remove own" on public.upvotes for delete using (user_id = auth.uid());

create policy "frc: read" on public.feature_request_comments for select using (true);
create policy "frc: own" on public.feature_request_comments for insert with check (user_id = auth.uid());
