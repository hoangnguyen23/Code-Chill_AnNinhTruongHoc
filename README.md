# An ninh trường học

App Android (Flutter) **báo cáo sự cố an ninh trong trường**. **Đăng ký** bằng email và chỉ thành công khi nhập
đúng **mã OTP gửi thật qua email** (Gmail SMTP, miễn phí); **đăng nhập** bằng tên đăng nhập (hoặc email) + mật khẩu.
Thông báo sự cố gửi qua **thông báo đẩy FCM** trong app.

- **Người báo** (sinh viên, giảng viên, nhân viên): đăng ký (email + OTP) và đăng nhập (tên + mật khẩu), nút KHẨN CẤP (2 chạm, kèm GPS),
  gửi báo cáo chi tiết (loại, mức độ, mô tả, toà/tầng/phòng, GPS, ảnh, thời gian, ẩn danh), theo dõi trạng thái, trao đổi.
  **Đi cùng tôi**: hẹn giờ đi tới một nơi, app gửi vị trí mỗi 30 giây; quá giờ chưa bấm "Đã tới nơi" thì backend tự tạo
  báo cáo khẩn cấp kèm vị trí cuối và báo bảo vệ trực.
- **Bảo vệ**: hàng đợi sự cố có lọc (trạng thái, mức độ, khu vực, thời gian), **bản đồ sự cố** (OpenStreetMap, màu theo
  mức độ, kèm người đang "Đi cùng tôi"), nhận việc, cập nhật trạng thái, bật/tắt "Đang trực".
- **Quản trị**: thống kê, phân công, quản lý tài khoản, cấu hình trường (số trực, khu vực), **Cảnh báo toàn trường**
  (banner trong app + push tới mọi người).
- Mọi người thấy **banner cảnh báo toàn trường** ở đầu trang chủ / Sự cố / Tổng quan khi quản trị gửi.

Tài liệu liên quan: [`DESIGN.md`](DESIGN.md) (hướng thiết kế và ghi chú audit `/impeccable`), [`PRODUCT.md`](PRODUCT.md) (bối cảnh sản phẩm).

---

## 1. Kiến trúc

```
D:\sms-otp-main
├─ lib/                     App Flutter (feature-first + clean architecture, Riverpod 3, go_router 18, Material 3)
│  ├─ core/                 theme, router theo vai trò, API client, push FCM, vị trí, ảnh, widget dùng chung
│  └─ features/             auth · reports · staff · admin · settings · campus (mỗi feature: domain / data / presentation)
├─ packages/campus_core/    Logic Dart dùng chung app + backend: chuẩn hoá SĐT, vai trò, máy trạng thái, phân quyền, validate
├─ backend/                 dart_frog: web API, MongoDB, tài khoản, OTP qua email, custom token Firebase, FCM
├─ firebase/                cấu hình Firebase cũ, không còn dùng cho dữ liệu
├─ test/                    Unit test + widget test của app
└─ tool/screenshots/        Chụp ảnh các màn để rà soát giao diện
```

Luồng dữ liệu:

```
App ──(Firebase ID token)──► backend dart_frog ──► SMTP (Gmail): email chứa mã OTP
 │                               ├──► MongoDB Atlas: CSDL chính (tài khoản, báo cáo, lượt đi, cảnh báo, ảnh)
 │                               └──► FCM HTTP v1: push cho bảo vệ / người báo
 └──(mọi thao tác đọc và ghi đều qua web API; app tự tải lại định kỳ và ngay khi có thông báo đẩy)
```

- App **không chứa secret** và không truy cập CSDL trực tiếp. **Firebase chỉ là phần hỗ trợ**: đăng nhập (Auth) và thông báo đẩy (FCM).
- `AccountService` (`backend/lib/src/auth/account_service.dart`): đăng ký (màn đăng ký không có ô chọn đối tượng:
  tài khoản mới mặc định là Sinh viên, chỉ quản trị đổi sang Giảng viên (màn Tài khoản), người dùng không tự đổi; vai trò luôn là Người báo; gửi OTP, chỉ tạo tài khoản khi nhập đúng mã), quên mật khẩu (OTP gửi tới email
  của tài khoản, đúng mã mới đổi được), quản trị xoá tài khoản, đăng nhập (mật khẩu băm PBKDF2-HMAC-SHA256, sai 5 lần khoá 15 phút). Mật khẩu đã băm nằm ở `credentials/{uid}`,
  tên đăng nhập duy nhất qua `username_index/{tên}`; client không đọc được hai collection này.
