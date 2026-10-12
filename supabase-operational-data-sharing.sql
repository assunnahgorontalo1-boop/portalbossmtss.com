-- Jalankan pada project yang sudah memasang supabase-schema.sql.
-- Menambahkan field yang dipakai frontend tanpa membuat tabel baru.
alter table public.inventory
  add column if not exists nomor_penghapusan text,
  add column if not exists harga_mode text not null default 'kali'
    check (harga_mode in ('kali', 'langsung')),
  add column if not exists penerima text;

alter table public.maintenance
  add column if not exists updated_by text,
  add column if not exists updated_by_role text;

alter table public.services
  add column if not exists foto_utama jsonb,
  add column if not exists nota_file jsonb;

-- Aktifkan perubahan tabel operasional pada Supabase Realtime jika publication tersedia.
do $$
declare
  table_name text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach table_name in array array['inventory','budgets','procurements','services','mutations','maintenance'] loop
      if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = table_name
      ) then
        execute format('alter publication supabase_realtime add table public.%I', table_name);
      end if;
    end loop;
  end if;
end $$;
