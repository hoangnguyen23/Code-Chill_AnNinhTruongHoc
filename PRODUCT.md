# Product

## Register

product

## Users

App Android (mobile) dùng trong khuôn viên một trường đại học Việt Nam, ba nhóm người dùng:

- **Người báo** (sinh viên, giảng viên, nhân viên): thường mở app khi đang lo lắng hoặc hoảng, có thể đang đứng ngoài trời, cầm máy một tay. Việc cần làm: báo sự cố thật nhanh (khẩn cấp) hoặc báo chi tiết kèm ảnh, vị trí; sau đó theo dõi trạng thái và nhận tin Zalo.
- **Bảo vệ**: trực ca, kể cả ban đêm, nhận cảnh báo qua Zalo và push. Việc cần làm: thấy ngay sự cố mới nhất, mức độ, vị trí; nhận việc, cập nhật trạng thái, trao đổi với người báo.
- **Quản trị** (phòng bảo vệ / phòng hành chính): phân công, xem thống kê, quản lý tài khoản, kiểm tra kênh Zalo (gửi thử, nhật ký gửi tin).

## Product Purpose

Rút ngắn thời gian từ lúc có sự cố tới lúc bảo vệ có mặt, và cho người báo biết chắc báo cáo đã được tiếp nhận. Tin nhắn đi qua Zalo (ZBS Template Message) vì đó là kênh mọi người ở Việt Nam đều mở. Thành công là: báo khẩn cấp trong 2 chạm, bảo vệ trực nhận cảnh báo trong vài giây, người báo luôn biết báo cáo đang ở trạng thái nào.

## Brand Personality

Tin cậy, bình tĩnh, gần gũi.

Giọng của một phòng bảo vệ chuyên nghiệp nhưng thân thiện: câu ngắn, rõ việc cần làm, trấn an chứ không doạ. Nghiêm túc ở chỗ cần nghiêm túc (khẩn cấp, ẩn danh, lỗi gửi tin), nhẹ nhàng và nhanh ở mọi chỗ còn lại. Không đùa cợt, không làm người dùng hoảng thêm.

## Anti-references

- Phần mềm hành chính cũ: bảng dày đặc, chữ nhỏ, nhiều nút xám, khó dùng trên điện thoại.
- App fintech bóng bẩy: gradient, glassmorphism, số liệu khổng lồ để khoe, hiệu ứng thừa.
- Mạng xã hội / game hoá: emoji, huy hiệu, màu sặc sỡ, cảm giác giải trí.
- App báo động gây hoảng: đỏ tràn màn hình, nhấp nháy, còi. Màu đỏ chỉ dành cho khẩn cấp thật và lỗi.

## Design Principles

1. **Hành động nguy cấp phải nhanh nhất và khó nhầm nhất.** KHẨN CẤP luôn là vật thể nổi bật nhất trang chủ, gửi trong 2 chạm, có nút gọi trực ở mọi nơi người dùng có thể cần.
2. **Luôn cho biết chuyện gì vừa xảy ra.** Mỗi thao tác có phản hồi rõ: đã gửi, Zalo đã tới chưa, bao nhiêu bảo vệ đã nhận, lỗi là gì và làm gì tiếp.
3. **Bình tĩnh là mặc định, khẩn trương là ngoại lệ.** Giao diện yên, một màu nhấn; màu đỏ và rung chỉ xuất hiện khi thật sự khẩn cấp.
4. **Tôn trọng người báo.** Ẩn danh là thật (bảo vệ không thấy tên, số); chữ nói như người với người, không thuật ngữ kỹ thuật với người báo.
5. **Một tay, mọi điều kiện.** Vùng chạm lớn, nút chính ở tầm ngón cái, đọc được dưới nắng và trong ca đêm (sáng/tối).

## Accessibility & Inclusion

- WCAG 2.2 AA ở cả chế độ sáng và tối (chữ 4.5:1, chữ lớn và viền ô nhập 3:1).
- Cỡ chữ hệ thống tới 200% không vỡ bố cục; vùng chạm tối thiểu 48dp; dùng được bằng một tay.
- TalkBack đọc đúng: nút chỉ có icon có nhãn, chip trạng thái đọc "Trạng thái: ...", vùng thông báo lỗi là live region.
- Không dựa vào màu đơn thuần (trạng thái và mức độ luôn có chữ và icon).
- Tôn trọng tuỳ chọn giảm chuyển động của hệ thống; không nhấp nháy.
