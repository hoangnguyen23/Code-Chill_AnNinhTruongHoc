# DESIGN.md: An ninh trường học

Tài liệu chốt hướng thiết kế cho app Android "Báo cáo sự cố an ninh trong trường".
Được lập theo quy trình của skill `/design-taste-frontend` trước khi viết UI, sau đó cập nhật
theo kết quả audit `/impeccable` (xem mục 12).

## 1. Design read

> Đọc brief là: **app Android cho trường đại học Việt Nam**, phục vụ người báo (sinh viên,
> giảng viên, nhân viên), bảo vệ và quản trị; ngôn ngữ **trust-first, sẵn sàng cho tình huống
> khẩn cấp**; dựa trên **Material 3 chính thức của Flutter** với token tuỳ chỉnh tiết chế.

Skill `/design-taste-frontend` tự ghi rõ nó không dành cho app native mobile và khuyên dùng
Material trực tiếp. Vì vậy chỉ áp dụng các phần dùng được: đọc brief, thang đo, khoá màu, khoá
bo góc, trạng thái rỗng/lỗi/loading, tương phản, dark mode, và danh sách "dấu hiệu AI" cần tránh
(không gạch ngang dài trong chữ hiển thị, không tên giả kiểu "Nguyễn Văn A", không số liệu giả).

Người dùng thật: một sinh viên đang hoảng vì thấy đánh nhau ở hành lang, một bảo vệ đang trực
đêm cầm máy bằng một tay, một cán bộ quản trị ngồi máy tính bảng xem thống kê. Mọi quyết định
ưu tiên: **đọc được ngay, bấm trúng ngay, không nhầm hành động nguy hiểm**.

## 2. Thang đo

| Thang | Màn người báo | Màn bảo vệ / quản trị | Lý do |
|---|---|---|---|
| DESIGN_VARIANCE | 3 | 3 | Trust-first: bố cục dự đoán được, căn trái, lưới đều |
| MOTION_INTENSITY | 2 | 2 | Chỉ chuyển cảnh mặc định M3 và phản hồi trạng thái |
| VISUAL_DENSITY | 4 | 6 | Người báo cần thoáng; bảo vệ cần quét nhanh nhiều sự cố |

## 3. Design system

- **Material 3** (`useMaterial3: true`) của Flutter, không pha thư viện UI khác.
- Icon: một họ duy nhất **Material Symbols Rounded** (`Icons.*_rounded`), không tự vẽ SVG.
- Font: **Be Vietnam Pro** (OFL, đóng gói trong `assets/fonts`). Thiết kế cho tiếng Việt,
  dấu thanh rõ ở cỡ nhỏ, chạy offline (không tải font qua mạng lúc khẩn cấp).

## 4. Màu (khoá màu)

Một accent duy nhất là **Cobalt** cho mọi hành động thông thường. **Đỏ khẩn cấp chỉ dùng cho**
nút KHẨN CẤP, mức độ "Khẩn cấp" và lỗi. Vàng hổ phách / xanh lá chỉ xuất hiện trong chip trạng
thái. Màu không bao giờ là tín hiệu duy nhất: luôn có chữ và icon đi kèm.

| Token | Light | Dark | Ghi chú |
|---|---|---|---|
| seed / primary | `#1F4FA3` | sinh từ seed (≈ `#AEC6FF`) | Chữ trắng trên primary: 7.7:1 |
| emergency | `#C4231C` | `#C4231C` | Chữ trắng trên nền: 5.8:1, giữ nguyên ở 2 chế độ |
| surface nền | sinh từ seed, không trắng tuyệt đối | sinh từ seed, không đen tuyệt đối | |

Trạng thái báo cáo (nền tonal / chữ):

| Trạng thái | Light nền / chữ | Dark nền / chữ | Icon |
|---|---|---|---|
| Đã gửi | `#E6E9EF` / `#353E4D` | `#2A313C` / `#D3DAE6` | `outbox_rounded` |
| Đã tiếp nhận | `#DCE6F8` / `#173E86` | `#1B3260` / `#C9D9FA` | `assignment_turned_in_rounded` |
| Đang xử lý | `#FBEBC8` / `#6E4400` | `#4A3510` / `#F5D9A0` | `pending_actions_rounded` |
| Đã giải quyết | `#D6EFDF` / `#145530` | `#173D27` / `#B9E5C9` | `task_alt_rounded` |
| Từ chối | `#ECEAEA` / `#4A4545` | `#343131` / `#DAD5D5` | `block_rounded` |

Mức độ: Thấp (viền xám), Trung bình (hổ phách tonal), Cao (cam tonal `#FDE3D3`/`#8A3500`,
dark `#4F2A12`/`#F8C9A8`), **Khẩn cấp (nền đỏ đặc, chữ trắng)**.

## 5. Chữ

Be Vietnam Pro, `letterSpacing: 0` (dấu tiếng Việt cần khoảng thở), line-height tối thiểu 1.4
cho đoạn văn để không cắt dấu.