- `OtpMailer` (interface) → `SmtpOtpMailer` ở `backend/lib/src/auth/otp_mailer.dart`: gửi mã OTP qua email.
- `NotificationService` (`backend/lib/src/notifications/`): thông báo đẩy FCM. Sự cố thường báo quản trị và bảo vệ
  đang trực; sự cố khẩn cấp báo mọi bảo vệ, kể cả đang nghỉ ca.
- Tài khoản gắn với **email** (`email_index/{email}` đảm bảo mỗi email một tài khoản). Số điện thoại là thông tin
  hồ sơ tuỳ chọn, dùng để bảo vệ liên hệ.
- Báo cáo ẩn danh: `reports/{id}` không chứa tên/SĐT người báo; thông tin thật ở `reports/{id}/private/reporter`,
  chỉ quản trị và chính người báo đọc được. Bảo vệ không đọc được.

## 2. Yêu cầu

| Công cụ | Ghi chú |
|---|---|
| Flutter stable 3.47.5 (Dart 3.13) | đã kiểm tra trên máy này |
| Android Studio + Android SDK 36 | máy ảo hoặc điện thoại Android **7.0 (API 24) trở lên** |
| Node.js | để cài Firebase CLI: `npm i -g firebase-tools` |
| FlutterFire CLI | `dart pub global activate flutterfire_cli` |
| dart_frog CLI | `dart pub global activate dart_frog_cli` |

Thêm `%LOCALAPPDATA%\Pub\Cache\bin` vào PATH để gọi được `flutterfire` và `dart_frog`.

> **minSdk là 24, không phải 23.** Flutter 3.47 và Firebase Android BoM 35 yêu cầu tối thiểu API 24; Flutter tự nâng
> `minSdk 23` lên 24 khi build và từ chối chạy trên máy API 23.

## 3. Cấu hình Firebase

1. Vào <https://console.firebase.google.com>, tạo project.
2. Bật **Authentication** và **Cloud Messaging**. Dữ liệu không nằm trên Firebase mà ở MongoDB Atlas (biến `MONGODB_URI`).
4. **Authentication**: bấm "Get started". Không cần bật provider nào: app đăng nhập bằng *custom token* do backend cấp sau khi xác thực OTP.
5. Thêm app Android với **Application ID `vn.edu.antoan.campus_safety`**.
6. Ở thư mục dự án:
   ```bash
   firebase login
   flutterfire configure --platforms=android
   ```
   Lệnh này ghi đè `lib/firebase_options.dart` (hiện là file tạm) và thêm `android/app/google-services.json`.
   Nếu chưa chạy, app mở màn "Chưa cấu hình Firebase" thay vì crash.
7. **Service account cho backend**: Project settings → Service accounts → *Generate new private key*.
   Lưu file thành `backend/service-account.json` (đã nằm trong `.gitignore`).

## 4. Email OTP (Gmail, miễn phí)

1. Bật **Xác minh 2 bước** cho tài khoản Google dùng để gửi mail: <https://myaccount.google.com/security>.
2. Tạo **Mật khẩu ứng dụng** tại <https://myaccount.google.com/apppasswords> (đặt tên tuỳ ý, ví dụ `campus safety`).
   Google hiện một chuỗi 16 ký tự, chỉ hiện một lần.
3. Điền vào `backend/.env`:

```
SMTP_USERNAME=ten.cua.ban@gmail.com
SMTP_PASSWORD=abcd efgh ijkl mnop
```

Không dùng mật khẩu đăng nhập Gmail (Google sẽ từ chối, lỗi `535`). Gmail miễn phí gửi được khoảng 500 email/ngày, đủ
cho demo. Muốn dùng máy chủ khác (Brevo, Outlook...) thì đổi `SMTP_HOST`/`SMTP_PORT` (587 dùng STARTTLS, 465 dùng SSL).
Email OTP có thể rơi vào mục **Spam/Quảng cáo** ở lần đầu; màn nhập mã có nhắc người dùng kiểm tra.

## 5. Chạy backend (máy tính của bạn)

```bash
cd backend
cp .env.example .env
dart pub get
dart run tool/generate_secret.dart
```

Dán chuỗi vừa in ra vào `OTP_PEPPER`, điền các biến Firebase và SMTP trong `.env`, rồi:

```bash
dart_frog dev
```

Backend chạy ở `http://localhost:8080`. Thiếu cấu hình thì backend in rõ biến nào thiếu (tiếng Việt) và dừng.
Bắt buộc: `MONGODB_URI`, `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` (file service account), `OTP_PEPPER`,
`SMTP_USERNAME`, `SMTP_PASSWORD`.

Biến quan trọng khác trong `.env`:

