# TÀI LIỆU HƯỚNG DẪN CÀI ĐẶT

Ứng dụng Flutter – Hoàng Công Đức

Phiên bản: 1.0.0+1 | Ngày biên soạn: 15/10/2026

Repository: https://github.com/duc19742-dotcom/hoangcongduc-laptrinhdidong.git

Phạm vi: lấy mã nguồn từ Git, cài môi trường Windows, cấu hình Twilio Trial, chạy backend và ứng dụng Android, kiểm thử và xử lý lỗi. Bản Word cùng tên được xuất từ tài liệu này.

## 1. Tổng quan

Ứng dụng có sáu tab: Nhiệt độ, Đơn vị, Báo thức, Dịch thuật, Cá nhân và Nhóm. Người dùng cần hoàn tất xác thực để vào màn hình chính.

Đăng ký: nhập họ tên, tài khoản, số điện thoại và mật khẩu → backend lưu tài khoản → gửi SMS OTP qua Twilio → nhập đúng mã → vào ứng dụng.

Đăng nhập: tài khoản và mật khẩu → backend kiểm tra → SMS OTP đến số đã gắn với tài khoản → backend xác minh → cấp phiên đăng nhập. Khóa Twilio nằm trên backend; Flutter không giữ Auth Token. SQLite lưu tài khoản và mật khẩu băm bằng scrypt với salt riêng.

## 2. Môi trường cần chuẩn bị

| Thành phần | Yêu cầu |
| --- | --- |
| Hệ điều hành | Hướng dẫn dùng Windows và PowerShell |
| Git | Git for Windows, lệnh git dùng được trong terminal |
| Flutter/Dart | Dart tương thích ^3.13.5 theo pubspec.yaml; bản đã build: Flutter 3.47.6, Dart 3.13.5 |
| Android Studio | Cài Flutter/Dart plugin, dùng JDK đi kèm Android Studio |
| Android SDK | SDK Platform 36, Build-Tools, Platform-Tools, Command-line Tools, CMake và NDK theo cấu hình Flutter |
| Node.js | 24 trở lên; bản đã kiểm tra: 24.19.0 |
| Thiết bị | Android thật hoặc emulator; demo đã chạy trên OPPO CPH2557 API 35 |
| OTP | Twilio Trial còn hiệu lực và hạn mức, số nhận đã xác minh |
| Kết nối | Máy tính có Internet để gọi Twilio; Android truy cập được backend |

Phạm vi nghiệm thu là Android. Các thư mục iOS, web và desktop có trong mã nguồn nhưng chưa được kiểm chứng đầy đủ với các plugin của đồ án.

### 2.1. Cài và kiểm tra công cụ

Tải công cụ từ các trang chính thức ở mục 11. Trong Android Studio → SDK Manager, cài các gói Android SDK bên trên. Thêm thư mục bin của Flutter và thư mục platform-tools của Android SDK vào PATH; mở terminal mới:

```powershell
git --version
node --version
flutter --version
adb version
flutter doctor -v
flutter doctor --android-licenses
```

Khắc phục các lỗi Android toolchain trong flutter doctor. Nếu chỉ chạy Android thì không cần thiết lập Visual Studio cho Windows desktop.

### 2.2. Đường dẫn trên máy thực hiện đồ án

Nếu chưa thiết lập PATH, dùng biến PowerShell cho phiên terminal hiện tại:

```powershell
$flutterExe = 'D:\Androi Studio - Git - Flutter SDK\Flutter\bin\flutter.bat'
$adbExe = 'D:\Androi Studio - Git - Flutter SDK\Sdk\platform-tools\adb.exe'
& $flutterExe doctor -v
& $adbExe devices
```

Trong các lệnh tiếp theo, thay flutter bằng & $flutterExe và adb bằng & $adbExe nếu cần. Trên máy khác, sửa đường dẫn theo nơi cài thực tế. Node.js 24 đã có trên máy thực hiện đồ án.

## 3. Lấy mã nguồn từ Git và mở dự án

Người nhận mã nguồn chạy:

```powershell
git clone https://github.com/duc19742-dotcom/hoangcongduc-laptrinhdidong.git
cd hoangcongduc-laptrinhdidong
flutter pub get
```

Điều kiện: chủ dự án đã push mã nguồn lên repository. Nếu clone báo repository rỗng hoặc không có pubspec.yaml, cần hoàn thành mục 9 trước. Không clone đè vào thư mục đang làm việc. Nếu đã có bản mã nguồn ở D:\hoang_cong_duc thì mở trực tiếp thư mục đó.

