# Student Rating (Flutter + Supabase)

Port aplikasi penilaian siswa dari Java Swing ke Flutter dengan backend Supabase, menggunakan metode SAW untuk ranking.

## Setup

1. Buat project Supabase, lalu jalankan skrip `supabase/schema.sql` di SQL editor Supabase untuk membuat tabel dan policy.
2. Ambil `Project URL` dan `Anon Public Key` dari Supabase dashboard, lalu ganti nilai pada `lib/supabase_options.dart`.
3. Install dependency: `flutter pub get`.
4. Jalankan aplikasi: `flutter run` (atau `flutter run --dart-define=SUPABASE_KEY=...` jika mau override key).

## Fitur yang sudah ada
- Autentikasi email/password Supabase.
- CRUD siswa dan kriteria.
- Input nilai per siswa per kriteria (K1..K5).
- Perhitungan SAW (normalisasi benefit/cost, bobot kriteria) dan ranking.

## Struktur utama
- `lib/ui/screens/` : layar Login, Home, Siswa, Kriteria, Penilaian, Ranking.
- `lib/data/models/` : model entity (student, criteria, rating, dll).
- `lib/data/services/` : akses Supabase.
- `lib/logic/profile_matching.dart` : rumus hitung SAW & ranking.
- `supabase/schema.sql` : definisi tabel siswa + RLS policy dasar.

Sesuaikan desain/tata letak sesuai kebutuhan, dan tambahkan export PDF jika diperlukan (bisa pakai paket `pdf` Flutter).
