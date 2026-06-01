# MOBILE APP UI/UX DESIGN RULEBOOK

Version: 2.0

---

# MISSION

Bạn là Senior Mobile UI/UX Designer và Senior Flutter Developer.

Mọi giao diện được tạo ra phải:

* Tuân thủ Material Design 3
* Hỗ trợ Dark Mode
* Responsive trên nhiều kích thước màn hình
* Thân thiện với người dùng
* Không được tạo giao diện chỉ để "đẹp"
* Luôn ưu tiên khả năng sử dụng thực tế

---

# GOLDEN RULES

## MUST

* Thiết kế theo chuẩn Android hiện đại
* Dùng Theme thay vì hard-code màu
* Hỗ trợ Dark Mode
* Hỗ trợ Accessibility
* Hỗ trợ bàn phím
* Hỗ trợ màn hình nhỏ

## MUST NOT

* Hard-code kích thước màn hình
* Hard-code màu sắc
* Tạo UI quá nhiều hiệu ứng
* Đặt nút ở vị trí bất thường
* Tạo giao diện không theo Material Design

---

# SPACING SYSTEM

Sử dụng quy tắc 8dp.

Cho phép:

4
8
12
16
24
32
40
48
56
64

Không cho phép:

7
13
19
21
27

---

# TYPOGRAPHY

Chỉ sử dụng tối đa 4 cấp chữ.

Display: 32
Title: 20-24
Body: 14-16
Caption: 12

Không dùng quá 1 font family trong cùng màn hình.

---

# COLOR SYSTEM

Không dùng:

Colors.red
Colors.blue
Colors.green
Colors.orange

Trực tiếp trong UI.

Luôn dùng:

Theme.of(context).colorScheme

---

# BUTTON RULES

Chiều cao tối thiểu:

48dp

Bo góc:

12dp

Touch target:

> = 48x48dp

---

# CARD RULES

Border Radius:

16dp

Padding:

16dp

Elevation:

0-2

Không dùng card quá nhiều bóng đổ.

---

# APP BAR RULES

Tối đa:

3 action buttons

Tiêu đề ngắn gọn.

Không nhét nhiều icon.

---

# BOTTOM NAVIGATION RULES

Tối đa:

5 tabs

Mỗi tab phải có:

* Icon
* Label

Không tạo Bottom Navigation 6+ tab.

---

# FORM RULES

Khoảng cách giữa các field:

16dp

Input height:

56dp

Luôn xử lý bàn phím.

Bắt buộc:

SafeArea
SingleChildScrollView
viewInsets.bottom

---

# DIALOG RULES

Chiều cao:

< 80% màn hình

Phải có:

* Hủy
* Xác nhận

Không dùng:

OK
YES
NO

---

# BOTTOM SHEET RULES

Luôn dùng:

isScrollControlled: true

Có drag handle.

Không để nội dung bị keyboard che.

---

# LIST RULES

Item height:

56-72dp

Không tạo item quá nhỏ.

---

# LOADING STATE

Mọi request dữ liệu phải có loading.

Không được hiển thị màn hình trắng.

Cho phép:

* CircularProgressIndicator
* Skeleton
* Shimmer

---

# EMPTY STATE

Mọi danh sách rỗng phải có:

* Icon
* Tiêu đề
* Mô tả
* CTA Button

---

# ERROR STATE

Mọi lỗi phải có:

* Error message
* Retry button

---

# ACCESSIBILITY

Touch target >= 48dp

Text >= 12sp

Đảm bảo tương phản màu sắc.

Không dùng màu làm phương tiện truyền tải thông tin duy nhất.

---

# RESPONSIVE RULES

Sử dụng:

MediaQuery
LayoutBuilder

Không sử dụng:

width: 350
height: 700

---

# ANIMATION RULES

Thời lượng:

200-300ms

Chỉ sử dụng animation khi có mục đích.

Không dùng animation gây phân tâm.

---

# CRITICAL UI MISTAKES TO AVOID

## Keyboard Covering Form

Sai:

TextField bị bàn phím che.

Đúng:

Scroll được khi keyboard xuất hiện.

---

## Bottom Sheet Overflow

Sai:

RenderFlex overflowed by XX pixels.

Đúng:

BottomSheet cuộn được.

---

## FAB Covering Content

Sai:

FloatingActionButton che item cuối.

Đúng:

List có padding bottom phù hợp.

---

## Bottom Navigation Covering Content

Sai:

Item cuối bị che.

Đúng:

SafeArea + padding.

---

## Nested Scroll Bug

Sai:

ListView bên trong SingleChildScrollView.

Đúng:

CustomScrollView hoặc Slivers.

---

## Unbounded Height Error

Sai:

Expanded bên trong Column không giới hạn chiều cao.

Đúng:

Bọc bằng SizedBox hoặc ConstrainedBox.

---

## Massive Widget Tree

Sai:

Widget dài >1000 dòng.

Đúng:

Tách component.

---

## Too Many Actions

Sai:

AppBar chứa 5-8 icon.

Đúng:

Tối đa 3 icon.

---

## Tiny Touch Area

Sai:

IconButton quá nhỏ.

Đúng:

Touch target >=48dp.

---

## Hardcoded Strings

Sai:

Text hiển thị viết trực tiếp.

Đúng:

Sử dụng localization hoặc constants.

---

## Hardcoded Colors

Sai:

Colors.blue

Đúng:

ColorScheme.primary

---

## Missing Empty State

Sai:

Danh sách rỗng nhưng màn hình trống.

Đúng:

Có Empty State.

---

## Missing Error State

Sai:

API lỗi nhưng không báo.

Đúng:

Hiển thị lỗi + Retry.

---

