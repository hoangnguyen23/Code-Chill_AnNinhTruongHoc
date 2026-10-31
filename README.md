# An ninh trường học

App Android (Flutter) **báo cáo sự cố an ninh trong trường**. **Đăng ký** bằng email và chỉ thành công khi nhập
đúng **mã OTP gửi thật qua email** (Gmail SMTP, miễn phí); **đăng nhập** bằng tên đăng nhập (hoặc email) + mật khẩu. Thông báo sự cố gửi qua push FCM trong app; nếu cấu hình Zalo OA thì gửi thêm tin Zalo
(ZBS Template Message, trước đây gọi là ZNS, có tính phí) tới số điện thoại người dùng.

- **Người báo** (sinh viên, giảng viên, nhân viên): đăng ký (email + OTP) và đăng nhập (tên + mật khẩu), nút KHẨN CẤP (2 chạm, kèm GPS),
  gửi báo cáo chi tiết (loại, mức độ, mô tả, toà/tầng/phòng, GPS, ảnh, thời gian, ẩn danh), theo dõi trạng thái, trao đổi.
  **Đi cùng tôi**: hẹn giờ đi tới một nơi, app gửi vị trí mỗi 30 giây; quá giờ chưa bấm "Đã tới nơi" thì backend tự tạo
  báo cáo khẩn cấp kèm vị trí cuối và báo bảo vệ trực.
- **Bảo vệ**: hàng đợi sự cố có lọc (trạng thái, mức độ, khu vực, thời gian), **bản đồ sự cố** (OpenStreetMap, màu theo
  mức độ, kèm người đang "Đi cùng tôi"), nhận việc, cập nhật trạng thái, bật/tắt "Đang trực".
- **Quản trị**: thống kê, phân công, quản lý tài khoản, cấu hình trường (số trực, khu vực), **Cảnh báo toàn trường**
  (banner trong app + push tới mọi người), **Gửi thử Zalo**, **Nhật ký gửi tin**.
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
├─ backend/                 dart_frog: OTP, custom token Firebase, ZaloZnsGateway, FCM, nhật ký gửi tin
├─ firebase/                firestore.rules, storage.rules, firestore.indexes.json, firebase.json
├─ test/                    Unit test + widget test của app
└─ tool/screenshots/        Chụp ảnh các màn để rà soát giao diện
```

Luồng dữ liệu:

```
App ──(Firebase ID token)──► backend dart_frog ──► SMTP (Gmail): email chứa mã OTP
 │                               ├──► Zalo (tuỳ chọn): business.openapi.zalo.me/message/template
 │                               │                 └► Zalo OAuth v4: oauth.zaloapp.com/v4/oa/access_token
 │                               ├──► Firestore (Admin SDK): ghi báo cáo, sự kiện, nhật ký, token Zalo
 │                               └──► FCM HTTP v1: push cho bảo vệ / người báo
 └──(chỉ ĐỌC, theo Firestore Rules)──► Firestore realtime (ảnh xem qua backend GET /images/{id})
