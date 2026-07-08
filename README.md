# Web bình chọn áp phích – RCV WPSD 2026

Web app trọn gói **vừa bình chọn vừa xem kết quả real-time** cho ngày Rung Chuông Vàng
(WPSD 2026, 10/9/2026). Nhân viên nhập **mã nhân viên + tên**, chọn tối đa 3 áp phích;
kết quả lên leaderboard (podium + bar race) ngay lập tức. Dữ liệu lưu trên **Supabase**.

Không cần Google Form/Sheet, không backend riêng — chỉ HTML tĩnh + Supabase.

## Các trang

| File | Vai trò | Ai dùng |
|---|---|---|
| `index.html` | **Bình chọn** — nhập mã + tên, chọn ≤3 áp phích, gửi; nhập lại mã để sửa | Nhân viên |
| `board.html` | **Leaderboard real-time** (podium + bar race) | Màn hình lớn |
| `admin.html` | **Quản trị** — áp phích, mở/đóng bình chọn, danh sách NV, kết quả cuối | Ban tổ chức |

## Cách hoạt động (kiến trúc)

```
index.html / board.html / admin.html  (HTML tĩnh, @supabase/supabase-js, ANON KEY)
        │   mọi ghi/đọc nhạy cảm đi qua RPC SECURITY DEFINER
        ▼
Supabase Postgres + Realtime
  posters · votes · vote_selections · settings · staff_roster · app_secrets
```

- **Danh tính phiếu:** nhân viên nhập **mã + họ tên**; phải **khớp danh sách nhân viên** đã upload
  mới được vote (sai mã hoặc sai tên → báo lỗi ngay, đối chiếu bỏ dấu & không phân biệt hoa thường).
  Mỗi mã chiếm 1 phiếu và **sửa được** lựa chọn đến khi ban tổ chức đóng bình chọn.
- **Bắt buộc:** upload danh sách nhân viên **trước khi mở bình chọn** (nếu chưa có, mọi người bị
  báo "mã không có trong danh sách"). Có thể xem lại kết quả đã đối chiếu bất cứ lúc nào ở admin.
- **Bảo mật:** RLS bật mọi bảng; anon **không** đọc trực tiếp `votes`/`staff_roster`. Board chỉ
  nhận số liệu tổng hợp qua `get_results()` → không lộ tên/mã người vote. Admin bảo vệ bằng passphrase.
- **Real-time:** board nghe thay đổi `vote_selections` qua Supabase Realtime + polling dự phòng 15s;
  mất mạng thì giữ nguyên số cũ trên màn hình.

## Cài đặt (một lần)

### 1. Tạo project Supabase
- Vào <https://supabase.com> → New project.
- **Project Settings → API**, copy `Project URL` và `anon public` key.

### 2. Cấu hình client
Mở `assets/config.js`, điền:
```js
SUPABASE_URL: "https://<project>.supabase.co",
SUPABASE_ANON_KEY: "<anon public key>",
```
> Chỉ dùng **anon public** key. Tuyệt đối không đặt `service_role` key vào đây.

### 3. Tạo database
- Mở `db/schema.sql`, **đổi `CHANGE_ME_admin_pass`** thành mật khẩu quản trị của bạn.
- Supabase → **SQL Editor → New query** → dán toàn bộ `db/schema.sql` → **Run**.
- Đổi mật khẩu sau này:
  ```sql
  update public.app_secrets
  set admin_hash = extensions.crypt('mat_khau_moi', extensions.gen_salt('bf')) where id = 1;
  ```

### 4. Bật Realtime (nếu chưa)
Schema đã tự thêm `vote_selections` vào publication `supabase_realtime`. Nếu bản Supabase của bạn
cần bật thủ công: **Database → Replication → `supabase_realtime`** → thêm bảng `vote_selections`.
(Không bật cũng chạy — board sẽ dùng polling 15s.)

### 5. Nhập áp phích + danh sách nhân viên qua admin
Mở `admin.html` → nhập passphrase, rồi làm theo thứ tự:
1. Mục **Áp phích**: nhập tên, **tải ảnh lên** (chọn file — ảnh tự động nén tối đa 1400px cho nhẹ)
   *hoặc* dán link ảnh → xem trước → **Thêm**. Có thể **Sửa / Ẩn / Xoá** sau đó.
   - Nhiều áp phích (60–100): mở **➕ Thêm hàng loạt**, dán mỗi dòng `Tên | assets/posters/anh.jpg`
     (dán 2 cột từ Excel được) → **Thêm tất cả**.
2. Mục **Danh sách nhân viên**: **chọn file Excel (.xlsx) hoặc CSV** — cột 1 là mã, cột 2 là họ tên
   (có dòng tiêu đề cũng được, sẽ tự bỏ) — hoặc dán trực tiếp `mã,tên`. Xem lại rồi bấm **Tải lên danh sách**.
   ⚠️ **Bắt buộc làm trước khi mở bình chọn**, vì nhân viên phải khớp danh sách này mới vote được.
