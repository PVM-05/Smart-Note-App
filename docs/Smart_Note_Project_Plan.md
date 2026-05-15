# TÀI LIỆU CHI TIẾT: SMART NOTE - 5 NGÀY HOÀN THÀNH ĐỒ ÁN

Nhóm 2 người | 10h total | Từ 0 → Production APK v1.0.0
🎯 **Mục tiêu:** Clean Architecture + Full features + APK nộp thầy

---

## 📅 LỊCH 5 NGÀY (19:00-21:00)

| Ngày | Thời gian | Person A | Person B | Kết quả |
|---|---|---|---|---|
| **NGÀY 1** | 2h | Data Layer (SQLite + FTS5) | UI Layer (HomeScreen) | ✅ MVP chạy |
| **NGÀY 2** | 2h | SyncRepo (Firestore) | AuthProvider (Google) | ✅ Live sync |
| **NGÀY 3** | 2h | Biometric lock | Image picker | ✅ Security + Media |
| **NGÀY 4** | 2h | Audio recording | Notifications + Tags | ✅ Pro features |
| **NGÀY 5** | 1.5h | APK build + Tests | Submission package | ✅ v1.0.0 nộp thầy |

---

## 🚀 TỔNG KẾT NGÀY 3

**Vân tay khóa note + Chụp ảnh nén upload**
*(Biometric + Security):*
✅ `local_auth` setup
✅ `BiometricService` + Lock note 

*(logicImage + UI):*
✅ `image_picker` + `ImageCompressor`
✅ `MediaItem` model + `StorageService`

**Kết quả Test:**
✅ `local_auth`: Vân tay unlock note
✅ `image_picker`: Gallery + Storage upload
✅ UI: `LockedNoteCard` + Image gallery
✅ Test: Device thật (vân tay + camera)
✅ Video + Firebase Storage screenshot

---

## 📝 GIẢI THÍCH CHI TIẾT MÃ NGUỒN HIỆN TẠI

### 1. LoginScreen (`lib/screens/login_screen.dart`)
- **UI:** Nền Gradient và phong cách Glassmorphism tạo cảm giác hiện đại, mượt mà.
- **Luồng:** Giải thích chi tiết luồng đăng nhập Firebase. Sau khi đăng nhập thành công, bắt buộc phải đi qua màn hình đồng bộ (`SyncingScreen`) để đảm bảo dữ liệu cục bộ được cập nhật đầy đủ trước khi vào Home.
- **Biometric:** Đã có nền tảng để tích hợp Session đăng nhập cho phần vân tay.

### 2. SyncingScreen (`lib/screens/syncing_screen.dart`)
- **Các bước:** Xác thực -> Tải Firestore -> Lưu SQLite.
- **Trái tim đồng bộ:** Hàm `pullFromCloud()` thực hiện công việc kéo toàn bộ dữ liệu từ server về máy.

### 3. HomeScreen (`lib/screens/home_screen.dart`)
- **UI:** Sử dụng `SliverAppBar` (thanh tiêu đề co giãn) để tiết kiệm không gian khi cuộn.
- **Tính năng:** Tự động ưu tiên hiển thị các ghi chú được GHIM (Pinned) lên đầu.
- **Data Fetch:** Sử dụng `fetchNotes` để lấy dữ liệu từ SQLite cục bộ ngay khi vào app, giúp app hiển thị tức thì kể cả khi không có mạng.

---

## 🔒 TRẠNG THÁI HIỆN TẠI CỦA SINH TRẮC HỌC

1. **Đã có Logic xác thực vân tay:** Khi nhấn nút, app thực sự gọi hệ thống quét vân tay/khuôn mặt. Chỉ khi quét đúng mới cho phép đi tiếp.
2. **Chưa có Logic liên kết Session:** Hiện tại, nếu xác thực vân tay thành công, app chuyển thẳng tới màn hình đồng bộ. Nếu trước đó chưa từng đăng nhập Email/Password (Firebase chưa có User session), thì khi sang màn hình Sync sẽ bị lỗi (không biết tải dữ liệu của ai).
   > **Tóm lại:** Cần tích hợp thêm bước lưu trữ Token an toàn để "nhớ" tài khoản và đăng nhập tự động bằng vân tay sau khi thoát app.

---

## 🧪 HƯỚNG DẪN TEST DỮ LIỆU THỰC TẾ

Về mặt logic, toàn bộ các mắt xích để dữ liệu chảy từ App lên Firebase và ngược lại đã hoàn thiện:
1. **Chiều đi (App -> Firebase):** Tạo/Lưu ghi chú -> Lưu vào SQLite -> Gọi `SyncService` đẩy lên Firestore.
2. **Chiều về (Firebase -> App):** Đăng nhập máy mới -> `SyncingScreen` tự động kéo dữ liệu từ Firestore về.
3. **Xử lý xung đột:** Nếu sửa ghi chú offline, sau đó có mạng, app sẽ dựa vào `updatedAt` để giữ bản mới nhất.

### CÁC BƯỚC TEST KHUYẾN NGHỊ:
- **Bước 1: Kiểm tra Firestore (Database)**
  - Đăng nhập vào App, tạo một vài ghi chú.
  - Mở Firebase Console -> Firestore Database.
  - Kiểm tra xem có Collection `users -> [ID của bạn] -> notes` không. 
- **Bước 2: Kiểm tra Đồng bộ (Pull)**
  - Xóa dữ liệu App (hoặc gỡ cài đặt rồi cài lại).
  - Đăng nhập lại đúng tài khoản đó.
  - Quan sát `SyncingScreen`. Các ghi chú cũ phải tự động xuất hiện lại ở màn hình Home.