Trong Android Studio, chọn Open → thư mục gốc chứa pubspec.yaml, lib và android. Không chỉ mở riêng thư mục android. Chọn đúng Flutter SDK và cấu hình lib/main.dart. Các lệnh ở các mục sau thực hiện tại thư mục gốc vừa clone, trừ khi có chỉ dẫn cd backend.

## 4. Cấu hình SMS OTP qua Twilio Trial

### 4.1. Lấy dịch vụ Trial có sẵn

1. Đăng ký hoặc đăng nhập Twilio Console, xác minh email và số điện thoại.
2. Mở Identity → Verify → Overview → Try out Verify.
3. Chọn SMS hoặc SMS & RCS theo giao diện; gửi mã thử và nhập mã nhận được để xác nhận.
4. Trong REQUEST, lấy riêng chuỗi Service SID bắt đầu bằng VA trong đường dẫn /Services/VA.../Verifications hoặc /VerificationCheck. Chuỗi VE trong RESPONSE là mã lượt xác minh, không phải Service SID.
5. Lấy Account SID bắt đầu bằng AC và Auth Token của cùng tài khoản ở Home. Không dùng Test Credentials để gửi SMS thật.

Không tạo dịch vụ riêng qua Services trong gói Trial: thao tác đó yêu cầu nâng cấp. Tài liệu Twilio hướng dẫn dùng Service SID từ request của Try out Verify để gọi API. Nguồn: https://www.twilio.com/docs/usage/trials/try-out-verify.

Trial chỉ gửi đến tối đa 5 số đã xác minh; mẫu SMS cố định. Kiểm tra thời hạn và hạn mức trong Console trước buổi demo. Để thêm số thành viên, dùng mục xác minh người nhận trên giao diện Trial và nhập mã do người giữ số cung cấp. Nguồn: https://www.twilio.com/docs/usage/trials/try-out-verify.

### 4.2. Tạo file môi trường

Từ thư mục gốc:

```powershell
cd backend
if (!(Test-Path .env)) { Copy-Item .env.example .env }
notepad .env
```

Điền thông tin thật vào các chỗ mẫu và lưu:

```dotenv
HOST=0.0.0.0
PORT=3000
TWILIO_ACCOUNT_SID=AC_REPLACE_ME
TWILIO_AUTH_TOKEN=REPLACE_ME
TWILIO_VERIFY_SERVICE_SID=VA_REPLACE_ME
DEMO_ALLOWED_PHONES=+84912345678
```

Số ví dụ 0912345678 được chuẩn hóa thành +84912345678. Nhiều số ngăn cách bằng dấu phẩy; tất cả phải được xác minh trên Twilio trước. Mỗi người nhận mã nguồn tự tạo .env với cấu hình được cấp. Không đưa khóa thật, file .env hoặc dữ liệu tài khoản vào tài liệu nộp hay Git.

## 5. Khởi động backend

Trong terminal thứ nhất, tại backend:

```powershell
node --env-file=.env server.mjs
```

Backend dùng thư viện có sẵn trong Node.js 24, không cần npm install. Kết quả mong đợi: OTP backend listening on port 3000.

Mở http://localhost:3000/health trên trình duyệt máy tính. Kết quả mong đợi: {"ok":true}. Health xác nhận backend hoạt động, không xác nhận gửi SMS thành công. Giữ terminal mở khi chạy app.

Sau khi sửa .env, bấm Ctrl+C rồi chạy lại lệnh trên. Khởi động lại backend làm hết hiệu lực phiên đăng nhập và OTP đang chờ; tài khoản trong SQLite vẫn được giữ.

## 6. Chạy Flutter trên Android

Mở terminal thứ hai ở thư mục gốc chứa pubspec.yaml. Chọn một phương án kết nối dưới đây.

### 6.1. Android thật qua ADB: USB hoặc gỡ lỗi Wi-Fi

Bật Tùy chọn nhà phát triển và Gỡ lỗi USB, cắm cáp, mở khóa điện thoại, chấp nhận hộp thoại cấp quyền. Nếu dùng Wi-Fi, ghép nối thiết bị trong Android Studio và giữ kết nối ADB hoạt động.