```

- App **không chứa secret**. Mọi thao tác ghi đi qua backend; Firestore Rules chặn ghi từ client.
- `AccountService` (`backend/lib/src/auth/account_service.dart`): đăng ký (màn đăng ký không có ô chọn đối tượng:
  tài khoản mới mặc định là Sinh viên, chỉ quản trị đổi sang Giảng viên (màn Tài khoản), người dùng không tự đổi; vai trò luôn là Người báo; gửi OTP, chỉ tạo tài khoản khi nhập đúng mã), quên mật khẩu (OTP gửi tới email
  của tài khoản, đúng mã mới đổi được), quản trị xoá tài khoản, đăng nhập (mật khẩu băm PBKDF2-HMAC-SHA256, sai 5 lần khoá 15 phút). Mật khẩu đã băm nằm ở `credentials/{uid}`,
  tên đăng nhập duy nhất qua `username_index/{tên}`; client không đọc được hai collection này.
- `OtpMailer` (interface) → `SmtpOtpMailer` ở `backend/lib/src/auth/otp_mailer.dart`: gửi mã OTP qua email.
- `NotificationGateway` (interface) → `ZaloZnsGateway` (bản cài đặt) ở `backend/lib/src/notifications/`; khi chưa
  cấu hình Zalo thì dùng `DisabledNotificationGateway` (không gửi, ghi rõ lý do).
- Tài khoản gắn với **email** (`email_index/{email}` đảm bảo mỗi email một tài khoản). Số điện thoại là thông tin
  hồ sơ tuỳ chọn, dùng để bảo vệ liên hệ và nhận tin Zalo.
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
2. **Firestore Database**: tạo database (Native mode), vùng `asia-southeast1` (Singapore) cho gần Việt Nam.
3. **Ảnh sự cố**: **không cần** Cloud Storage (gói Blaze). App nén ảnh (JPEG, tối đa 700 KB), gửi qua backend
   `POST /images`, backend lưu vào Firestore `report_images/{id}`; mọi backend dùng chung nên máy nào cũng xem được.
4. **Authentication**: bấm "Get started". Không cần bật provider nào: app đăng nhập bằng *custom token* do backend cấp sau khi xác thực OTP.
5. Thêm app Android với **Application ID `vn.edu.antoan.campus_safety`**.
6. Ở thư mục dự án:
   ```bash
   firebase login
   flutterfire configure --platforms=android
   ```
   Lệnh này ghi đè `lib/firebase_options.dart` (hiện là file tạm) và thêm `android/app/google-services.json`.
   Nếu chưa chạy, app mở màn "Chưa cấu hình Firebase" thay vì crash.
7. Deploy Rules và index:
   ```bash
   cd firebase
   firebase use --add            # chọn project vừa tạo
   firebase deploy --only firestore:rules,firestore:indexes
   ```
8. **Service account cho backend**: Project settings → Service accounts → *Generate new private key*.
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

## 4b. Zalo: OA, ứng dụng, ZBS Account (không bắt buộc)

Để trống toàn bộ biến `ZALO_*` thì backend **tắt Zalo**: vẫn chạy đủ chức năng, thông báo chỉ đi qua push FCM, màn
"Gửi thử Zalo" báo chưa cấu hình. Phần dưới chỉ cần khi muốn gửi tin Zalo thật (OA phải xác thực, tin có tính phí).
Template OTP của Zalo không còn dùng vì mã đăng nhập gửi qua email.

Tài liệu chính thức (đã đọc ngày 19/10/2026): *ZBS Template Message* trên <https://developers.zalo.me/docs/zbs-template-message/>.
Từ 01/01/2025, ZNS được hợp nhất vào ZBS Template Message; API gửi tin vẫn là `POST https://business.openapi.zalo.me/message/template`.

1. **Tạo Zalo Official Account** cho trường tại <https://oa.zalo.me> và **xác thực OA**
   (OA chưa xác thực hoặc gói miễn phí sẽ bị lỗi `-135` khi gửi tin qua số điện thoại).
2. **Tạo ứng dụng** tại <https://developers.zalo.me> → *Thêm ứng dụng mới*. Ghi lại **App ID** và **Khoá bí mật (Secret Key)**.
   Bấm **Kích hoạt** ứng dụng (nếu không: lỗi `-103`).
3. **Liên kết ứng dụng với OA** và xin quyền *Gửi tin qua số điện thoại* (ZBS Template Message).
4. **Tạo ZBS Account**, nạp tiền, rồi **liên kết ZBS Account với ứng dụng** (nếu không: lỗi `-136`; hết tiền: `-115`).

### 4b.1 Lấy access token và refresh token

Theo tài liệu "Xác thực và ủy quyền cho Ứng dụng": access token sống **25 giờ**, refresh token sống **3 tháng** và
**chỉ dùng được 1 lần**; mỗi lần làm mới trả về refresh token mới.

**Cách nhanh (API Explorer)**: developers.zalo.me → *Công cụ* → *API Explorer* → chọn ứng dụng → loại
*OA Access Token* → chọn OA → *Cho phép* → sao chép **Access token** và **Refresh token**.

**Cách OAuth v4 (PKCE)**: tạo `code_verifier` 43 ký tự, `code_challenge = Base64URL(SHA256(code_verifier))` không padding,
thiết lập đường dẫn cấp quyền trên developers.zalo.me với callback URL, cho admin OA mở link, nhận `code` ở callback, rồi:

```bash
curl -X POST 'https://oauth.zaloapp.com/v4/oa/access_token' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'secret_key: <APP_SECRET>' \
  --data-urlencode 'code=<CODE>' --data-urlencode 'app_id=<APP_ID>' \
  --data-urlencode 'grant_type=authorization_code' --data-urlencode 'code_verifier=<CODE_VERIFIER>'
```

Dán `ZALO_ACCESS_TOKEN` và `ZALO_REFRESH_TOKEN` vào `backend/.env`. Sau đó **backend tự làm mới** (gửi
`refresh_token`, `app_id`, `grant_type=refresh_token` kèm header `secret_key`), lưu token xoay vòng vào Firestore
`system/zalo_oauth` (client không đọc được), gộp các lần làm mới đồng thời thành một request, và tự làm mới lại một lần
khi Zalo báo `-124`. Khi refresh token hỏng (quá 3 tháng không dùng, hoặc đã dùng ở nơi khác): lấy refresh token mới,
dán vào `.env`, khởi động lại backend; backend nhận ra token mới (so dấu vân tay) và nạp lại.

### 4b.2 Đăng ký template

Tạo trong **ZBS Account → Template** (Zalo khuyến nghị tạo qua giao diện). Tên tham số phải **khớp chính xác**
(code: `backend/lib/src/notifications/zalo/zalo_templates.dart`). Backend tự cắt giá trị theo độ dài tối đa của loại tham số.

**1. Mã OTP đăng nhập** (`ZALO_TEMPLATE_OTP`): loại *Template xác thực*, tag *Giao dịch*.
> Mã xác thực đăng nhập ứng dụng An ninh trường học của bạn là `<otp>`. Mã có hiệu lực trong 5 phút.
> Tuyệt đối không chia sẻ mã này cho người khác.

| Tham số | Loại | Tối đa |
|---|---|---|
| `otp` | OTP | 10 |

**2. Xác nhận đã nhận báo cáo** (`ZALO_TEMPLATE_REPORT_RECEIVED`): *Template tùy chỉnh*, tag *Giao dịch*.
> Tiêu đề: Đã nhận báo cáo sự cố
> Xin chào `<customer_name>`, phòng bảo vệ đã nhận báo cáo của bạn và sẽ cập nhật tình trạng xử lý qua Zalo.
> Bảng: Mã sự cố `<report_code>` · Loại `<incident_type>` · Vị trí `<location>` · Thời gian `<created_time>`

| Tham số | Loại | Tối đa |
|---|---|---|
| `customer_name` | Tên khách hàng | 30 |
| `report_code` | Mã số | 30 |
| `incident_type` | Nhãn tùy chỉnh | 30 |
| `location` | Địa chỉ | 200 |
| `created_time` | Thời gian | 20 |

**3. Cập nhật trạng thái báo cáo** (`ZALO_TEMPLATE_STATUS_UPDATE`): *Template tùy chỉnh*, tag *Chăm sóc khách hàng*.
> Tiêu đề: Cập nhật báo cáo sự cố
> Xin chào `<customer_name>`, báo cáo `<report_code>` của bạn đã chuyển sang trạng thái `<status>` lúc `<updated_time>`.

| Tham số | Loại | Tối đa |
|---|---|---|
| `customer_name` | Tên khách hàng | 30 |
| `report_code` | Mã số | 30 |
| `status` | Trạng thái giao dịch | 30 |
| `updated_time` | Thời gian | 20 |

**4. Cảnh báo sự cố mới cho bảo vệ** (`ZALO_TEMPLATE_GUARD_ALERT`): *Template tùy chỉnh*, tag *Giao dịch*.
> Tiêu đề: Có sự cố cần xử lý
> `<guard_name>` ơi, có sự cố `<incident_type>` mức `<severity>` tại `<location>` lúc `<reported_time>`.
> Mã sự cố `<report_code>`. Mở ứng dụng An ninh trường học để tiếp nhận.

| Tham số | Loại | Tối đa |
|---|---|---|
| `guard_name` | Tên khách hàng | 30 |
| `report_code` | Mã số | 30 |
| `incident_type` | Nhãn tùy chỉnh | 30 |
| `severity` | Nhãn tùy chỉnh | 30 |
| `location` | Địa chỉ | 200 |
| `reported_time` | Thời gian | 20 |

