-- Jalankan setelah supabase-schema.sql jika akun Google sudah ada di
-- Authentication > Users sebelum trigger Google dibuat.
-- Akun yang belum terdaftar di public.users akan dibuat sebagai viewer.

do $$
declare
  auth_account record;
  app_user_id uuid;
  app_role public.app_role;
  app_status text;
  user_name text;
  user_avatar text;
begin
  for auth_account in
    select id, email, raw_app_meta_data, raw_user_meta_data
    from auth.users
    where coalesce(raw_app_meta_data->>'provider', '') = 'google'
       or coalesce((raw_app_meta_data->'providers') ? 'google', false)
  loop
    if auth_account.email is null or btrim(auth_account.email) = '' then
      continue;
    end if;

    user_name := coalesce(
      nullif(btrim(auth_account.raw_user_meta_data->>'full_name'), ''),
      nullif(btrim(auth_account.raw_user_meta_data->>'name'), ''),
      lower(btrim(auth_account.email))
    );
    user_avatar := nullif(auth_account.raw_user_meta_data->>'avatar_url', '');

    insert into public.users (auth_user_id, name, email, google_id, avatar, role, status)
    values (
      auth_account.id,
      user_name,
      lower(btrim(auth_account.email)),
      auth_account.id::text,
      user_avatar,
      'viewer',
      'active'
    )
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
      raise exception 'Google email % is already linked to another application account', auth_account.email;
    end if;

    insert into public.profiles (id, nama, email, role, status)
    values (
      auth_account.id,
      user_name,
      lower(btrim(auth_account.email)),
      app_role,
      case when app_status = 'active'
        then 'aktif'::public.account_status
        else 'nonaktif'::public.account_status
      end
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
  end loop;
end;
$$;
