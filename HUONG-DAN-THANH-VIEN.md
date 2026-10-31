# Hướng dẫn chạy trên laptop của từng thành viên

Mỗi thành viên chạy **backend riêng trên laptop của mình** và cắm/kết nối **điện thoại Android của mình**.
Cả nhóm dùng **chung dữ liệu** vì mọi backend đều kết nối tới cùng một Firebase project (`sms-otp-26e31`).

```
Điện thoại 1 ─ Laptop 1 ─ backend ─┐
Điện thoại 2 ─ Laptop 2 ─ backend ─┼─► Firestore + thông báo đẩy (chung, trên cloud)
Điện thoại 3 ─ Laptop 3 ─ backend ─┘
```

> Thư mục này có `backend/.env` (mật khẩu gửi email) và `backend/service-account.json` (quyền quản trị
> Firebase). **Không đưa lên GitHub công khai, không gửi vào nhóm chat đông người.**

> **Nhóm dùng APK**: điện thoại cài sẵn file **`sms-otp-main.apk`** (trưởng nhóm gửi), laptop chỉ cần chạy
> backend. **Không cần Android Studio** (chỉ cần khi muốn sửa code). Làm các mục 1 → 3 → 4A.

## 1. Cài đặt (làm một lần)

| Phần mềm | Ghi chú |
|---|---|
| **Flutter 3.47.8** (stable) | **Bắt buộc** (để chạy backend). https://docs.flutter.dev/get-started/install/windows . Giải nén, ví dụ `C:\flutter`, thêm `C:\flutter\bin` vào PATH. Bản cũ hơn không chạy được (dự án cần Dart 3.13.4 trở lên): chạy `flutter upgrade` nếu cần. |
| **Android Studio** | *Chỉ cần nếu chạy app từ source (mục 4B).* Cài kèm Android SDK, *Settings → Plugins* cài **Flutter**. |
| Điện thoại Android 7.0 trở lên | Bản APK dành cho điện thoại 64-bit (hầu hết máy từ 2017 trở lại đây). |

Kiểm tra bằng lệnh (mở PowerShell):

```bash
flutter --version
```

```bash
flutter doctor
```

Dùng APK thì `flutter --version` chạy được là đủ. Chạy app từ source (4B) thì `flutter doctor` cần thêm dấu tích ở
**Android toolchain** (chạy `flutter doctor --android-licenses` nếu được hỏi về license).

## 2. Mở dự án (chỉ khi chạy app từ source, mục 4B)

1. Giải nén file `sms-otp-main.zip`, ví dụ ra `D:\`, được thư mục `D:\sms-otp-main`.
2. Android Studio → **Open** → chọn đúng thư mục có file `pubspec.yaml` (không chọn thư mục cha).
3. Nếu báo *Dart SDK is not configured*: *Settings → Languages & Frameworks → Flutter* → chọn thư mục Flutter
   (ví dụ `C:\flutter`).
4. Mở terminal trong Android Studio, chạy:

```bash
flutter pub get
```

## 3. Chạy backend trên laptop

Trong thư mục dự án, chuột phải `chay-backend.ps1` → **Run with PowerShell** (hoặc chạy lệnh dưới trong
PowerShell tại thư mục dự án):

```bash
powershell -ExecutionPolicy Bypass -File .\chay-backend.ps1
```

- Lần đầu mất vài phút (tải thư viện, build). Windows hỏi tường lửa thì chọn **Allow access / Cho phép**.
- Cửa sổ in ra **Địa chỉ máy chủ cho điện thoại**, ví dụ `192.168.1.54:8080`. Ghi lại địa chỉ này.
- **Giữ cửa sổ mở** suốt buổi báo cáo.

## 4A. Cài app bằng APK (nhóm dùng cách này)

1. Gửi file `sms-otp-main.apk` sang điện thoại (Zalo, Google Drive, cáp USB...).
2. Mở file trên điện thoại → nếu máy hỏi, cho phép **cài ứng dụng từ nguồn này** → **Cài đặt**.
   - Báo *"Ứng dụng chưa được cài đặt"* / *xung đột gói*: điện thoại đang có bản cũ cài từ Android Studio của máy
     khác. **Gỡ app "An ninh trường học" cũ** rồi cài lại.
   - Google Play Protect cảnh báo ứng dụng lạ: chọn **Vẫn cài đặt** (bản demo không qua cửa hàng).
3. Mở app, cho phép **Thông báo**, **Vị trí**, **Máy ảnh** khi được hỏi.
4. Điện thoại và laptop bắt **cùng một Wi-Fi** (Wi-Fi trường chặn thì dùng hotspot điện thoại).
5. Màn đăng nhập: bấm **biểu tượng máy chủ** ở góc trên bên phải → nhập địa chỉ ở mục 3 →
   **Kiểm tra kết nối** → **Lưu**. App nhớ địa chỉ này; đổi mạng thì nhập lại địa chỉ mới.

## 4B. Chạy app từ source (khi cần sửa code)

1. Làm mục 2 (mở dự án trong Android Studio).
2. Cắm điện thoại vào laptop, bật *Tuỳ chọn nhà phát triển* → *Gỡ lỗi USB*, chấp nhận "Cho phép gỡ lỗi USB".
3. Chọn điện thoại ở ô thiết bị, chọn cấu hình **main.dart** rồi bấm ▶ (lần đầu build khoảng 5–7 phút).
4. Nhập địa chỉ máy chủ như bước 5 của mục 4A.

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

| Máy | Vai trò | Thao tác |
|---|---|---|
| 1 | Quản trị | Tổng quan, **Quản lý → Cảnh báo toàn trường**, phân công sự cố |
| 2 | Bảo vệ | Bật **Đang trực**, tab **Sự cố** và **Bản đồ**, nhận việc, đổi trạng thái |
| 3 | Người báo | Bấm **KHẨN CẤP**, gửi báo cáo có ảnh/vị trí, **Đi cùng tôi** (để quá giờ cho bảo vệ thấy) |

## 7. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| App báo "Không kết nối được máy chủ" | Backend (cửa sổ PowerShell) còn chạy không? Điện thoại cùng Wi-Fi chưa? Nhập lại địa chỉ máy chủ (IP đổi khi đổi mạng). |
| Kiểm tra kết nối báo "Không phản hồi" | Tường lửa chặn: *Windows Security → Firewall → Allow an app* → cho phép **dartvm**. Hoặc Wi-Fi chặn thiết bị nhìn nhau: dùng hotspot. |
| Nút ▶ Run bị mờ, Android Studio không nhận ra dự án Flutter | Chạy `flutter pub get` trong Terminal; *Settings → Languages & Frameworks → Flutter* chọn thư mục Flutter SDK (bật *Enable Dart support* nếu được hỏi); rồi *File → Close Project* và mở lại thư mục có `pubspec.yaml`. |
| `flutter pub get` báo cần Dart 3.13.4 | Flutter cũ: chạy `flutter upgrade`. |
| Script báo thiếu `.env` / `service-account.json` | Xin lại 2 file từ trưởng nhóm, đặt trong thư mục `backend`. |
| Không nhận email OTP | Xem mục Spam/Quảng cáo; đợi 60 giây rồi bấm "Gửi lại mã". |