```powershell
flutter pub get
adb devices
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

adb devices cần hiển thị trạng thái device. Nếu unauthorized, chấp nhận cấp quyền trên điện thoại. Nếu có nhiều thiết bị, lấy mã từ adb devices / flutter devices và chỉ định:

```powershell
adb -s MA_THIET_BI reverse tcp:3000 tcp:3000
flutter run -d MA_THIET_BI --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

127.0.0.1 truy cập được máy tính nhờ adb reverse. Sau khi ngắt và kết nối lại ADB, có thể cần chạy reverse lại. SIM nhận OTP có thể nằm trong iPhone; đọc mã trên iPhone và nhập vào app Android.

### 6.2. Android Emulator

Khởi động emulator qua Device Manager, giữ backend chạy trên máy tính:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

10.0.2.2 là địa chỉ truy cập máy tính từ Android Emulator; không dùng làm địa chỉ cho máy Android thật.

### 6.3. Android qua địa chỉ IP mạng LAN

Máy tính và Android cùng Wi-Fi. Dùng ipconfig để lấy IPv4 máy tính, ví dụ 192.168.1.10. Cho phép Node.js qua Windows Firewall trên mạng Private nếu được hỏi. Thử mở http://192.168.1.10:3000/health từ trình duyệt điện thoại trước:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

Thay IP ví dụ bằng IP máy tính thực tế. Thay API_BASE_URL cần dừng app rồi chạy lại, không chỉ hot reload.

## 7. Sử dụng và nghiệm thu

1. App mở ở màn hình Đăng nhập, chưa mở các tab chức năng.
2. Chọn Đăng ký. Nhập họ tên, tài khoản 3–30 chữ không dấu/số/dấu gạch dưới, số điện thoại trong danh sách demo, mật khẩu 8–128 ký tự và nhập lại; đồng ý nhận SMS.
3. Bấm Đăng ký và gửi OTP, nhập mã 6 số vừa nhận. Đúng mã mới vào màn hình chính.
4. Mở tab Cá nhân, kiểm tra thông tin tài khoản rồi Đăng Xuất.
5. Đăng nhập lại bằng tài khoản/mật khẩu, nhập OTP để vào ứng dụng.
6. Thử sai mật khẩu, sai OTP: phải báo lỗi và không mở màn hình chính.
7. Thử chuyển đổi nhiệt độ/đơn vị, các tab Cá nhân/Nhóm; cấp quyền micro/camera khi kiểm tra báo thức và dịch thuật.

Backend giới hạn cửa sổ xác minh 5 phút, tối đa 5 lần thử mã; mỗi số chờ 60 giây giữa các lần gửi và tối đa 5 yêu cầu gửi/giờ trong phiên backend. Gửi lại không gia hạn cửa sổ xác minh. Không dùng lại OTP đã xác minh trên web.

Báo thức cần xác nhận trong ứng dụng Đồng hồ Android. Dịch thuật cần Internet lần đầu để tải model; camera/nhận giọng nói cần kiểm tra thực tế. App không lưu phiên qua lần đóng/mở; backend cấp phiên 8 giờ sau OTP đúng.

## 8. Kiểm tra và build APK demo

Tại thư mục gốc:

