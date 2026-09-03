# DeleteVNG Valorant (VALORANT VNG Logo Manager) 🚀

![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Windows-0078D6.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**DeleteVNG Valorant** là công cụ tự động hóa siêu nhẹ được phát triển bằng AutoHotkey v2, giúp người chơi VALORANT tại Việt Nam tự động dọn dẹp các tệp tin Logo/Splash Screen của nhà phát hành VNG mỗi khi mở game. Nhờ đó, game sẽ khởi động thẳng vào giao diện chính nhanh hơn và mượt mà hơn.

---

## ✨ Tính năng nổi bật

- ⚡ **Tự động hóa hoàn toàn (Automation):** Tự động phát hiện khi tiến trình VALORANT khởi chạy và xóa các tệp logo VNG ngay lập tức.
- ⏱️ **Tùy chỉnh thời gian hoãn (Launch Delay):** Cho phép đặt độ trễ (delay seconds) trước khi xóa file để đảm bảo tính ổn định trên mọi cấu hình máy.
- 🎨 **Quản lý Theme thông minh (Dark / Light / Auto):**
  - Mặc định **Auto-Detect** tự động chuyển màu sắc giao diện theo chuẩn Theme của Windows (Light / Dark Mode).
  - Cho phép người dùng chuyển đổi thủ công giữa `⚙ Auto`, `🌙 Dark Mode` và `☀️ Light Mode`.
- 🚀 **Khởi động cùng Windows & Chạy ngầm (System Tray):**
  - Hỗ trợ tùy chọn tự động mở cùng hệ điều hành.
  - Thu nhỏ xuống khay hệ thống (Tray Icon) giúp màn hình làm việc luôn gọn gàng.
- 🔄 **Tự động kiểm tra bản cập nhật (Auto-Update Check):** Tự động kiểm tra phiên bản mới từ GitHub Releases qua kết nối HTTP bất đồng bộ không gây giật lag.
- 🔔 **Thông báo Toast nhẹ nhàng:** Thay thế toàn bộ hộp thoại thông báo cắt ngang bằng Toast (`TrayTip`) góc màn hình.
- 🧹 **Tối ưu tài nguyên cực tốt:** Sử dụng cơ chế bất đồng bộ (Non-blocking Timer) và giải phóng RAM tự động (`EmptyWorkingSet`), chiếm dưới **10 MB RAM**.

---

## 📂 Các tệp tin được xử lý

Ứng dụng sẽ dọn dẹp 4 tệp tin logo VNG trong thư mục `...\VALORANT\live\ShooterGame\Content\Paks`:
- `VNGLogo-WindowsClient.pak`
- `VNGLogo-WindowsClient.sig`
- `VNGLogo-WindowsClient.ucas`
- `VNGLogo-WindowsClient.utoc`

---

## 🛠️ Hướng dẫn cài đặt & Sử dụng

### Dành cho người dùng (File .exe)
1. Tải về phiên bản mới nhất từ mục **[Releases](../../releases)**.
2. Giải nén và chạy tệp `DeleteVNGValorant.exe` dưới quyền Administrator.
3. Chọn đường dẫn thư mục `Paks` của VALORANT (nếu ứng dụng chưa tự phát hiện).
4. Nhấn **Minimize to tray** hoặc đóng cửa sổ, ứng dụng sẽ tự chạy ngầm và xử lý khi bạn bật game.

### Dành cho Lập trình viên (Chạy từ Mã nguồn)
1. Cài đặt **[AutoHotkey v2.0](https://www.autohotkey.com/)** hoặc mới hơn.
2. Tải mã nguồn `.ahk` từ Repository này.
3. Chạy trực tiếp tệp script `.ahk`.

---

## 🛡️ Yêu cầu hệ thống

- **HĐH:** Windows 10 / Windows 11 (64-bit).
- **Quyền:** Quyền Quản trị viên (Administrator) để xóa file trong thư mục ổ đĩa Game.

---

## 📜 Giấy phép (License)

Dự án được phân phối dưới giấy phép [MIT License](LICENSE).
