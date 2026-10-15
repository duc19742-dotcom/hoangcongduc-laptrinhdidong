# Demo đăng nhập bằng tài khoản, mật khẩu và SMS OTP

App chỉ mở màn hình chính sau khi backend kiểm tra OTP thành công. Đăng ký cũng xác minh SMS để gắn số điện thoại với tài khoản. Không có mã OTP cố định hoặc SMS giả trong app.

## 1. Tạo Twilio Trial

1. Đăng ký tại https://www.twilio.com/try-twilio, xác minh email và số điện thoại Việt Nam.
2. Trong Console, mở **Identity → Verify → Overview → Try out Verify**. Không vào Services để tạo dịch vụ riêng: Trial yêu cầu nâng cấp cho thao tác đó.
3. Theo hướng dẫn trên Try out Verify để thử gửi SMS đến số đã xác minh. Trong khối API request hiển thị trên trang, lấy **Service SID** bắt đầu bằng `VA` từ đường dẫn `/Services/VA.../Verifications`. Dùng SID dịch vụ Trial đó cho `TWILIO_VERIFY_SERVICE_SID`. Lấy **Account SID**, **Auth Token** tại trang tài khoản. Không dùng Test Credentials: chúng không gửi SMS thật. Không sao chép toàn bộ đoạn lệnh lên chat vì có thể chứa khóa bí mật.
4. Xác minh trước số điện thoại nhận OTP trong danh sách người nhận thử nghiệm của Twilio. Có thể dùng số đăng ký tài khoản để demo.
5. Kiểm tra Verify Geo Permissions cho phép Việt Nam nếu Console yêu cầu.

Tài liệu Trial Verify: https://www.twilio.com/docs/usage/trials/try-out-verify. Twilio cho dùng API Verification và VerificationCheck với giới hạn Trial; lấy đầy đủ Service SID từ khối request trên trang Try out Verify.

Trial hiện có hạn mức và thời hạn; kiểm tra trực tiếp trong Console. Giữ tài khoản ở Trial nếu muốn chỉ dùng hạn mức miễn phí, không nâng cấp tài khoản. Số gửi SMS là do Twilio cấp, không phải SIM cá nhân.

## 2. Chạy backend trên máy tính

Yêu cầu Node.js 24 trở lên. Backend dùng thư viện có sẵn của Node, không cần npm install.

```powershell
cd D:\hoang_cong_duc\backend
Copy-Item .env.example .env
notepad .env
```

Điền thông tin thật vào `.env`:

```dotenv
HOST=0.0.0.0
PORT=3000
TWILIO_ACCOUNT_SID=AC...
TWILIO_AUTH_TOKEN=...
TWILIO_VERIFY_SERVICE_SID=VA...
DEMO_ALLOWED_PHONES=+84912345678
```

Thay số ví dụ bằng số nhận đã xác minh của bạn. Nhiều số thì ngăn cách bằng dấu phẩy. Backend chỉ gửi đến danh sách này để giữ hạn mức demo. Không gửi file `.env` hoặc Auth Token cho người khác, không đặt khóa trong Flutter.

```powershell
node --env-file=.env server.mjs
```

Kiểm tra: mở http://localhost:3000/health để thấy `{"ok":true}`. Health chỉ xác nhận backend chạy, không xác nhận Twilio đã cấu hình đúng.

## 3. Chạy Flutter

### Android Emulator

Mặc định API là `http://10.0.2.2:3000` (máy tính chạy emulator):

```powershell
cd D:\hoang_cong_duc
& 'D:\Androi Studio - Git - Flutter SDK\Flutter\bin\flutter.bat' pub get
& 'D:\Androi Studio - Git - Flutter SDK\Flutter\bin\flutter.bat' run
```

### Điện thoại Android thật qua Wi-Fi

Máy tính và điện thoại cùng Wi-Fi. Chạy `ipconfig` lấy IPv4 của card Wi-Fi, ví dụ `192.168.1.10`. Cho phép Node.js qua Windows Firewall ở mạng Private khi Windows hỏi. Thử mở `http://192.168.1.10:3000/health` bằng trình duyệt điện thoại trước.

```powershell
& 'D:\Androi Studio - Git - Flutter SDK\Flutter\bin\flutter.bat' run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

Thay IP ví dụ bằng IP máy của bạn. Thay `API_BASE_URL` phải dừng và chạy lại app.

### Điện thoại Android qua USB (không cần cùng Wi-Fi)

```powershell
& 'D:\Androi Studio - Git - Flutter SDK\Sdk\platform-tools\adb.exe' reverse tcp:3000 tcp:3000
& 'D:\Androi Studio - Git - Flutter SDK\Flutter\bin\flutter.bat' run --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Backend này phục vụ demo Android. HTTP nội bộ chỉ được bật ở bản debug; bản release cần API HTTPS. Khi demo nên dùng mật khẩu dành riêng cho đồ án.

## 4. Trình diễn

1. Chọn **Chưa có tài khoản? Đăng ký**.
2. Nhập họ tên, tài khoản không dấu (3–30 ký tự), số điện thoại có trong danh sách demo, mật khẩu ít nhất 8 ký tự và nhập lại mật khẩu.
3. Đồng ý nhận SMS rồi bấm **Đăng ký và gửi OTP**.
4. Nhập mã 6 số nhận trong Tin nhắn. Nhập sai để kiểm tra lỗi; nhập đúng mới vào ứng dụng.
5. Mở tab Cá nhân: phần đầu hiển thị tài khoản vừa đăng nhập, phần thông tin đồ án bên dưới được giữ lại. Bấm **Đăng Xuất**.
6. Đăng nhập lại bằng tài khoản và mật khẩu, nhận SMS OTP mới, nhập đúng để vào app.

OTP có cửa sổ xác minh 5 phút, tối đa 5 lần nhập; mỗi số chờ 60 giây giữa các lần gửi và tối đa 5 yêu cầu gửi/giờ. Gửi lại không gia hạn cửa sổ xác minh. Twilio có thể gửi lại cùng mã trong thời gian mã còn hiệu lực.

Nếu gửi SMS thất bại lúc đăng ký, tài khoản vẫn được lưu ở trạng thái chưa xác minh: chuyển sang Đăng nhập để thử lại, không đăng ký trùng. Mã hết hạn hoặc nhập sai quá nhiều lần cũng quay lại Đăng nhập.

Tài khoản lưu trong `backend/data/users.sqlite`, mật khẩu được băm bằng scrypt và salt riêng. Phiên đăng nhập và yêu cầu OTP nằm trong bộ nhớ backend; khởi động lại backend sẽ hết hiệu lực. App không lưu phiên qua lần đóng/mở để mỗi lần demo bắt đầu ở màn hình đăng nhập. Backend cấp phiên 8 giờ, chỉ sau OTP đúng.

## 5. Kiểm tra tự động

```powershell
cd D:\hoang_cong_duc\backend
node --test
cd D:\hoang_cong_duc
& 'D:\Androi Studio - Git - Flutter SDK\Flutter\bin\flutter.bat' analyze
& 'D:\Androi Studio - Git - Flutter SDK\Flutter\bin\flutter.bat' test
```

Các bài kiểm tra dùng nhà cung cấp SMS giả được tiêm riêng trong test, không gọi Twilio và không tiêu hao SMS. Nhận SMS thật phải kiểm tra sau khi điền cấu hình Twilio.
