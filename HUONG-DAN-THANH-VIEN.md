# Hướng dẫn dùng app cho thành viên

Backend đã deploy trên Internet tại `https://an-ninh-truong-hoc-api.onrender.com`. Cả nhóm chỉ cần **cài APK lên điện thoại**:
**không cần chạy backend trên laptop, không cần cùng Wi-Fi, không cần nhập địa chỉ máy chủ**.

```
Điện thoại 1 ─┐
Điện thoại 2 ─┼─► Web API trên Render ─► MongoDB Atlas (CSDL) + Firebase (đăng nhập, thông báo đẩy)
Điện thoại 3 ─┘
```

## 1. Cài app bằng APK

1. Gửi file `sms-otp-main.apk` sang điện thoại (Zalo, Google Drive, cáp USB...). Cần Android 7.0 trở lên.
2. Mở file trên điện thoại → nếu máy hỏi, cho phép **cài ứng dụng từ nguồn này** → **Cài đặt**.
   - Báo *"Ứng dụng chưa được cài đặt"* / *xung đột gói*: **gỡ app "An ninh trường học" cũ** rồi cài lại.
   - Google Play Protect cảnh báo ứng dụng lạ: chọn **Vẫn cài đặt** (bản demo không qua cửa hàng).
3. Mở app, cho phép **Thông báo**, **Vị trí**, **Máy ảnh** khi được hỏi.
4. Đăng nhập hoặc đăng ký. Điện thoại chỉ cần có Internet (Wi-Fi hoặc 4G).

## 2. Khi cần sửa code

Mở thư mục có `pubspec.yaml` trong Android Studio (cần Flutter 3.47.8), chạy `flutter pub get`, chọn điện thoại rồi bấm ▶.
Sửa backend xong, đẩy code lên GitHub thì Render tự deploy lại. Muốn chạy backend trên máy để thử, dùng
`chay-backend.ps1` rồi nhập địa chỉ máy tính ở biểu tượng máy chủ trên màn đăng nhập.

## 5. Tài khoản

- Lần đầu: **Đăng ký ngay** → nhập họ tên, email, tên đăng nhập, mật khẩu → nhập **mã OTP gửi về email** →
  tài khoản được tạo (mặc định **Sinh viên**, vai trò **Người báo**). Người dùng **không tự đổi** được Sinh viên/Giảng viên:
  quản trị đổi trong **Quản lý → Tài khoản**.
- **Đổi mật khẩu** khi đang đăng nhập: *Cài đặt → Đổi mật khẩu* (nhập mật khẩu hiện tại). Tên đăng nhập hiện trong *Cài đặt*.
- **Quên mật khẩu**: ở màn đăng nhập bấm *Quên mật khẩu?* → nhập email của tài khoản → nhập mã OTP gửi về email
  và mật khẩu mới. Mã đúng thì mật khẩu mới có hiệu lực ngay (các máy đang đăng nhập bằng mật khẩu cũ bị đăng xuất). Các lần sau đăng nhập bằng tên đăng nhập + mật khẩu.
- Tài khoản là **chung cho cả nhóm**: đăng ký ở máy nào cũng đăng nhập được ở máy khác.
- Người đăng ký chỉ tự chọn Sinh viên / Giảng viên. **Vai trò Bảo vệ, Quản trị** chỉ quản trị đổi được:
  trưởng nhóm vào **Quản lý → Tài khoản** để đổi một thành viên thành **Bảo vệ**.
- Quản trị **xoá tài khoản** trong **Quản lý → Tài khoản** → chọn người → *Xoá tài khoản*. Báo cáo họ đã gửi vẫn giữ;
  tài khoản quản trị gốc (`kien`) không xoá được.

## 6. Kịch bản demo gợi ý

Mỗi thành viên phải tự thao tác trên máy của mình khi trình bày.

| Máy | Vai trò | Thao tác |
|---|---|---|
| 1 | Quản trị | Tổng quan, **Quản lý → Cảnh báo toàn trường**, phân công sự cố |
| 2 | Bảo vệ | Bật **Đang trực**, tab **Sự cố** và **Bản đồ**, nhận việc, đổi trạng thái |
| 3 | Người báo | Bấm **KHẨN CẤP**, gửi báo cáo có ảnh/vị trí, **Đi cùng tôi** (để quá giờ cho bảo vệ thấy) |

## 7. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| App báo "Không kết nối được máy chủ" | Kiểm tra Internet của điện thoại. Máy chủ có thể vừa khởi động lại: đợi 1 phút rồi thử lại. |
| Nút ▶ Run bị mờ, Android Studio không nhận ra dự án Flutter | Chạy `flutter pub get` trong Terminal; *Settings → Languages & Frameworks → Flutter* chọn thư mục Flutter SDK (bật *Enable Dart support* nếu được hỏi); rồi *File → Close Project* và mở lại thư mục có `pubspec.yaml`. |
| `flutter pub get` báo cần Dart 3.13.4 | Flutter cũ: chạy `flutter upgrade`. |
| Không nhận email OTP | Xem mục Spam/Quảng cáo; đợi 60 giây rồi bấm "Gửi lại mã". |
