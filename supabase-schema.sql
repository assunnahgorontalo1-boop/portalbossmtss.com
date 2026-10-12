-- Skema online Portal Inventaris BOS
-- Jalankan di SQL Editor Supabase setelah membuat project.
-- Jika tabel activities sudah pernah dibuat, jalankan juga migrasi ini:
-- alter table public.activities add column if not exists changed_data jsonb not null default '{}'::jsonb;
-- Password pengguna dikelola Supabase Auth; jangan simpan password plaintext di tabel aplikasi.

create extension if not exists pgcrypto;

create type public.app_role as enum ('viewer', 'bendahara', 'kepala_madrasah');
create type public.account_status as enum ('aktif', 'nonaktif');

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nama text not null default 'Pengguna',
  email text,
  role public.app_role not null default 'viewer',
  status public.account_status not null default 'aktif',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  kode text,
  nomor_inventaris text,
  nomor_penghapusan text,
  nama_barang text not null,
  kbli text,
  merk text,
  tipe text,
  nomor_seri text,
  kategori text,
  jumlah numeric not null default 0 check (jumlah >= 0),
  satuan text,
  harga numeric not null default 0 check (harga >= 0),
  harga_mode text not null default 'kali' check (harga_mode in ('kali', 'langsung')),
  tanggal_beli date,
  tahun_perolehan integer,
  tahun integer not null,
  tahap text check (tahap in ('tahap1', 'tahap2')),
  kondisi text check (kondisi in ('baik', 'ringan', 'rusak')),
  sumber_dana text,
  penerima text,
  gedung text,
  lantai text,
  ruangan text,
  area text,
  penanggung_jawab text,
  status_barang text,
  nomor_nota text,
  nomor_dokumen text,
  keterangan text,
  foto_utama jsonb,
  foto_tambahan jsonb not null default '[]'::jsonb,
  nota_file jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  tahun integer not null,
  tahap text not null check (tahap in ('tahap1', 'tahap2')),
  anggaran numeric not null default 0 check (anggaran >= 0),
  realisasi numeric not null default 0 check (realisasi >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tahun, tahap)
);