| Vai trò | Cỡ / dòng | Độ đậm |
|---|---|---|
| headlineSmall (tiêu đề màn) | 24 / 32 | 600 |
| titleLarge | 20 / 28 | 600 |
| titleMedium | 16 / 24 | 600 |
| bodyLarge (mặc định) | 16 / 24 | 400 |
| bodyMedium | 14 / 20 | 400 |
| labelLarge (nút) | 15 / 20 | 600 |
| labelMedium | 12 / 16 | 500 |

Mã sự cố, giờ, số liệu thống kê dùng `FontFeature.tabularFigures()`.

## 6. Hình khối (khoá bo góc)

Một quy tắc duy nhất, áp dụng mọi nơi:

- **Nút bấm**: viên thuốc (stadium), cao tối thiểu 52dp cho nút chính.
- **Thẻ / khối nội dung**: bo 16.
- **Ô nhập**: bo 12, viền rõ (outline), nhãn nằm trên ô, lỗi nằm dưới ô.
- **Chip / badge**: bo 8.
- **Bottom sheet**: bo 24 ở cạnh trên.
- **Nút KHẨN CẤP**: khối bo 24, cao tối thiểu 120dp, phủ hết bề ngang. Đây là ngoại lệ có chủ
  đích: nó là "vật thể" lớn nhất màn hình, không phải một nút thường.

Thẻ chỉ dùng khi phân tầng thật (báo cáo trong danh sách, khối khẩn cấp). Các nhóm còn lại dùng
khoảng trắng và tiêu đề nhóm, không lồng thẻ trong thẻ.

## 7. Khoảng cách

Lưới 4dp. Lề màn hình 16. Khoảng giữa các nhóm 24. Đệm trong thẻ 16. Vùng chạm tối thiểu 48dp.

## 8. Chuyển động

- Dùng chuyển trang mặc định của M3. `AnimatedSwitcher` 200ms cho đổi trạng thái (gửi xong,
  lỗi, loading). Không có vòng lặp vô hạn, không parallax.
- Khi hệ thống bật giảm chuyển động (`MediaQuery.disableAnimations`), mọi hiệu ứng về 0ms.
- Rung nhẹ (`HapticFeedback.heavyImpact`) khi mở và khi gửi khẩn cấp.

## 9. Kiến trúc thông tin theo vai trò

Thanh điều hướng dưới (NavigationBar), đích khác nhau theo vai trò:

- **Người báo**: Trang chủ (khối KHẨN CẤP, gửi báo cáo, báo cáo gần đây), Báo cáo của tôi, Cài đặt.
- **Bảo vệ**: Sự cố (hàng đợi có lọc), Được giao cho tôi, Cài đặt. Nút "Báo cáo" vẫn có ở trang Sự cố.
- **Quản trị**: Tổng quan (thống kê), Sự cố (lọc + phân công), Quản lý (tài khoản, cấu hình,
  gửi thử Zalo, nhật ký gửi tin), Cài đặt.

Nút "Gọi trực an ninh" xuất hiện ở: màn đăng nhập, khối khẩn cấp, sheet khẩn cấp.

## 10. Luồng khẩn cấp

1. Chạm khối KHẨN CẤP (1 chạm) → mở sheet toàn màn, rung, bắt đầu lấy GPS ngay.
2. Sheet có: chip loại sự cố (tuỳ chọn, mặc định "Khác"), ô ghi chú ngắn (tuỳ chọn),
   công tắc ẩn danh, nút **Gửi cảnh báo ngay** (đỏ, 64dp) và **Gọi trực an ninh**.
3. Gửi xong: hiện mã sự cố cỡ lớn, số bảo vệ đã nhận cảnh báo Zalo, nút gọi trực.

Hai chạm là đủ (không bắt giữ nút) để người dùng TalkBack và người đang run tay đều dùng được,
nhưng không thể gửi nhầm chỉ bằng một chạm vô tình.

## 11. Trạng thái bắt buộc cho mọi màn có dữ liệu

- **Loading**: khối skeleton đúng hình dạng hàng thật, không spinner giữa màn (trừ nút đang gửi).
- **Rỗng**: icon + một dòng tiêu đề + một dòng gợi ý + hành động (nếu có).
- **Lỗi**: nói rõ chuyện gì xảy ra và cần làm gì, có nút "Thử lại". Lỗi form nằm ngay dưới ô.
- **Offline**: banner mỏng trên cùng; nút khẩn cấp vẫn mở được và gợi ý "Gọi trực an ninh".

## 12. Văn phong

- Tiếng Việt, câu thường (không viết hoa toàn bộ trừ chữ "KHẨN CẤP"), động từ rõ:
  "Gửi báo cáo", "Tiếp nhận", "Bắt đầu xử lý", "Đánh dấu đã giải quyết", "Từ chối".
- Không dùng gạch ngang dài trong chữ hiển thị; dùng dấu hai chấm, dấu phẩy hoặc xuống dòng.
- Lỗi = chuyện gì xảy ra + làm gì tiếp. Ví dụ: "Số này chưa có tài khoản Zalo. Hãy dùng số đã
  đăng ký Zalo hoặc liên hệ quản trị."