- **Bước 3: Kiểm tra Offline**
  - Tắt Wifi/4G, tạo một ghi chú (vẫn tạo được nhờ SQLite).
  - Bật lại Wifi/4G.
  - Chờ vài giây rồi kiểm tra trên Firebase Console xem ghi chú có tự động đồng bộ lên không.

> **Lưu ý quan trọng:** Đảm bảo đã cấu hình đúng file `google-services.json` trong `android/app` và đã bật dịch vụ Firestore trong Console!

---

## 🎨 PROMPT UI/UX NÂNG CẤP: "KHÔNG GIỐNG AI"

Sau khi hoàn thành bản APK cơ bản, bạn có thể sử dụng Prompt sau để AI tạo ra phiên bản UI cấp độ PRO (Material Design 3 + Custom Animations).

```text
Tạo UPGRADE UI cho Smart Note Flutter app theo đúng SPEC sau:

🎯 MỤC TIÊU: Material Design 3 + Custom animations + "Hand-crafted" feel
✅ KHÔNG dùng: Generic Card, ListView.builder, default transitions
✅ PHẢI dùng: Glassmorphism, Hero animations, Custom painters, Micro-interactions

## 1. COLOR SYSTEM (Exact HEX)
Primary: #2E75B6
Primary Dark: #1A3A5C  
Surface: #F5F5F5 / #121212 (dark)
Card: #FFFFFF / #1E1E1E (dark)
Accent: #FFF8E1 (pinned)
Success: #388E3C
Danger: #D32F2F

## 2. HOME SCREEN (Staggered MasonryGrid)
- flutter_staggered_grid_view: ^0.7.0
- Custom NoteCard: 
  * Glassmorphism blur (BackdropFilter)
  * Corner radius 20px + shadow neumorphism
  * Height tự động theo content (max 200px)
  * Swipe right: Pin (scale + glow)
  * Swipe left: Delete (scale down + fade)
  * Long press: Tags fly-out animation
- AppBar: 
  * SearchField với expand/collapse animation
  * Trailing: Filter chips (All/Pinned/Photos)
- FAB: Adaptive (scroll hide/show + scale 0.9→1.0)

## 3. NOTE EDITOR (Rich Editor)
- flutter_quill: ^9.2.1 (Rich text: bold/italic/list)
- Toolbar: Floating curved (Neumorphism)
- Media buttons: 
  * Camera/Gallery: Shimmer loading → Success tick
  * Mic: Waveform animation real-time
  * Schedule: Date picker với slide-up
- Auto-save: Progress ring (3s debounce)

## 4. ANIMATIONS (CustomPainter + Hero)
- NoteCard enter: Staggered (title→content→sync icon)
- Sync status: 
  * Orange → Lottie cloud upload → Green check
  * Error: Shake + retry pulse
- Biometric: Face ID ripple + success confetti
- Image upload: Progress circle → Thumbnail fade-in
- Dark mode: Smooth color lerp 300ms

## 5. CUSTOM WIDGETS (KHÔNG DÙNG PACKAGE)
- SyncStatusIcon: CustomPainter (cloud + checkmark)
- TagChip: Draggable + glow on hover
- AdaptiveFAB: Custom ScrollController listener
- EmptyState: Lottie hand-drawn + "No notes yet..."

## 6. DARK MODE (System aware)
- ThemeData(useMaterial3: true)
- Custom colors lerp light→dark
- Glassmorphism: BackdropFilter blur(10)

## 7. PERFORMANCE
- RepaintBoundary mọi Card
- ListenableBuilder thay Consumer
- CachedNetworkImage mọi thumbnail
- const constructor 100%

## CODE STRUCTURE YÊU CẦU:
lib/
├── core/
│   ├── app_theme.dart (Material 3 + Custom)
│   ├── app_colors.dart (Exact HEX)
│   └── animations.dart (Curves + Tweens)
├── widgets/
│   ├── custom/
│   │   ├── glass_card.dart
│   │   ├── sync_icon_painter.dart
│   │   └── adaptive_fab.dart
│   └── note_card.dart (Full custom)
├── screens/
│   ├── home_screen.dart (MasonryGrid + Animations)
│   └── note_editor.dart (Quill + Media)

## OUTPUT:
1. Full code 5 files chính: theme.dart, home_screen.dart, note_card.dart, note_editor.dart, glass_card.dart
2. Screenshots Figma-style mockups
3. Video demo 30s smooth animations
4. Perf metrics FPS 60 + rebuild count

## TONE: Professional Flutter dev (KHÔNG AI)
- Comments: "Pro tip: Use RepaintBoundary here"
- Variable names: descriptive + camelCase
- Code style: dart format --line-length 100

BẮT ĐẦU NGAY → UI PRO "Hand-crafted"! 👨‍💻✨
```

### KẾT QUẢ CẦN ĐẠT ĐƯỢC SAU PROMPT:
✅ Glassmorphism NoteCards (blur + neumorphism)
✅ Hero animations giữa screens
✅ CustomPainter Sync icons (cloud + check)
✅ Quill rich editor + floating toolbar
✅ Adaptive FAB (scroll-aware)
✅ Lottie micro-interactions

**Thực tế Trước / Sau:**
| TRƯỚC (Cơ bản) | SAU (UI Upgrade) |
|---|---|
| ❌ Default ListView | ✅ MasonryGrid glassmorphism |
| ❌ Flat Cards | ✅ Neumorphism + blur |
| ❌ No animations | ✅ Hero + Lottie |
| ❌ Basic FAB | ✅ Adaptive scroll |

**Cách chạy mã mới:**
1. Copy code trả về từ prompt.
2. Cài đặt các packages cần thiết (`flutter pub get`).
3. Chạy `flutter run` để trải nghiệm UI PRO.
