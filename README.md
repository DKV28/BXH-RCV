# Web Leaderboard Bình chọn Áp phích – RCV WPSD 2026

Màn hình leaderboard real-time chiếu lên màn hình lớn trong ngày Rung Chuông Vàng
(WPSD 2026, 10/9/2026). Nhân viên bình chọn áp phích qua Google Form → dữ liệu về
Google Sheet → web đọc CSV liên tục và hiển thị podium + bar race.

## Cách hoạt động

```
Google Form (mã kim cương + chọn áp phích)
        │
        ▼
Sheet 1 – RAW (private): raw votes + validation, tính trọng số CB=1 / LD=3
        │
        ▼
Sheet 2 – KẾT QUẢ (published CSV): 2 cột "Tên áp phích | Tổng điểm"
        │
        ▼
index.html (tĩnh) polling CSV mỗi 15s → podium + bar race
```

Web **chỉ đọc Sheet 2** (2 cột kết quả đã tính). Không backend, không API key —
mở `index.html` bằng Chrome là chạy.

## Cấu hình (1 lần)

1. Tab kết quả trong Google Sheet: đúng 2 cột `Tên áp phích` | `Tổng điểm`,
   cột điểm kéo từ sheet raw bằng công thức / `IMPORTRANGE`.
2. `File → Share → Publish to web` → chọn đúng tab → định dạng
   **Comma-separated values (.csv)** → **Publish**.
3. Copy link CSV, mở `index.html`, dán vào 4 hằng số đầu phần `<script>`:

   ```js
   const CSV_URL = "";            // link CSV published của Sheet 2
   const REFRESH_SECONDS = 15;    // chu kỳ làm mới
   const NAME_COL = 0;            // cột tên áp phích (0-based)
   const SCORE_COL = 1;           // cột tổng điểm (0-based)
   ```

4. Lưu lại và mở bằng Chrome. Web tự làm phần còn lại.

Nếu chưa dán `CSV_URL`, trang sẽ hiện màn hình hướng dẫn thay vì màn hình trống.

## Tính năng

- **Podium Top 3**: hạng 1 ở giữa & cao hơn, vàng/bạc/đồng, hiện tên + điểm.
- **Bar race đầy đủ**: mọi áp phích, thanh chạy theo % so với điểm cao nhất,
  tự sắp xếp lại thứ hạng mỗi lần cập nhật, hạng 1 tô vàng.
- **Trạng thái kết nối**: chấm xanh (ok) / đỏ (mất kết nối), thời gian cập nhật,
  tổng điểm.
- **Tự làm mới** mỗi 15s, chống cache bằng `_t=Date.now()`.
- **Mất mạng giữ số cũ**, không xóa màn hình.
- **Responsive**: xem tốt trên màn hình lớn lẫn điện thoại.

## Giới hạn đã biết

- Google published CSV trễ cache **~1–5 phút** phía Google → không real-time
  tuyệt đối (chấp nhận được cho use-case bình chọn áp phích).

## Thương hiệu

Cam WPSD `#F26A21` · nền tối `#0e1524` · vàng `#FFD24C`. Có thể thêm logo bệnh
viện, QR code dẫn tới Form, đổi màu/layout sau.