```powershell
flutter analyze
flutter test
cd backend
node --test
cd ..
flutter build apk --debug --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

APK sinh tại build/app/outputs/flutter-apk/app-debug.apk. APK ví dụ dùng ADB reverse và vẫn cần backend chạy; APK không chứa backend hoặc dịch vụ SMS. Muốn dùng LAN thì build lại với IP máy tính. HTTP nội bộ chỉ bật ở debug; release cần API HTTPS và cấu hình ký phát hành phù hợp.

Test tự động không gửi SMS. Test Flutter kiểm tra điều hướng và luồng OTP; test backend kiểm tra mật khẩu, chặn trước OTP, mã sai/hết hạn, dùng lại mã, giới hạn gửi và đăng xuất. SMS thật cần kiểm tra riêng với Twilio.

## 9. Đưa mã nguồn và tài liệu lên GitHub

Thư mục D:\hoang_cong_duc chưa có .git khi soạn tài liệu. Các lệnh dưới đây dành cho chủ dự án khi chưa khởi tạo Git; nếu đã clone thì dùng Git hiện có. Chưa tự động push mã nguồn trong quá trình tạo tài liệu này.

Tại thư mục gốc:

```powershell
git init
git branch -M main
git config user.name 'TEN_CUA_BAN'
git config user.email 'EMAIL_GIT_CUA_BAN'
git check-ignore backend/.env
git status --short
```

git check-ignore cần in ra backend/.env. Kiểm tra .env.example chỉ có giá trị mẫu. .gitignore cũng loại backend/data, build và các file cấu hình máy cục bộ. Nếu nộp ZIP, tự loại .env và backend/data: .gitignore không có tác dụng khi nén thư mục thủ công.

```powershell
git add README.md .gitignore pubspec.yaml pubspec.lock analysis_options.yaml lib android ios linux macos windows web images test backend docs HUONG_DAN_CHAY.md HUONG_DAN_OTP.md
git diff --cached --stat
git diff --cached --name-only
git diff --cached
```

Danh sách đã stage không được có backend/.env hoặc backend/data. Chỉ commit sau khi đọc nội dung và xác nhận không có khóa thật. Có thể dùng git rm --cached -- backend/.env nếu lỡ stage file đó.

```powershell
git commit -m 'Add Flutter app, OTP backend and installation documents'
git remote add origin https://github.com/duc19742-dotcom/hoangcongduc-laptrinhdidong.git
git ls-remote --heads origin
```

Nếu repository từ xa còn rỗng, chạy:

```powershell
git push -u origin main
```

Nếu đã có nhánh từ xa, kiểm tra lịch sử và đồng bộ trước, không force push ghi đè. Nếu origin đã tồn tại, kiểm tra git remote -v thay vì add lần nữa. Đăng nhập GitHub khi công cụ yêu cầu. Sau khi push, mở repository để kiểm tra README, thư mục backend và tài liệu Word. Có thể xác nhận commit bằng git log -1 và git ls-remote origin HEAD.

## 10. Xử lý lỗi

| Hiện tượng | Cách khắc phục |
| --- | --- |
| Lệnh flutter/adb/node không nhận diện | Kiểm tra PATH, mở terminal mới; dùng đường dẫn đầy đủ ở mục 2.2 |
| Dart SDK không tương thích | Kiểm tra flutter --version, dùng Dart đáp ứng ^3.13.5 |
| Không thấy máy / unauthorized | Kiểm tra quyền gỡ lỗi, cáp hoặc kết nối Wi-Fi |
| Không kết nối được máy chủ | Chạy backend; kiểm tra health, adb reverse hoặc IP LAN/Firewall |
| EADDRINUSE / cổng 3000 đã dùng | Kiểm tra backend đã chạy ở terminal khác; tránh mở hai tiến trình cùng cổng |
| Twilio chưa cấu hình / từ chối yêu cầu | Kiểm tra AC, Auth Token, VA cùng tài khoản, số nhận và hạn mức Trial |
| Số chưa nằm trong danh sách demo | Thêm số +84 vào DEMO_ALLOWED_PHONES, khởi động lại backend |
| Số mới không nhận SMS | Xác minh số trên Twilio trước, kiểm tra Verify Logs và hạn mức |
| Tài khoản hoặc số đã đăng ký | Chuyển sang Đăng nhập, kể cả khi gửi SMS thất bại lúc đăng ký trước |
| OTP hết hạn / nhập sai quá nhiều | Quay lại Đăng nhập và đợi đủ thời gian để xin mã mới |
| Bấm Run trong IDE không gọi được API | Thêm dart-define tương ứng vào Additional run args, chạy adb reverse trước |
| Log có cảnh báo KGP/native access | Nếu vẫn có Built APK thì build thành công; phân biệt với FAILURE làm dừng build |

Không xóa backend/data để sửa lỗi mạng: đây là dữ liệu tài khoản. Thay .env hoặc restart backend không cần đăng ký lại tài khoản cũ.

## 11. Nguồn tham khảo và tài liệu nộp

- Git: https://git-scm.com/downloads/win
- Flutter: https://docs.flutter.dev/install
- Android cho Flutter: https://docs.flutter.dev/platform-integration/android/setup
- Android Studio: https://developer.android.com/studio
- Node.js: https://nodejs.org/en/download
- Twilio Trial: https://www.twilio.com/docs/usage/trials/try-out-verify
- GitHub Docs: https://docs.github.com/en

Nộp URL repository, README, mã nguồn Flutter/backend, backend/.env.example và bản Word docs/HUONG_DAN_CAI_DAT.docx. Đính kèm APK debug nếu giảng viên yêu cầu, ghi rõ cách nối backend. Không nộp khóa thật hoặc dữ liệu tài khoản cá nhân.

Sửa bản Markdown rồi xuất lại Word bằng Python 3, không cần cài thư viện ngoài:

```powershell
python docs/export_document.py
```
