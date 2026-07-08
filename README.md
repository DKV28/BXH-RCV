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

- **Danh tính phiếu:** mỗi mã nhân viên chiếm 1 phiếu (khoá lại). Chủ mã **sửa được** lựa chọn
  đến khi ban tổ chức đóng bình chọn (mã đóng vai "mật khẩu cá nhân").
- **Lúc sự kiện:** đếm mọi phiếu có mã chưa dùng. **Cuối ngày:** đối chiếu (mã + tên) với
  danh sách nhân viên chính thức để lọc phiếu hợp lệ (bỏ dấu, không phân biệt hoa thường).
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

### 5. Nhập nội dung qua admin
Mở `admin.html` → nhập passphrase → **thêm áp phích** (tên + link ảnh) → **Mở bình chọn**.

### 6. Deploy
Đẩy toàn bộ thư mục (tĩnh) lên **Netlify / Vercel / GitHub Pages**. Sau đó:
- Chiếu `board.html` lên màn hình lớn.
- Phát link `index.html` (kèm QR nếu muốn) cho nhân viên bình chọn.

Có thể mở thẳng bằng Chrome từ máy để thử, nhưng nên deploy để nhiều người truy cập.

## Cuối ngày – chốt kết quả

1. Trong `admin.html`, mục **Danh sách nhân viên**: dán CSV `mã,tên` (mỗi dòng 1 người) → **Tải lên**.
2. Bấm **Đóng bình chọn**.
3. Bấm **Tính kết quả cuối** → xem kết quả đã đối chiếu + danh sách phiếu bị loại → **Export CSV**.

## Cấu trúc file

```
index.html        trang bình chọn
board.html        leaderboard real-time
admin.html        trang quản trị
assets/config.js  SUPABASE_URL / ANON_KEY (điền tay)
assets/styles.css style chung (cam/vàng WPSD)
db/schema.sql     toàn bộ bảng + RLS + RPC + realtime
```

## Ghi chú bảo mật

- Mã nhân viên là "mật khẩu cá nhân" cho việc sửa phiếu — phù hợp sự kiện nội bộ 1 ngày, đã có
  đối chiếu roster cuối ngày để lọc phiếu gian lận/nhầm.
- `anon` key là public (nằm trong HTML) — an toàn vì RLS chặn truy cập bảng nhạy cảm và mọi ghi
  đi qua RPC có kiểm tra. Passphrase admin được lưu dạng hash bcrypt (`pgcrypto`).
- Muốn chắc hơn cho admin: có thể thay passphrase bằng Supabase Auth (email magic link) cho 1 tài khoản
  ban tổ chức — cần chỉnh RLS/RPC tương ứng.
