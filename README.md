# DeleteVNG Valorant 🚀

![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Windows-0078D6.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**DeleteVNG Valorant** là công cụ tự động hóa siêu nhẹ được viết bằng AutoHotkey v2, giúp tự động thực hiện thủ thuật xóa file logo VNG ngay khi game VALORANT vừa khởi chạy. Công cụ giúp bỏ qua màn hình logo VNG, hỗ trợ mở game nhanh hơn và bật hiệu ứng **máu vàng**.

---

## 💡 Ý tưởng (Credits)

Ứng dụng này được phát triển dựa trên mẹo thủ công được chia sẻ bởi YouTuber **Leminh**:
- **Video gốc:** [(VALORANT) CÁCH HIỆN MÁU VÀNG + TẮT LOGO VNG KHÔNG DÙNG PHẦN MỀM THỨ 3](https://www.youtube.com/watch?v=dQ7plD9cv3I)
- **Tác giả:** Leminh

### 📌 Nguyên lý hoạt động từ Video:
1. Mở thư mục cài đặt game tại đường dẫn `...\VALORANT\live\ShooterGame\Content\Paks` [00:00:26].
2. Bấm nút **Play** trên Riot Client [00:00:42].
3. Ngay khi nút Play chuyển trạng thái sang *Playing* hoặc cửa sổ khởi động xuất hiện, lập tức xóa 4 file logo VNG (`VNGLogo-WindowsClient.*`) [00:00:49].
4. **Kết quả:** Bỏ qua Logo nhà phát hành VNG và kích hoạt thành công hiệu ứng máu vàng trong game [00:01:00].

👉 **Ứng dụng này giúp bạn tự động canh thời điểm chuẩn xác và dọn dẹp file tự động mỗi khi mở game mà không cần phải thao tác thủ công phức tạp!**

---

## ✨ Tính năng nổi bật

- ⚡ **Tự động hóa 100%:** Phát hiện tiến trình game khởi chạy và tự động xóa 4 file logo VNG tức thì.
- 🩸 **Hiện máu vàng & Tắt Logo VNG:** Tự động áp dụng thủ thuật giúp vào game nhanh hơn và hiển thị hiệu ứng máu vàng.
- ⏱️ **Tùy chỉnh Launch Delay:** Cho phép tùy chỉnh độ trễ (0s, 1s...) phù hợp với từng cấu hình máy.
- 🚀 **Chạy ngầm & Khởi động cùng Windows:**
  - Thu nhỏ xuống khay hệ thống (System Tray).
  - Tự động bật cùng hệ điều hành.
- 🔄 **Auto-Update Check:** Tự động kiểm tra bản cập nhật mới nhất từ GitHub qua kết nối bất đồng bộ.


---

## 📂 Các tệp tin được xử lý

Công cụ sẽ dọn dẹp 4 tệp tin trong thư mục `...\ShooterGame\Content\Paks` [00:00:26]:
- `VNGLogo-WindowsClient.pak`
- `VNGLogo-WindowsClient.sig`
- `VNGLogo-WindowsClient.ucas`
- `VNGLogo-WindowsClient.utoc`

---

## 🛠️ Hướng dẫn cài đặt & Sử dụng

### Dành cho người dùng (File .exe)
1. Tải về phiên bản mới nhất tại mục **[Releases](../../releases)**.
2. Giải nén và chạy tệp `DeleteVNGValorant.exe` dưới quyền **Administrator**.
3. Đảm bảo đường dẫn thư mục `Paks` chính xác.
4. Tích chọn **Minimize to tray** & **Start with Windows** để ứng dụng tự động chạy ngầm xử lý mỗi khi bạn bật game.

### Dành cho Lập trình viên
1. Cài đặt môi trường **[AutoHotkey v2.0+](https://www.autohotkey.com/)**.
2. Chạy trực tiếp script `DeleteVNGValorant.ahk`.

---

## 🛡️ Yêu cầu hệ thống

- **HĐH:** Windows 10 / Windows 11 (64-bit).
- **Quyền:** Administrator (để cấp quyền xóa file trong thư mục ổ đĩa game).

---

## 📜 Giấy phép (License)

Dự án được phân phối dưới giấy phép [MIT License](LICENSE).  
*Special thanks to YouTuber **Leminh** for the original trick idea!*
