# Portal Inventaris BOS — fondasi online

File `supabase-schema.sql` berisi skema PostgreSQL online dan Row Level Security (RLS) untuk mode multi-user.

## Urutan pemasangan

1. Buat project PostgreSQL/Supabase.
2. Jalankan seluruh isi `supabase-schema.sql` di SQL Editor.
   - Pada project yang sudah ada, jalankan `supabase-operational-data-sharing.sql` setelah schema. Migrasi ini hanya menambah kolom yang dibutuhkan pada tabel operasional yang sudah ada (termasuk kolom foto utama dan nota/bukti transaksi honor/jasa) dan mendaftarkan tabel tersebut ke Supabase Realtime jika publication tersedia; tidak membuat tabel baru.
   - Jika schema sudah pernah dipasang dan pengguna Google sudah ada di Authentication → Users, jalankan hanya `supabase-google-backfill.sql` untuk menghubungkan akun tersebut ke profil aplikasi. Jangan jalankan ulang schema penuh karena pembuatan enum awal tidak dirancang sebagai migrasi berulang.
   - Jika schema sudah dipasang sebelum pengaturan dibagikan ke viewer, jalankan `supabase-settings-sharing.sql`. Pengaturan dibaca dari tabel `public.settings`; hanya bendahara yang dapat mengubahnya melalui RLS.
3. Di Supabase Dashboard → Authentication → Sign In / Providers, aktifkan Google dan masukkan OAuth Client ID/Secret dari Google Cloud. Redirect URI callback Google adalah:

   `https://ccetccoywoguuhkcyvyj.supabase.co/auth/v1/callback`

4. Di Supabase Dashboard → Authentication → URL Configuration, atur Site URL dan tambahkan URL redirect:

   - Site URL: `https://www.portainventaris-bosassunnah.com/`
   - Redirect URL: `https://www.portainventaris-bosassunnah.com/**`
   - Untuk Live Server lokal: `http://127.0.0.1:5500/**` dan `http://localhost:5500/**`

5. Pasang/deploy aplikasi di domain tersebut dan arahkan DNS domain ke penyedia hosting. SQL tidak dapat membeli domain, mengatur DNS, atau mengaktifkan provider Google.
6. Login Google pertama kali otomatis membuat akun aplikasi dengan role `viewer`. Akun yang sudah lebih dulu didaftarkan di `public.users` mempertahankan role dan statusnya. Daftar **Authentication → Users** adalah akun autentikasi; daftar itu terpisah dari tabel aplikasi `public.users` dan `public.profiles`. Nonaktifkan pendaftaran Supabase lain jika memang hanya login dengan Google yang diinginkan.
7. Untuk menetapkan pengelola pertama, minta akun tersebut login Google sekali, lalu ubah role melalui SQL Editor sebagai administrator:

```sql
update public.users
set role = 'bendahara'
where lower(email) = lower('bendahara@contoh.sch.id')
  and auth_user_id is not null;

update public.profiles
set role = 'bendahara'
where id = (
  select auth_user_id
  from public.users
  where lower(email) = lower('bendahara@contoh.sch.id')
);
```

Pengelola tambahan selanjutnya dapat ditetapkan melalui panel administrasi aplikasi. Jangan memberikan role pengelola melalui metadata Google atau input publik.

Role yang tersedia:

- `viewer`: hanya membaca data.
- `bendahara`: mengelola data.
- `kepala_madrasah`: membaca data dan memiliki hak ubah terbatas sesuai kebijakan RLS; sinkronisasi modul operasional saat ini hanya menerima penulisan dari bendahara.

8. Sebelum migrasi, gunakan fitur **Backup Data** pada aplikasi lama untuk menyimpan JSON localStorage.
9. Saat bendahara login di browser yang menyimpan data lokal, aplikasi menawarkan impor tahun yang belum ada di Supabase. Tahun yang sudah memiliki data online tidak ditimpa; data lokal juga tidak dihapus. Pastikan backup tersedia sebelum menyetujui impor.
10. Jangan menghapus backup asli. Jangan menaruh service-role key di browser; aplikasi menggunakan session Supabase pengguna dan RLS untuk membatasi penulisan kepada pengelola.

## Aturan keamanan

RLS sudah disiapkan agar:

- pengguna login dapat membaca inventaris dan anggaran;
- viewer tidak dapat `insert`, `update`, atau `delete`;
- bendahara dapat mengelola tabel operasional; kepala madrasah memiliki hak ubah terbatas pada tabel tertentu;
- aktivitas dapat ditulis oleh pengguna yang sedang login;
- pengaturan hanya dapat dibaca/diubah pengelola.

Sembunyikan menu viewer di frontend untuk pengalaman pengguna, tetapi jangan menganggapnya sebagai keamanan. RLS/API tetap menjadi pengaman utama.

Pengaturan yang sebelumnya tersimpan hanya di browser pengelola tidak otomatis masuk ke Supabase. Masuk sebagai bendahara menggunakan Google, isi kembali nilai yang belum ada di tabel `public.settings`, lalu simpan. Pesan aplikasi akan menyatakan apakah perubahan berhasil dibagikan ke viewer atau hanya tersimpan lokal. Viewer perlu memuat ulang halaman setelah perubahan disimpan.

## Catatan integrasi

Login Google dan profil pengguna memakai Supabase. Inventaris, anggaran, pengadaan, jasa, mutasi, dan pemeliharaan dibaca/ditulis ke tabel operasional Supabase yang sudah ada; akun viewer hanya membaca. Penerimaan, penggunaan, stock opname, dan penghapusan belum memiliki tabel/kolom penyimpanan pada schema saat ini sehingga tetap lokal per browser dan tidak ikut tampil lintas akun. Endpoint `/api/...` tetap tercantum untuk integrasi backend lain, tetapi bukan penyimpanan yang dipakai oleh modul operasional ini.

Jangan mengaktifkan kredensial contoh atau menyimpan password di HTML, JavaScript, SQL, atau localStorage.