- `BOOTSTRAP_ADMIN_EMAILS`: email luôn có quyền quản trị (dùng để tạo quản trị đầu tiên).
- `ALLOW_SELF_REGISTRATION`: `true` cho mọi email đăng nhập làm người báo; `false` chỉ cho email đã được quản trị tạo trước.
- `DUTY_HOTLINE`: số trực mặc định cho nút "Gọi trực an ninh" (quản trị đổi được trong app).

Các API: `GET /config`, `POST /auth/register/request`, `POST /auth/register/verify`, `POST /auth/login`,
`POST /auth/password/forgot`, `POST /auth/password/reset`, `POST /me/password`, `DELETE /admin/users/{uid}`, `POST /images`, `GET /images/{id}`, `GET|PATCH /me`, `POST|DELETE /me/fcm_token`,
`POST /reports`, `POST /reports/{id}/status|assign|comments`, `POST /admin/users`, `PATCH /admin/users/{uid}`,
`PUT /admin/config`,
`POST /admin/broadcasts`, `POST /admin/broadcasts/{id}/end`, `POST /walks`,
`POST /walks/{id}/location|arrive|cancel|extend|sos`.

Backend quét các lượt "Đi cùng tôi" quá giờ mỗi 30 giây (`WalkService.startOverdueTimer`).
Chạy nhiều backend cùng lúc trên một CSDL vẫn an toàn: mọi thay đổi trạng thái lượt đi
đi qua transaction (`WalkRepository.updateIfActive`), nên mỗi lượt quá giờ chỉ tạo đúng một báo cáo khẩn cấp.

## 6. Chạy app

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

- **Mặc định**: app gọi backend đã deploy `https://an-ninh-truong-hoc-api.onrender.com` (Render, xem `render.yaml`).
- **Máy ảo Android**: `10.0.2.2` trỏ về máy tính đang chạy backend.
- **Điện thoại thật qua USB**: chạy `adb reverse tcp:8080 tcp:8080` rồi dùng `--dart-define=API_BASE_URL=http://127.0.0.1:8080`.
- **Android Studio**: *Run → Edit Configurations → Additional run args*: `--dart-define=API_BASE_URL=http://10.0.2.2:8080`.
- Bản debug cho phép HTTP tới backend local; bản release bắt buộc HTTPS.

Lần đầu dùng:

1. Bấm **Đăng ký ngay**, dùng một email trong `BOOTSTRAP_ADMIN_EMAILS`, nhập mã OTP nhận trong hộp thư: tài khoản
   này thành quản trị. Lần sau đăng nhập bằng tên đăng nhập + mật khẩu.
2. **Quản lý → Cấu hình trường**: nhập tên trường, số trực, danh sách khu vực.
3. **Quản lý → Tài khoản**: tạo tài khoản bảo vệ (email, số điện thoại tuỳ chọn). Bảo vệ **đăng ký bằng đúng email đó**
   (nhận OTP) để đặt tên đăng nhập và mật khẩu; vai trò bảo vệ được giữ nguyên. Sau đó bật **Đang trực**.

## 7. Deploy backend

**Cloud Run** (khuyến nghị):

```bash
cd backend
dart_frog build
gcloud run deploy campus-safety-backend --source build --region asia-southeast1 --allow-unauthenticated
```

- Đặt các biến môi trường như trong `.env` bằng `--set-env-vars` hoặc Secret Manager (biến môi trường ưu tiên hơn file `.env`).
- Mount service account JSON như secret file và đặt `GOOGLE_APPLICATION_CREDENTIALS` trỏ tới file đó.
- Đặt `TRUST_PROXY=true` để giới hạn tần suất theo IP lấy đúng IP người dùng.
- Cloud Run tắt instance khi không có request; token vẫn được làm mới khi có lượt gửi tin. Nếu trường có thể không phát sinh
  tin nào trong 3 tháng, đặt `--min-instances=1` để bộ hẹn giờ làm mới token chạy liên tục.

**VPS**: `dart_frog build` tạo sẵn `build/Dockerfile`; chạy container sau reverse proxy HTTPS (Caddy/Nginx), `TRUST_PROXY=true`.