- Không tên mẫu giả, không số liệu thống kê bịa; màn thống kê chỉ hiện dữ liệu thật.

## 13. Accessibility

- Tương phản tối thiểu WCAG AA (4.5:1 chữ thường, 3:1 chữ lớn và viền ô nhập) ở cả 2 chế độ.
- Hỗ trợ cỡ chữ hệ thống tới 200%: không cố định chiều cao chứa chữ, cho phép xuống dòng.
- Mọi icon-only có `tooltip`/`Semantics`. Chip trạng thái đọc đủ "Trạng thái: Đang xử lý".
- Thứ tự focus theo thứ tự đọc. Ô OTP dùng `autofillHints: oneTimeCode`.

## 14. Ghi chú sửa đổi từ /impeccable

Audit chạy ngày 19/10/2026 trên ảnh chụp thật của từng màn (golden test với font Be Vietnam Pro và
Material Icons, cả sáng/tối và cỡ chữ 200%; công cụ ở `tool/screenshots/capture_test.dart`).
Bối cảnh chiến lược ở `PRODUCT.md`.

Điểm trước khi sửa: Accessibility 2, Performance 3, Responsive 2, Theming 3, Anti-patterns 2 (12/20).

| Mức | Vấn đề tìm thấy | Đã sửa |
|---|---|---|
| P1 | Nút "Gửi cảnh báo ngay" nằm cuối sheet, có thể phải cuộn mới thấy (phá cam kết 2 chạm) | Ghim nút gửi và nút gọi trực ở chân sheet, phần chi tiết cuộn phía trên |
| P1 | Chữ đỏ "KHẨN CẤP" trên nền tối chỉ khoảng 3:1 | Thêm token `emergencyText` (sáng `#B3211A` ~6:1, tối `#FFB4A9` ~9.6:1) |
| P1 | Cỡ chữ 200%: tiêu đề 2 dòng trên AppBar bị cắt; thanh lọc cao cố định 64dp cắt chip | AppBar một dòng, tên trường chuyển xuống thân trang; thanh lọc co giãn theo nội dung |
| P1 | Chữ nhỏ 11-12px ở chip và chú thích | Cỡ tối thiểu 13px (labelMedium, bodySmall) |
| P2 | Viền trái màu đỏ trên thẻ báo cáo khẩn cấp (mẫu side-stripe bị cấm) | Viền đầy đủ 1.5dp màu `emergencyText` + icon SOS |
| P2 | "Khẩn cấp" lặp 2 lần (tiêu đề + nhãn mức độ) | Ẩn nhãn mức độ khi là báo cáo khẩn cấp; nhãn mức độ ghi rõ "Mức độ: Cao" |
| P2 | Tổng quan: 4 thẻ số liệu giống hệt nhau, ô "Khẩn cấp" tô đỏ đặc cho một con số thống kê | Một bảng tóm tắt 2x2 có đường kẻ; số đỏ chỉ khi còn sự cố khẩn cấp chưa đóng |
| P2 | Màn chi tiết: "Nhận xử lý" trùng ý với "Tiếp nhận"; không có nút chính | Bước tiếp theo là nút chính (filled), còn lại tonal; "Nhận xử lý" chỉ hiện khi chưa có người giữ ở trạng thái sau "Đã gửi" |
| P2 | Banner "nghỉ ca" dùng tông tím/hồng (tertiary) ngoài bảng màu | Dùng `secondaryContainer`, nút hành động xuống dòng riêng |
| P2 | Icon khẩn cấp là dấu sao y tế, dễ hiểu nhầm | Đổi sang icon SOS ở mọi nơi |
| P2 | Câu "Chưa có báo cáo đã giải quyết" mâu thuẫn với ô "Đã giải quyết 1" | "Chưa đủ dữ liệu thời gian giải quyết" |
| P2 | Nhật ký gửi tin chỉ hiện "Lỗi -118", phải mở chi tiết mới biết lý do | Hiện luôn thông báo tiếng Việt dưới dòng lỗi |
| P2 | Cảnh báo cấu hình Zalo (thiếu template) hiển thị như ghi chú thông tin | Hiển thị như lỗi (errorContainer) |
| P3 | Nền xem ảnh đen tuyệt đối; thumbnail giải mã ảnh gốc 1600px | Token `viewerBackground`; `cacheWidth` theo kích thước hiển thị |
| P3 | Cuộn lên lỗi form vẫn có animation khi máy bật giảm chuyển động | Nhảy thẳng khi `disableAnimations` |
| P3 | Màn đăng nhập: icon căn giữa nhưng chữ căn trái | Căn trái đồng bộ |

Đã kiểm lại bằng ảnh chụp sau khi sửa. Ghi chú: viền đen quanh FAB trong ảnh golden là do Flutter
tắt bóng đổ khi test, không xuất hiện trên máy thật.