## Missing Loading State

Sai:

Đứng im vài giây.

Đúng:

Loading rõ ràng.

---

## Overuse of Dialogs

Sai:

Mọi hành động đều bật dialog.

Đúng:

Chỉ dùng khi cần xác nhận.

---

## Deep Navigation

Sai:

Điều hướng 5-6 tầng màn hình.

Đúng:

Giữ flow đơn giản.

---

## UX Smell Detection

Nếu xuất hiện bất kỳ dấu hiệu nào sau đây, phải đề xuất cải tiến:

* Người dùng cần >3 lần chạm để làm tác vụ chính
* Có nhiều hơn 2 FAB
* Có nhiều hơn 5 tab
* AppBar chứa quá nhiều icon
* Form dài hơn 1 màn hình
* Nút quan trọng nằm ngoài vùng ngón tay cái
* Người dùng phải cuộn nhiều mới thấy CTA
* Chức năng bị ẩn quá sâu
* Không có feedback sau khi thao tác

---

# FLUTTER CODE QUALITY RULES

Không được:

* BuildContext sử dụng sau async gap
* setState sau dispose
* Memory leak
* Stream không dispose
* Controller không dispose
* Hard-code dimensions
* Hard-code colors

Phải:

* dispose() đầy đủ
* mounted check
* const widget khi có thể
* chia nhỏ widget
* ưu tiên StatelessWidget

---

# FINAL REVIEW CHECKLIST

Trước khi hoàn thành UI, phải tự kiểm tra:

[ ] Material Design 3
[ ] Dark Mode
[ ] Responsive
[ ] Accessibility
[ ] Empty State
[ ] Loading State
[ ] Error State
[ ] Keyboard Safe
[ ] No Overflow
[ ] No Hidden Content
[ ] No Hardcoded Colors
[ ] No Hardcoded Dimensions
[ ] Touch Target >=48dp
[ ] AppBar <=3 actions
[ ] Bottom Navigation <=5 tabs
[ ] FAB không che nội dung
[ ] Dialog đúng chuẩn
[ ] Bottom Sheet đúng chuẩn
[ ] Flutter Best Practices
[ ] Không có UX Smell

---

# PHẦN 3: QUY TẮC GIAO DIỆN & CHỨC NĂNG - MÀN EDITOR (MOBILE)

## 3.1 Acceptance Criteria

### 3.1.1 Counters: Đếm từ & ký tự

**Định nghĩa**

* **Char Count**: tổng số ký tự hiển thị trong nội dung, bao gồm khoảng trắng, dấu câu và ký tự xuống dòng (`\n`).
* **Word Count**: số lượng token được tách theo khoảng trắng; bỏ qua chuỗi rỗng và dòng trống.
* Hỗ trợ tiếng Việt có dấu và Unicode đầy đủ.

**Hiển thị**

* Bộ đếm hiển thị ở cuối màn Editor, ngay dưới vùng nhập nội dung.
* Bộ đếm chỉ xuất hiện khi editor đang có nội dung hoặc đang được focus.
* Khi nội dung rỗng và editor không focus, bộ đếm phải ẩn hoàn toàn.

**Giới hạn**

* Max mặc định: 2000 ký tự cho body content.
* Khi đạt 90% giới hạn: chuyển sang trạng thái warning.
* Khi vượt quá giới hạn: chuyển sang trạng thái error và disable nút submit/gửi.
* Limit có thể cấu hình theo từng màn hình hoặc từng loại note nếu nghiệp vụ yêu cầu.

### 3.1.2 Text Toolbar

**Các nút bắt buộc**

* Bold
* Italic
* Underline
* List / Bullet list
* Undo
* Redo

**Trạng thái**

* Active state: nút đang áp dụng định dạng phải có nền highlight rõ ràng.
* Inactive state: nút dùng màu trung tính, không gây chú ý quá mức.

**Hành vi**

* Khi người dùng chọn text, toolbar phải xuất hiện để áp dụng định dạng.
* Khi bỏ chọn hoặc cursor rời vùng chọn, toolbar có thể ẩn hoặc trở về trạng thái chờ.
* Nếu đang ở checklist mode thì ưu tiên thao tác danh sách thay vì rich text formatting.

## 3.2 UX Thresholds & Debounce

* Khi người dùng nhập gần ngưỡng giới hạn, hiển thị thông báo ngắn: ví dụ “Còn 100 ký tự có thể nhập”.
* Bộ đếm phải cập nhật theo nhịp debounce 300ms để tránh render liên tục khi gõ nhanh.
* Data state phải cập nhật ngay lập tức; debounce chỉ áp dụng cho phần hiển thị.

## 3.3 Test Cases / Edge Cases

* Checklist mode: khi chọn List, nội dung mới phải được đưa vào dạng danh sách rõ ràng, phục vụ note dạng checklist.
* Title rỗng: vẫn cho phép submit nếu body có nội dung, trừ khi nghiệp vụ màn hình yêu cầu khác.
* Nội dung lớn hơn 2000 ký tự: màn hình phải scroll mượt, keyboard không che nội dung.
* Tiếng Việt có dấu: không làm sai vị trí dấu hoặc tách ký tự hiển thị.
* Xuống dòng: newline phải được tính vào char count và hiển thị đúng trên preview.
* Limit theo dòng: nếu có quy ước riêng thì newline (`\n`) vẫn tính là ký tự.

## 3.4 Ghi chú triển khai

* Không hard-code màu sắc; ưu tiên `Theme.of(context).colorScheme`.
* Touch target của các nút toolbar phải đạt tối thiểu 48dp.
* Counter và toolbar phải hoạt động tốt trên màn hình nhỏ và khi bàn phím mở.
