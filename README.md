# Ứng dụng Flutter – Hoàng Công Đức

Đồ án gồm chuyển đổi nhiệt độ/đơn vị, báo thức giọng nói, dịch thuật Google ML Kit, thông tin cá nhân/nhóm và xác thực tài khoản bằng mật khẩu kết hợp SMS OTP Twilio Verify.

## Mã nguồn và tài liệu cài đặt

Repository: https://github.com/duc19742-dotcom/hoangcongduc-laptrinhdidong.git

- [Hướng dẫn cài đặt đầy đủ (Git)](docs/HUONG_DAN_CAI_DAT.md).
- [Tài liệu Word để nộp đồ án](docs/HUONG_DAN_CAI_DAT.docx).
- [Hướng dẫn SMS OTP](HUONG_DAN_OTP.md).
- [Ghi chú chạy trên máy hiện tại](HUONG_DAN_CHAY.md).

## Chạy nhanh

Yêu cầu Flutter có Dart tương thích ^3.13.5, Android SDK Platform 36 và Node.js 24 trở lên. Thêm Flutter và Android platform-tools vào PATH trước khi chạy các lệnh.

Tải mã nguồn:

```powershell
git clone https://github.com/duc19742-dotcom/hoangcongduc-laptrinhdidong.git
cd hoangcongduc-laptrinhdidong
flutter pub get
```

Terminal 1 (backend):

```powershell
cd backend
if (!(Test-Path .env)) { Copy-Item .env.example .env }
notepad .env
# Điền khóa Twilio, số nhận đã xác minh và lưu file.
node --env-file=.env server.mjs
```

Terminal 2 (thư mục gốc, Android đã kết nối ADB):

```powershell
adb devices
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Giữ cả hai terminal hoạt động. SIM nhận OTP có thể nằm trong iPhone. Xem hướng dẫn đầy đủ để cài SDK, chạy emulator, dùng mạng LAN hoặc đưa bản mã nguồn mới lên GitHub.

## Cấu trúc mã nguồn

| Đường dẫn | Vai trò |
| --- | --- |
| lib/main.dart | Khởi động và điều hướng xác thực |
| lib/screens/ | Giao diện đăng ký, OTP và các chức năng đồ án |
| lib/services/auth_service.dart | Gọi API xác thực |
| backend/server.mjs | Tài khoản, SQLite và Twilio Verify |
| backend/.env.example | Mẫu cấu hình không chứa khóa thật |
| test/ và backend/server.test.mjs | Kiểm tra tự động |
| docs/ | Tài liệu Markdown và Word |

## Kiểm tra

```powershell
flutter analyze
flutter test
cd backend
node --test
```

Test tự động không gửi SMS. Không đưa backend/.env, backend/data hoặc Auth Token lên Git. APK demo vẫn cần backend đang chạy.