Nếu ZBS Account yêu cầu nút bấm cho loại template đã chọn, thêm nút mở trang web của trường.
Chờ Zalo duyệt (trạng thái **ENABLE**), rồi điền template ID vào `.env`. Gửi template chưa duyệt sẽ bị lỗi `-131`.

> **Khung giờ 22h-7h**: Zalo có thể chặn một số loại tin vào ban đêm (lỗi `-133`). Kiểm tra chính sách hiện hành của
> từng tag trong ZBS Account. Bảo vệ trực đêm luôn nhận push FCM song song, và app/nhật ký báo rõ khi Zalo từ chối.

### 4b.3 Chế độ gửi: development / production

`ZALO_ZNS_MODE` trong `backend/.env`:

- `development`: backend thêm `"mode": "development"` vào body. Zalo **chỉ gửi tới SĐT quản trị viên của ứng dụng hoặc OA**
  (thêm người thử nghiệm làm quản trị viên ứng dụng trên developers.zalo.me). Gửi tới số khác báo lỗi `-127`.
- `production`: gửi thật tới mọi người dùng, tính phí theo ZBS Account.

Đổi giá trị rồi khởi động lại backend, **không phải sửa code**. Màn đăng nhập và màn "Gửi thử" hiện chế độ đang dùng.

### 4b.4 Lỗi Zalo hiển thị cho người dùng (tiếng Việt)

| Trường hợp | Mã Zalo | Nhóm |
|---|---|---|
| Số không có tài khoản Zalo / số sai | `-118`, `-108` | `recipient` |
| Template chưa duyệt / sai ID / không thuộc OA / chỉ gửi admin | `-131`, `-109`, `-117`, `-127` | `template` |
| Hết hạn mức / hết số dư | `-144`, `-147`, `-115`, `-126`, `-137` | `quota` |
| Token hết hạn và không làm mới được | `-124` | `token` |
| Ngoài khung giờ cho phép | `-133` | `time_window` |
| Sai/thiếu/quá dài tham số | `-1121`, `-1122`, `-1124`, `-132`, `-111` | `template_params` |

Bảng đầy đủ: `backend/lib/src/notifications/zalo/zalo_error_catalog.dart`. Mỗi lần gửi được ghi vào `zalo_logs`
(thời gian, số nhận đã che `84912***678`, template, `tracking_id`, kết quả, mã lỗi) và xem ở **Quản lý → Nhật ký gửi tin**.

## 5. Chạy backend (máy tính của bạn)

```bash
cd backend
cp .env.example .env
dart pub get
dart run tool/generate_secret.dart
```

Dán chuỗi vừa in ra vào `OTP_PEPPER`, điền các biến Firebase/Zalo trong `.env`, rồi:

```bash
dart_frog dev
```

Backend chạy ở `http://localhost:8080`. Thiếu cấu hình thì backend in rõ biến nào thiếu (tiếng Việt) và dừng.
Bắt buộc: `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` (file service account), `OTP_PEPPER`,
`SMTP_USERNAME`, `SMTP_PASSWORD`. Zalo không bắt buộc.

Biến quan trọng khác trong `.env`:

- `BOOTSTRAP_ADMIN_EMAILS`: email luôn có quyền quản trị (dùng để tạo quản trị đầu tiên).
- `ALLOW_SELF_REGISTRATION`: `true` cho mọi email đăng nhập làm người báo; `false` chỉ cho email đã được quản trị tạo trước.
- `DUTY_HOTLINE`: số trực mặc định cho nút "Gọi trực an ninh" (quản trị đổi được trong app).
- `DUTY_GUARD_PHONES`: số bảo vệ trực luôn nhận cảnh báo Zalo, ngoài các bảo vệ bật "Đang trực" trong app.

Các API: `GET /config`, `POST /auth/register/request`, `POST /auth/register/verify`, `POST /auth/login`,
`POST /auth/password/forgot`, `POST /auth/password/reset`, `POST /me/password`, `DELETE /admin/users/{uid}`, `POST /images`, `GET /images/{id}`, `GET|PATCH /me`, `POST|DELETE /me/fcm_token`,
`POST /reports`, `POST /reports/{id}/status|assign|comments`, `POST /admin/users`, `PATCH /admin/users/{uid}`,
`PUT /admin/config`, `GET /admin/zalo/status`, `POST /admin/zalo/test_send`, `POST /admin/zalo/refresh_token`,
`POST /admin/broadcasts`, `POST /admin/broadcasts/{id}/end`, `POST /walks`,
`POST /walks/{id}/location|arrive|cancel|extend|sos`.

