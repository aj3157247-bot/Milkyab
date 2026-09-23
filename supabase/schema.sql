-- رهنمای معاملات افغانستان
-- این فایل را در Supabase SQL Editor اجرا کنید.
-- قبل از انتشار، قوانین و متن قرارداد را با الزامات جاری افغانستان تطبیق دهید.

create extension if not exists pgcrypto;

create table if not exists public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text,
 phone text,
 role text not null default 'customer' check(role in ('customer','owner','office','admin')),
 avatar_url text,
 created_at timestamptz not null default now()
);

create table if not exists public.offices(
 id uuid primary key default gen_random_uuid(),
 owner_user_id uuid references public.profiles(id) on delete set null,
 name text not null,
 phone text,
 whatsapp text,
 province text,
 city text,
 address text,
 latitude numeric,
 longitude numeric,
 description text,
 verified boolean not null default false,
 created_at timestamptz not null default now()
);

create table if not exists public.properties(
 id uuid primary key default gen_random_uuid(),
 owner_id uuid references public.profiles(id) on delete set null,
 office_id uuid references public.offices(id) on delete set null,
 title text not null,
 province text not null,
 city text,
 district text not null,
 category text not null,
 deal_type text not null check(deal_type in ('rent','sale')),
 price numeric not null check(price>=0),
 unit text not null default 'افغانی',
 area numeric,
 rooms integer,
 bathrooms integer,
 furnished boolean default false,
 parking boolean default false,
 address_details text,
 latitude numeric,
 longitude numeric,
 description text,
 image_url text,
 status text not null default 'pending' check(status in ('pending','active','reserved','sold','rented','rejected','archived')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.property_images(
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 storage_path text not null,
 sort_order integer not null default 0,
 created_at timestamptz not null default now()
);

create table if not exists public.favorites(
 user_id uuid not null references public.profiles(id) on delete cascade,
 property_id uuid not null references public.properties(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(user_id,property_id)
);

create table if not exists public.viewing_requests(
 id uuid primary key default gen_random_uuid(),
 property_id uuid not null references public.properties(id) on delete cascade,
 user_id uuid references public.profiles(id) on delete set null,
 office_id uuid references public.offices(id) on delete set null,
 customer_name text,
 customer_phone text,
 requested_at timestamptz,
 note text,
 status text not null default 'pending' check(status in ('pending','confirmed','completed','cancelled')),
 created_at timestamptz not null default now()
);

create table if not exists public.messages(
 id uuid primary key default gen_random_uuid(),
 sender_id uuid references public.profiles(id) on delete set null,
 receiver_id uuid references public.profiles(id) on delete set null,
 property_id uuid references public.properties(id) on delete set null,
 body text not null,
 read_at timestamptz,
 created_at timestamptz not null default now()
);

create table if not exists public.deals(
 id uuid primary key default gen_random_uuid(),
 property_id uuid references public.properties(id) on delete set null,
 office_id uuid references public.offices(id) on delete set null,
 seller_id uuid references public.profiles(id) on delete set null,
 buyer_id uuid references public.profiles(id) on delete set null,
 deal_type text not null check(deal_type in ('rent','sale')),
 agreed_price numeric not null check(agreed_price>=0),
 status text not null default 'negotiation' check(status in ('negotiation','viewed','agreed','contract_pending','completed','cancelled')),
 notes text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.contracts(
 id uuid primary key default gen_random_uuid(),
 deal_id uuid not null references public.deals(id) on delete cascade,
 contract_number text unique not null,
 contract_type text,
 terms text,
 document_path text,
 signed_at timestamptz,
 status text not null default 'draft' check(status in ('draft','ready','signed','cancelled')),
 created_at timestamptz not null default now()
);

create table if not exists public.commissions(
 id uuid primary key default gen_random_uuid(),
 deal_id uuid not null references public.deals(id) on delete cascade,
 payer_role text not null check(payer_role in ('seller','buyer','other')),
 rate_percent numeric,
 fixed_amount numeric,
 amount numeric not null check(amount>=0),
 status text not null default 'unpaid' check(status in ('unpaid','paid','waived')),
 paid_at timestamptz,
 created_at timestamptz not null default now()
);

create table if not exists public.payments(
 id uuid primary key default gen_random_uuid(),
 commission_id uuid references public.commissions(id) on delete set null,
 deal_id uuid references public.deals(id) on delete set null,
 amount numeric not null check(amount>=0),
 method text,
 reference text,
 status text not null default 'pending' check(status in ('pending','confirmed','cancelled')),
 paid_at timestamptz,
 created_at timestamptz not null default now()
);

create table if not exists public.notifications(
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 title text not null,
 body text,
 type text,
 read_at timestamptz,
 created_at timestamptz not null default now()
);

create table if not exists public.reports(
 id uuid primary key default gen_random_uuid(),
 reporter_id uuid references public.profiles(id) on delete set null,
 property_id uuid references public.properties(id) on delete cascade,
 reason text not null,
 details text,
 status text not null default 'open' check(status in ('open','reviewing','resolved','dismissed')),
 created_at timestamptz not null default now()
);

create table if not exists public.admin_logs(
 id uuid primary key default gen_random_uuid(),
 admin_id uuid references public.profiles(id) on delete set null,
 action text not null,
 target_type text,
 target_id uuid,
 details jsonb,
 created_at timestamptz not null default now()
);

create table if not exists public.site_settings(
 key text primary key,
 value jsonb not null default '{}'::jsonb,
 updated_at timestamptz not null default now()
);

-- Automatically create profile after signup.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name,phone,role)
 values(new.id,new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'phone',
   case when (new.raw_user_meta_data->>'role') in ('owner','office') then new.raw_user_meta_data->>'role' else 'customer' end)
 on conflict(id) do nothing;
 return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- RLS
alter table public.profiles enable row level security;
alter table public.offices enable row level security;
alter table public.properties enable row level security;
alter table public.property_images enable row level security;
alter table public.favorites enable row level security;
alter table public.viewing_requests enable row level security;
alter table public.messages enable row level security;
alter table public.deals enable row level security;
alter table public.contracts enable row level security;
alter table public.commissions enable row level security;
alter table public.payments enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;
alter table public.admin_logs enable row level security;
alter table public.site_settings enable row level security;

-- Helper
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;

-- Profiles
drop policy if exists profiles_self on public.profiles;
create policy profiles_self on public.profiles for select using(id=auth.uid() or public.is_admin());
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update using(id=auth.uid() or public.is_admin());

-- Public read for active listings/offices.
drop policy if exists properties_public_read on public.properties;
create policy properties_public_read on public.properties for select using(status='active' or owner_id=auth.uid() or public.is_admin());
drop policy if exists properties_owner_insert on public.properties;
create policy properties_owner_insert on public.properties for insert with check(owner_id=auth.uid());
drop policy if exists properties_owner_update on public.properties;
create policy properties_owner_update on public.properties for update using(owner_id=auth.uid() or public.is_admin());
drop policy if exists properties_owner_delete on public.properties;
create policy properties_owner_delete on public.properties for delete using(owner_id=auth.uid() or public.is_admin());

drop policy if exists offices_public_read on public.offices;
create policy offices_public_read on public.offices for select using(verified=true or owner_user_id=auth.uid() or public.is_admin());
drop policy if exists offices_owner_write on public.offices;
create policy offices_owner_write on public.offices for all using(owner_user_id=auth.uid() or public.is_admin()) with check(owner_user_id=auth.uid() or public.is_admin());

drop policy if exists images_public_read on public.property_images;
create policy images_public_read on public.property_images for select using(exists(select 1 from public.properties p where p.id=property_id and (p.status='active' or p.owner_id=auth.uid() or public.is_admin())));
drop policy if exists images_owner_write on public.property_images;
create policy images_owner_write on public.property_images for all using(exists(select 1 from public.properties p where p.id=property_id and (p.owner_id=auth.uid() or public.is_admin()))) with check(exists(select 1 from public.properties p where p.id=property_id and (p.owner_id=auth.uid() or public.is_admin())));

drop policy if exists fav_self on public.favorites;
create policy fav_self on public.favorites for all using(user_id=auth.uid()) with check(user_id=auth.uid());

drop policy if exists visit_self on public.viewing_requests;
create policy visit_self on public.viewing_requests for insert with check(user_id=auth.uid());
drop policy if exists visit_read on public.viewing_requests;
create policy visit_read on public.viewing_requests for select using(user_id=auth.uid() or public.is_admin() or exists(select 1 from public.offices o where o.id=office_id and o.owner_user_id=auth.uid()));

drop policy if exists msg_self on public.messages;
create policy msg_self on public.messages for select using(sender_id=auth.uid() or receiver_id=auth.uid() or public.is_admin());
drop policy if exists msg_insert on public.messages;
create policy msg_insert on public.messages for insert with check(sender_id=auth.uid());

drop policy if exists deal_access on public.deals;
create policy deal_access on public.deals for select using(seller_id=auth.uid() or buyer_id=auth.uid() or public.is_admin() or exists(select 1 from public.offices o where o.id=office_id and o.owner_user_id=auth.uid()));
drop policy if exists deal_admin_insert on public.deals;
create policy deal_admin_insert on public.deals for insert with check(seller_id=auth.uid() or buyer_id=auth.uid() or public.is_admin());

drop policy if exists contracts_access on public.contracts;
create policy contracts_access on public.contracts for select using(public.is_admin() or exists(select 1 from public.deals d where d.id=deal_id and (d.seller_id=auth.uid() or d.buyer_id=auth.uid() or exists(select 1 from public.offices o where o.id=d.office_id and o.owner_user_id=auth.uid()))));

drop policy if exists commission_access on public.commissions;
create policy commission_access on public.commissions for select using(public.is_admin() or exists(select 1 from public.deals d where d.id=deal_id and (d.seller_id=auth.uid() or d.buyer_id=auth.uid() or exists(select 1 from public.offices o where o.id=d.office_id and o.owner_user_id=auth.uid()))));

drop policy if exists payment_access on public.payments;
create policy payment_access on public.payments for select using(public.is_admin());

drop policy if exists notification_self on public.notifications;
create policy notification_self on public.notifications for select using(user_id=auth.uid() or public.is_admin());
drop policy if exists report_insert on public.reports;
create policy report_insert on public.reports for insert with check(reporter_id=auth.uid());
drop policy if exists report_admin on public.reports;
create policy report_admin on public.reports for select using(public.is_admin() or reporter_id=auth.uid());

-- Seed geography/categories.
insert into public.site_settings(key,value) values
('office', '{"name":"رهنمای معاملات افغانستان","province":"کابل","city":"کابل","address":"آدرس دفتر خود را اینجا وارد کنید","phone":"+93 700 000 000","whatsapp":"93700000000"}'::jsonb)
on conflict(key) do nothing;

-- Storage bucket for property images. Create through Storage UI if this command is unavailable in your project:
-- insert into storage.buckets(id,name,public) values ('property-images','property-images',true) on conflict(id) do nothing;
