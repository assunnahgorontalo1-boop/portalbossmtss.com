-- Jalankan pada project yang sudah memasang schema lama agar semua pengguna
-- yang login dapat membaca pengaturan madrasah. Hak ubah tetap dibatasi role.
drop policy if exists settings_read_managers on public.settings;
drop policy if exists settings_read_authenticated on public.settings;

create policy settings_read_authenticated
  on public.settings
  for select
  to authenticated
  using (true);