Backend quét các lượt "Đi cùng tôi" quá giờ mỗi 30 giây (`WalkService.startOverdueTimer`).
Chạy nhiều backend cùng lúc trên một Firestore (mỗi người một laptop) vẫn an toàn: mọi thay đổi trạng thái lượt đi
đi qua transaction (`WalkRepository.updateIfActive`), nên mỗi lượt quá giờ chỉ tạo đúng một báo cáo khẩn cấp.

## 6. Chạy app

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

- **Máy ảo Android**: `10.0.2.2` trỏ về máy tính đang chạy backend (giá trị mặc định nếu không truyền).
- **Điện thoại thật qua USB**: chạy `adb reverse tcp:8080 tcp:8080` rồi dùng `--dart-define=API_BASE_URL=http://127.0.0.1:8080`.
- **Android Studio**: *Run → Edit Configurations → Additional run args*: `--dart-define=API_BASE_URL=http://10.0.2.2:8080`.
- Bản debug cho phép HTTP tới backend local; bản release bắt buộc HTTPS.

Lần đầu dùng:

1. Bấm **Đăng ký ngay**, dùng một email trong `BOOTSTRAP_ADMIN_EMAILS`, nhập mã OTP nhận trong hộp thư: tài khoản
   này thành quản trị. Lần sau đăng nhập bằng tên đăng nhập + mật khẩu.
2. **Quản lý → Cấu hình trường**: nhập tên trường, số trực, danh sách khu vực.
3. **Quản lý → Tài khoản**: tạo tài khoản bảo vệ (email, số điện thoại tuỳ chọn). Bảo vệ **đăng ký bằng đúng email đó**
   (nhận OTP) để đặt tên đăng nhập và mật khẩu; vai trò bảo vệ được giữ nguyên. Sau đó bật **Đang trực**.
4. (Khi bật Zalo) **Quản lý → Gửi thử Zalo**: gửi thử từng template để kiểm tra cấu hình.

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
| `backend/test` | bảng mã lỗi Zalo, gateway Zalo (giả lập HTTP theo đúng tài liệu), OAuth v4 refresh, đăng ký email + OTP (chỉ tạo tài khoản khi đúng mã, trùng tên, nhận tài khoản tạo trước), đăng nhập mật khẩu (khoá sau 5 lần sai), PBKDF2 theo vector RFC, nghiệp vụ báo cáo (kể cả người dùng chưa có SĐT, Firestore lỗi lúc gửi thông báo), cảnh báo toàn trường, "Đi cùng tôi" (quá giờ, gia hạn, khẩn cấp, nhiều backend quét cùng lúc), kho ảnh, quên mật khẩu, xoá tài khoản, đăng nhập sai không lộ tài khoản, đổi mật khẩu, Zalo tắt không báo lỗi giả, giới hạn tần suất | 97 |
| `test/` | điều hướng theo vai trò, lọc/thống kê, API client, **widget test màn gửi báo cáo**, sheet khẩn cấp (chờ GPS), lịch sử ẩn danh, dữ liệu cảnh báo toàn trường và "Đi cùng tôi", **widget test đăng nhập/đăng ký/OTP** | 43 |

Test không gọi Zalo/Firebase/máy chủ mail thật (dùng giả lập và kho dữ liệu trong bộ nhớ chỉ có trong `test/`).
Mã chạy thật luôn gửi email/tin thật.

Chụp ảnh các màn (sáng/tối, chữ 200%) để rà soát giao diện:

```bash
flutter test tool/screenshots/capture_test.dart --update-goldens
```

## 9. Bảo mật

- Secret (mật khẩu ứng dụng Gmail, App ID/Secret Key/token Zalo) và service account chỉ nằm ở backend `.env` /
  Firestore `system/` (client bị chặn).
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
- Firestore Rules theo vai trò; client chỉ đọc. Ảnh: chỉ JPEG tối đa 700 KB, lưu ở `report_images` (client không đọc
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