3. Bấm **Mở bình chọn**.

> Ảnh được lưu thẳng trong database (dưới dạng data URI đã nén) nên **không cần cấu hình Supabase Storage**.
> Người bình chọn bấm 🔍 trên mỗi áp phích để xem phóng to trước khi chọn.
> Với cuộc thi rất nhiều/ảnh rất lớn, có thể chuyển sang Supabase Storage — nhưng cách nhúng DB này đủ dùng
> và không phải mở quyền upload công khai.

### 6. Deploy
Đẩy toàn bộ thư mục (tĩnh) lên **Netlify / Vercel / GitHub Pages**. Sau đó:
- Chiếu `board.html` lên màn hình lớn.
- Phát link `index.html` (kèm QR nếu muốn) cho nhân viên bình chọn.

Có thể mở thẳng bằng Chrome từ máy để thử, nhưng nên deploy để nhiều người truy cập.

## Cuối ngày – chốt kết quả

Vì phiếu đã được đối chiếu danh sách ngay lúc bình chọn nên kết quả trên `board.html` chính là kết quả chính thức.
Để lưu lại:
1. Trong `admin.html` bấm **Đóng bình chọn**.
2. Mục **Kết quả CUỐI** → **Tính kết quả cuối** → **Export CSV** (đồng thời rà lại nếu bạn có chỉnh sửa danh sách sau đó).

## Cấu trúc file

```
index.html        trang bình chọn
board.html        leaderboard real-time
admin.html        trang quản trị
assets/config.js  SUPABASE_URL / ANON_KEY (điền tay)
assets/styles.css style chung (cam/vàng WPSD)
assets/vendor/supabase.js  thư viện @supabase/supabase-js (đóng gói sẵn, không cần CDN)
assets/vendor/xlsx.full.min.js  thư viện đọc Excel (chỉ dùng ở admin)
assets/posters/   nơi đặt file ảnh áp phích (phục vụ qua CDN)
db/schema.sql     toàn bộ bảng + RLS + RPC + realtime
```

> Thư viện Supabase được nhúng sẵn trong `assets/vendor/` nên web **không phụ thuộc CDN ngoài** khi
> chạy — an toàn cho mạng nội bộ/hội trường có thể chặn CDN.

## Quy mô lớn (5000–7000 người) — chống quá tải

Đã kiểm thử ở đúng quy mô này. Các điểm cần lưu ý:

1. **Ảnh áp phích — quan trọng nhất.** Với vài nghìn người, **KHÔNG nhúng ảnh vào database**
   (mỗi người sẽ kéo vài MB qua API Supabase → vượt hạn mức egress 5GB/tháng của gói free).
   Thay vào đó đặt file ảnh trong `assets/posters/` (xem README trong thư mục đó) và dán đường
   dẫn — ảnh phục vụ qua **CDN GitHub Pages**, được cache, mỗi người tải 1 lần. Băng thông
   GitHub Pages ~100GB/tháng, thừa sức.
2. **Bảng xếp hạng (`board.html`) chỉ chiếu trên màn hình lớn** (vài máy). Trang này dùng
   Supabase Realtime — gói free giới hạn ~200 kết nối realtime đồng thời, nên **đừng phát link
   board cho hàng nghìn điện thoại**. Nhân viên chỉ cần trang vote (`index.html`, không dùng
   realtime). Board đã throttle: lúc cao điểm chỉ cập nhật tối đa ~1 lần/3 giây + polling 15s.
3. **Ghi phiếu & đếm phiếu rất nhẹ.** `cast_vote` tra cứu bằng khoá chính (có index); `get_results`
   tổng hợp ~21.000 lượt chọn chỉ mất ~6ms. Postgres/Supabase free thừa sức cho 7000 phiếu.
4. **Danh sách nhân viên 7000 dòng** upload 1 lần bình thường (đã test). Dán thẳng từ Excel.
5. Nếu muốn dư dả tuyệt đối (nhiều màn hình xem, biên độ an toàn cao), nâng Supabase lên gói Pro
   (~$25/tháng) là đủ — nhưng với cách đặt ảnh trên CDN ở trên thì gói **free vẫn chạy tốt**.

## Ghi chú bảo mật

- Nhân viên phải nhập đúng **mã + họ tên khớp danh sách** mới vote được (đối chiếu ngay lúc bình chọn);
  mã cũng là "mật khẩu cá nhân" để sửa lại phiếu của chính mình.
- `anon` key là public (nằm trong HTML) — an toàn vì RLS chặn truy cập bảng nhạy cảm và mọi ghi
  đi qua RPC có kiểm tra. Passphrase admin được lưu dạng hash bcrypt (`pgcrypto`).
- Muốn chắc hơn cho admin: có thể thay passphrase bằng Supabase Auth (email magic link) cho 1 tài khoản
  ban tổ chức — cần chỉnh RLS/RPC tương ứng.