create table if not exists public.procurements (
  id uuid primary key default gen_random_uuid(),
  tahun integer not null,
  nomor text,
  tanggal date,
  tahap text check (tahap in ('tahap1', 'tahap2')),
  sumber_dana text,
  kategori text,
  nama_barang text not null,
  jumlah numeric not null default 0 check (jumlah >= 0),
  satuan text,
  harga numeric not null default 0 check (harga >= 0),
  penyedia text,
  nota text,
  status text,
  keterangan text,
  inventory_id uuid references public.inventory(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  tahun integer not null,
  tanggal date,
  kategori text,
  penerima text,
  deskripsi text,
  volume numeric not null default 0,
  tarif numeric not null default 0,
  bukti text,
  keterangan text,
  foto_utama jsonb,
  nota_file jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mutations (
  id uuid primary key default gen_random_uuid(),
  tahun integer not null,
  nomor text,
  inventory_id uuid references public.inventory(id) on delete set null,
  kode text,
  nama text,
  lokasi_asal text,
  lokasi_tujuan text,
  pj_lama text,
  pj_baru text,
  tanggal date,
  alasan text,
  keterangan text,
  created_at timestamptz not null default now()
);

create table if not exists public.maintenance (
  id uuid primary key default gen_random_uuid(),
  tahun integer not null,
  nomor_pemeliharaan text,
  inventory_id uuid references public.inventory(id) on delete set null,
  kode text,
  nama text,
  tanggal_kerusakan date,
  jenis_kerusakan text,
  kondisi_sebelum text,
  tanggal_perbaikan date,
  biaya numeric not null default 0 check (biaya >= 0),
  teknisi text,
  status text,
  keterangan text,
  updated_by text,
  updated_by_role text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  aktivitas text not null,
  data_id text,
  changed_data jsonb not null default '{}'::jsonb,
  waktu timestamptz not null default now()
);

create table if not exists public.settings (
  id boolean primary key default true check (id),
  madrasah text not null default 'MTSS AS SUNNAH GORONTALO',
  npsn text,
  alamat text,
  tahun_aktif integer,
  kepala text,
  nip_kepala text,
  bendahara text,
  nip_bendahara text,
  whatsapp text,
  email text,
  logo_madrasah text,
  logo_kemenag text,
  updated_at timestamptz not null default now()
);

create or replace function public.current_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles
  where id = auth.uid() and status = 'aktif'
  limit 1;
$$;

create or replace function public.is_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_role() in ('bendahara', 'kepala_madrasah');
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array['profiles','inventory','budgets','procurements','services','maintenance','settings'] loop
    execute format('drop trigger if exists %I on public.%I', 'set_' || table_name || '_updated_at', table_name);
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()', 'set_' || table_name || '_updated_at', table_name);
  end loop;
end $$;

alter table public.profiles enable row level security;
alter table public.inventory enable row level security;
alter table public.budgets enable row level security;
alter table public.procurements enable row level security;
alter table public.services enable row level security;
alter table public.mutations enable row level security;
alter table public.maintenance enable row level security;
alter table public.activities enable row level security;
alter table public.settings enable row level security;

drop policy if exists profiles_read_authenticated on public.profiles;
create policy profiles_read_authenticated on public.profiles for select to authenticated
  using (status = 'aktif' and (id = auth.uid() or public.is_manager()));

drop policy if exists inventory_read_authenticated on public.inventory;
create policy inventory_read_authenticated on public.inventory for select to authenticated using (true);
drop policy if exists inventory_manage_managers on public.inventory;
create policy inventory_manage_managers on public.inventory for all to authenticated
  using (public.is_manager()) with check (public.is_manager());

 drop policy if exists budgets_read_authenticated on public.budgets;
create policy budgets_read_authenticated on public.budgets for select to authenticated using (true);
drop policy if exists budgets_manage_managers on public.budgets;
create policy budgets_manage_managers on public.budgets for all to authenticated
  using (public.is_manager()) with check (public.is_manager());

-- Tabel operasional menggunakan aturan yang sama: viewer read-only.
do $$
declare t text;
begin
  foreach t in array array['procurements','services','mutations','maintenance'] loop
    execute format('drop policy if exists %I_read_authenticated on public.%I', t, t);
    execute format('create policy %I_read_authenticated on public.%I for select to authenticated using (true)', t, t);
    execute format('drop policy if exists %I_manage_managers on public.%I', t, t);
    execute format('create policy %I_manage_managers on public.%I for all to authenticated using (public.is_manager()) with check (public.is_manager())', t, t);
  end loop;
end $$;

drop policy if exists activities_read_managers on public.activities;
create policy activities_read_managers on public.activities for select to authenticated using (public.is_manager() or user_id = auth.uid());
drop policy if exists activities_insert_authenticated on public.activities;
create policy activities_insert_authenticated on public.activities for insert to authenticated with check (user_id = auth.uid());
drop policy if exists activities_delete_managers on public.activities;
create policy activities_delete_managers on public.activities for delete to authenticated using (public.is_manager());

drop policy if exists settings_read_managers on public.settings;
drop policy if exists settings_read_authenticated on public.settings;
create policy settings_read_authenticated on public.settings for select to authenticated using (true);
drop policy if exists settings_manage_managers on public.settings;
create policy settings_manage_managers on public.settings for all to authenticated
  using (public.is_manager()) with check (public.is_manager());

insert into public.settings (id, tahun_aktif)
values (true, extract(year from current_date)::integer)
on conflict (id) do nothing;

-- Penguatan permission granular.
create or replace function public.has_permission(permission_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case permission_name
    when 'inventory.write' then public.current_role() in ('bendahara', 'kepala_madrasah')
    when 'budget.create' then public.current_role() = 'bendahara'
    when 'budget.update' then public.current_role() in ('bendahara', 'kepala_madrasah')
    when 'budget.delete' then public.current_role() = 'bendahara'
    when 'operations.write' then public.current_role() = 'bendahara'
    when 'settings.write' then public.current_role() = 'bendahara'
    when 'audit.delete' then public.current_role() in ('bendahara', 'kepala_madrasah')
    else false
  end;
$$;

-- Viewer tetap read-only; kepala tidak dapat mengubah modul operasional.
do $$
declare t text;
begin
  foreach t in array array['procurements','services','mutations','maintenance'] loop
    execute format('drop policy if exists %I_manage_managers on public.%I', t, t);
    execute format('create policy %I_manage_bendahara on public.%I for all to authenticated using (public.has_permission(''operations.write'')) with check (public.has_permission(''operations.write''))', t, t);
  end loop;
end $$;

drop policy if exists budgets_manage_managers on public.budgets;
create policy budgets_insert_bendahara on public.budgets for insert to authenticated
  with check (public.has_permission('budget.create'));
create policy budgets_update_authorized on public.budgets for update to authenticated
  using (public.has_permission('budget.update')) with check (public.has_permission('budget.update'));
create policy budgets_delete_bendahara on public.budgets for delete to authenticated
  using (public.has_permission('budget.delete'));

drop policy if exists inventory_manage_managers on public.inventory;
create policy inventory_manage_authorized on public.inventory for all to authenticated
  using (public.has_permission('inventory.write')) with check (public.has_permission('inventory.write'));

drop policy if exists settings_manage_managers on public.settings;
create policy settings_manage_bendahara on public.settings for all to authenticated
  using (public.has_permission('settings.write')) with check (public.has_permission('settings.write'));

drop policy if exists activities_insert_authenticated on public.activities;
create policy activities_insert_authenticated on public.activities for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists activities_delete_managers on public.activities;
create policy activities_delete_authorized on public.activities for delete to authenticated
  using (public.has_permission('audit.delete'));

-- Audit server-side: actor dan waktu berasal dari session/database, bukan frontend.
create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.activities (user_id, aktivitas, data_id, changed_data, waktu)
  values (
    auth.uid(),
    lower(tg_op) || ' ' || tg_table_name,
    coalesce((case when tg_op = 'DELETE' then old.id else new.id end)::text, ''),
    jsonb_build_object(
      'table', tg_table_name,
      'operation', tg_op,
      'before', case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
      'after', case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end
    ),
    now()
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['inventory','budgets','procurements','services','mutations','maintenance','settings'] loop
    execute format('drop trigger if exists audit_%I on public.%I', t, t);
    execute format('create trigger audit_%I after insert or update or delete on public.%I for each row execute function public.audit_row_change()', t, t);
  end loop;
end $$;

-- Kompatibilitas tabel users untuk identitas Google dan manajemen akun.
-- Password tetap dikelola oleh Supabase Auth.
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  name text not null default 'Pengguna',
  email text not null,
  google_id text,
  avatar text,
  role public.app_role not null default 'viewer',
  status text not null default 'active' check (status in ('active','inactive')),
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (email),
  unique (google_id)
);

create table if not exists public.viewer_permissions (
  user_id uuid primary key references public.users(id) on delete cascade,
  dashboard boolean not null default true,
  statistik boolean not null default true,
  inventaris boolean not null default true,
  pengadaan boolean not null default false,
  dokumentasi boolean not null default false,
  laporan boolean not null default true,
  detail_transaksi boolean not null default false,
  nominal_transaksi boolean not null default false,
  nota boolean not null default false,
  kwitansi boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.users enable row level security;
alter table public.viewer_permissions enable row level security;

drop policy if exists users_read_self_or_manager on public.users;
create policy users_read_self_or_manager on public.users for select to authenticated
  using (auth_user_id = auth.uid() or lower(email) = lower(coalesce(auth.jwt()->>'email','')) or public.is_manager());
drop policy if exists users_manage_manager on public.users;
create policy users_manage_manager on public.users for all to authenticated
  using (public.is_manager()) with check (public.is_manager());

create or replace function public.current_role()
returns public.app_role
language sql stable security definer set search_path = public
as $$
  select role from public.users where auth_user_id = auth.uid() and status = 'active' limit 1;
$$;

drop policy if exists viewer_permissions_read on public.viewer_permissions;
create policy viewer_permissions_read on public.viewer_permissions for select to authenticated
  using (user_id = auth.uid() or public.is_manager());
drop policy if exists viewer_permissions_manage on public.viewer_permissions;
create policy viewer_permissions_manage on public.viewer_permissions for all to authenticated
  using (public.is_manager()) with check (public.is_manager());

-- Google OAuth accounts receive a viewer profile automatically. Existing user
-- rows keep their assigned role/status when the matching verified email logs in.
create or replace function public.handle_google_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  user_email text := lower(btrim(new.email));
  user_name text;
  user_avatar text;
  app_user_id uuid;
  app_role public.app_role;
  app_status text;
begin
  if coalesce(new.raw_app_meta_data->>'provider', '') <> 'google'
     and not coalesce((new.raw_app_meta_data->'providers') ? 'google', false) then
    return new;
  end if;

  if user_email is null or user_email = '' then
    return new;
  end if;

  user_name := coalesce(
    nullif(btrim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data->>'name'), ''),
    user_email
  );
  user_avatar := nullif(new.raw_user_meta_data->>'avatar_url', '');

  insert into public.users (auth_user_id, name, email, google_id, avatar, role, status)
  values (new.id, user_name, user_email, new.id::text, user_avatar, 'viewer', 'active')
  on conflict (email) do update
    set auth_user_id = coalesce(public.users.auth_user_id, excluded.auth_user_id),
        google_id = coalesce(public.users.google_id, excluded.google_id),
        name = case when public.users.name = 'Pengguna' then excluded.name else public.users.name end,
        avatar = coalesce(public.users.avatar, excluded.avatar),
        updated_at = now()
    where public.users.auth_user_id is null
       or public.users.auth_user_id = excluded.auth_user_id
  returning id, role, status into app_user_id, app_role, app_status;

  if not found then
    raise exception 'Google email is already linked to another application account';
  end if;

  insert into public.profiles (id, nama, email, role, status)
  values (
    new.id,
    user_name,
    user_email,
    app_role,
    case when app_status = 'active' then 'aktif'::public.account_status else 'nonaktif'::public.account_status end
  )
  on conflict (id) do update
    set nama = case when public.profiles.nama = 'Pengguna' then excluded.nama else public.profiles.nama end,
        email = excluded.email,
        role = excluded.role,
        status = excluded.status,
        updated_at = now();

  insert into public.viewer_permissions (user_id)
  values (app_user_id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_google_auth_user() from public, anon, authenticated;
drop trigger if exists on_auth_user_created_google on auth.users;
create trigger on_auth_user_created_google
  after insert on auth.users
  for each row execute function public.handle_google_auth_user();

-- Penting: pembuatan akun dilakukan melalui Supabase Auth.
-- Password di-hash dan dikelola Supabase Auth, bukan oleh HTML/JavaScript.
-- Akun Google baru mendapat role viewer; role pengguna lain hanya dapat diubah
-- melalui backend/admin tepercaya.