Build app phát hành trỏ tới backend thật:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<ten-mien-backend>
```

## 8. Kiểm thử

```bash
flutter analyze
flutter test
cd packages/campus_core && dart analyze && dart test
cd backend && dart analyze && dart test
```

| Bộ test | Nội dung | Số test |
|---|---|---|
| `packages/campus_core/test` | chuẩn hoá SĐT và email, quy tắc tên đăng nhập/mật khẩu, email không chứa "/", phân quyền, máy trạng thái, validate báo cáo | 70 |
| `backend/test` | đăng ký email + OTP (chỉ tạo tài khoản khi đúng mã, trùng tên, nhận tài khoản tạo trước), đăng nhập mật khẩu (khoá sau 5 lần sai, không lộ tài khoản), quên và đổi mật khẩu, xoá tài khoản, PBKDF2 theo vector RFC, nghiệp vụ báo cáo, thông báo đẩy theo trạng thái trực, cảnh báo toàn trường, "Đi cùng tôi" (quá giờ, gia hạn, khẩn cấp, nhiều backend quét cùng lúc), kho ảnh, giới hạn tần suất | 73 |
| `test/` | điều hướng theo vai trò, lọc/thống kê, API client, **widget test màn gửi báo cáo**, sheet khẩn cấp (chờ GPS), lịch sử ẩn danh, dữ liệu cảnh báo toàn trường và "Đi cùng tôi", **widget test đăng nhập/đăng ký/OTP** | 50 |

Test không gọi MongoDB/Firebase/máy chủ mail thật (dùng giả lập và kho dữ liệu trong bộ nhớ chỉ có trong `test/`).
Mã chạy thật luôn gửi email/tin thật.

Chụp ảnh các màn (sáng/tối, chữ 200%) để rà soát giao diện:

```bash
flutter test tool/screenshots/capture_test.dart --update-goldens
```

## 9. Bảo mật

- Secret (mật khẩu ứng dụng Gmail, `OTP_PEPPER`) và service account chỉ nằm ở backend `.env` và file service account.
- OTP đăng ký 6 số từ `Random.secure()`, hết hạn 5 phút, chỉ lưu HMAC-SHA256 (pepper + email + mã + salt), dùng một
  lần, sai 5 lần khoá mã; giới hạn theo email (60 giây giữa 2 lần, 5 lần/giờ, 10 lần/ngày) và theo IP.
- Phiên đăng nhập: backend kiểm tra ID token **kể cả đã bị thu hồi** (`checkRevoked`), nên sau khi đặt lại mật khẩu,
  khoá hoặc xoá tài khoản, máy cũ bị từ chối ngay. Quản trị gốc (`BOOTSTRAP_ADMIN_EMAILS`) không bị khoá, hạ quyền hay xoá.
- Giới hạn tần suất theo tài khoản (`UserLimits`): 10 báo cáo/10 phút, 30 ảnh/10 phút, 30 tin nhắn/10 phút,
  10 lượt Đi cùng tôi/giờ, 5 lần đổi mật khẩu/15 phút, 10 cảnh báo toàn trường/giờ; mỗi tài khoản tối đa 10 thiết bị nhận push.
- Kết nối app ↔ backend trong demo là HTTP trong mạng LAN (chỉ bản debug cho phép). Triển khai thật phải dùng HTTPS
  (bản release chặn HTTP).
- Mật khẩu: tối thiểu 8 ký tự có chữ và số, băm PBKDF2-HMAC-SHA256 (80.000 vòng, muối ngẫu nhiên). Đăng nhập sai báo
  chung "Tên đăng nhập hoặc mật khẩu không đúng" (không lộ tài khoản có tồn tại), sai 5 lần khoá 15 phút.
- Phân quyền theo vai trò nằm ở backend; client chỉ gọi API. Ảnh: chỉ JPEG tối đa 700 KB, lưu ở `report_images` (client không đọc
  trực tiếp); link xem ảnh dùng ID ngẫu nhiên 32 ký tự, chỉ ai thấy báo cáo mới biết link.
- Ảnh được nén (cạnh dài 1600px, JPEG) và **xoá EXIF** (không lộ GPS trong ảnh) trước khi tải lên.
- Validate dữ liệu ở cả app và backend bằng cùng một package (`campus_core`).

## 10. Ghi chú kỹ thuật

- **Material**: Flutter 3.47 tách Material thành package `material_ui` (go_router 18 dùng package này), nên app import
  `package:material_ui/material_ui.dart` để theme và localization không bị lệch.
- **FCM token**: firebase_messaging 17 đánh dấu `getToken()` là deprecated để chuyển sang định danh FID. Backend gửi push qua
  FCM HTTP v1 bằng `dart_firebase_admin`, vốn nhắm tới registration token, nên app vẫn dùng `getToken()` (vẫn hoạt động).
- **Windows**: `android/gradle.properties` đặt `kotlin.incremental=false` vì dự án (ổ D:) và pub cache (ổ C:) khác ổ đĩa
  làm Kotlin incremental compilation lỗi.
