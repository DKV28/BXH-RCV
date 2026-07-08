# Thư mục ảnh áp phích

Đặt **file ảnh áp phích** vào đây (jpg/png/webp) để phục vụ qua CDN của GitHub Pages
— cách này chịu được vài nghìn người xem mà không tốn băng thông Supabase.

## Cách làm (khuyến nghị cho sự kiện đông người)

1. Nén ảnh về khoảng **1200–1400px, ~100–200KB/ảnh** (dùng https://squoosh.app hoặc bất kỳ công cụ nào).
2. Trên GitHub, vào thư mục này → **Add file → Upload files** → kéo thả các ảnh → **Commit**.
3. Trong `admin.html`, khi thêm/sửa áp phích, dán **đường dẫn** vào ô link ảnh, ví dụ:
   ```
   assets/posters/ap-phich-01.jpg
   ```
   (dùng đường dẫn tương đối như trên; KHÔNG cần link đầy đủ)

Ảnh sẽ được trình duyệt và CDN cache lại → mỗi người chỉ tải 1 lần, rất nhẹ.

> Nút "tải ảnh lên" trong admin (nhúng thẳng vào database) chỉ nên dùng cho sự kiện ít người.
> Với 5000–7000 người, hãy dùng cách đặt file ở đây.
