# Chạy bản đã sửa

Ứng dụng hiện mở màn hình đăng nhập và yêu cầu SMS OTP trước khi vào các tab. Cần chạy backend và cấu hình Twilio Trial theo [HUONG_DAN_OTP.md](HUONG_DAN_OTP.md). Không có mã OTP cố định; nhận SMS thật cần tài khoản Twilio của bạn.

Project cần mở: `D:\hoang_cong_duc`. Không chạy bản cũ ở `D:\Download\Laptrinhmobile\hoang_cong_duc`.

Trong Android Studio, mở thư mục gốc project rồi chạy cấu hình Flutter `lib/main.dart` trên điện thoại. Dừng phiên chạy cũ và chạy lại hoàn toàn vì có thay đổi AndroidManifest / thư viện native.

Hoặc chạy PowerShell:

```powershell
cd D:\hoang_cong_duc
$env:ANDROID_HOME = 'D:\Androi Studio - Git - Flutter SDK\Sdk'
& 'D:\Androi Studio - Git - Flutter SDK\Flutter\bin\flutter.bat' run
```

## Kiểm tra trên điện thoại

1. Có 6 tab: Nhiệt độ, Đơn vị, Báo thức, Dịch thuật, Cá nhân, Nhóm.
2. Cá nhân: nút điện thoại mở trình quay số; YouTube mở app nếu đã cài, nếu không mở web.
3. Báo thức: cấp quyền micro, nói `7 giờ 30 sáng`. Chuyển ngôn ngữ English và nói `seven thirty PM`. Kiểm tra giờ nhận diện rồi bấm đặt, xác nhận trong Đồng hồ. Báo thức được quản lý bởi ứng dụng Đồng hồ, không chỉ một thông báo trong Flutter.
4. Dịch thuật: cần Internet lần đầu để tải model. Dịch `Hello` từ English sang Tiếng Việt, sau đó thử nhận giọng nói và ảnh rõ chữ. OCR hỗ trợ chữ Latin (Việt, Anh, Pháp, Đức, Tây Ban Nha).
5. Camera: cấp quyền camera, hướng vào chữ. Chữ nhận diện và bản dịch tự cập nhật liên tục theo ảnh chụp mỗi lượt, khoảng 1–3 giây tùy thiết bị. Rời tab hoặc đưa app xuống nền sẽ dừng camera.
6. Nhóm: vuốt ngang qua 4 thành viên. Thay dữ liệu mẫu trong `lib/screens/group_info_screen.dart`; trường `avatarUrl` có thể dùng ảnh trong `images/`.

## Phạm vi kiểm chứng

Kiểm tra tự động phân tích giờ Việt/Anh, chuyển tab và vuốt thành viên. Build APK kiểm tra khả năng biên dịch Android. Các chức năng phụ thuộc dịch vụ nhận giọng nói, camera, Google ML Kit, ứng dụng Đồng hồ và YouTube cần thử thực tế trên điện thoại.

Bản sao lưu trước khi sửa: `D:\hoang_cong_duc-backup-20261008-213037`.
