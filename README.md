<h1 align="center">
  <br>
  <img src="assets/images/app_icon.png" alt="Smart Note App" width="120">
  <br>
  Smart Note App (Offline-First)
  <br>
</h1>

<h4 align="center">Ứng dụng ghi chú cá nhân thông minh, tích hợp Trợ lý AI và đồng bộ hóa đám mây mượt mà.</h4>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-blue.svg?logo=flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2.svg?logo=dart"></a>
  <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/Firebase-Integrated-FFCA28.svg?logo=firebase"></a>
  <a href="https://sqlite.org/index.html"><img src="https://img.shields.io/badge/SQLite-FTS5-003B57.svg?logo=sqlite"></a>
  <a href="https://ai.google.dev/"><img src="https://img.shields.io/badge/Gemini-AI-8E75B2.svg?logo=google"></a>
</p>

---

## 🌟 Giới thiệu (Overview)

**Smart Note App** là một ứng dụng di động được xây dựng bằng **Flutter**, áp dụng kiến trúc **Clean Architecture** và mô hình **Offline-First**. Ứng dụng cho phép người dùng ghi chép đa phương tiện, quản lý công việc và tự động đồng bộ hóa dữ liệu lên Cloud Firestore. 

Đặc biệt, dự án tích hợp sâu **Google Gemini AI** giúp người dùng tóm tắt ghi chú, tự động tạo Checklist và gợi ý nhãn phân loại một cách thông minh.

## 🚀 Tính năng nổi bật (Key Features)

- 📝 **Rich Text Editor:** Soạn thảo văn bản phong phú (In đậm, nghiêng, màu sắc, danh sách).
- 🖼️ **Đa phương tiện:** Hỗ trợ chèn Hình ảnh, ghi âm giọng nói và Bảng vẽ tay (Drawing Board).
- ☁️ **Offline-First Sync:** Lưu trữ ngay lập tức bằng SQLite, tự động đồng bộ ngầm lên Firebase khi có mạng.
- 🤖 **Trợ lý Gemini AI:** Tự động tóm tắt văn bản, gợi ý tiêu đề, chuyển đổi văn bản thô thành To-do list.
- 🔒 **Bảo mật sinh trắc học:** Khóa ghi chú riêng tư bằng Vân tay / FaceID.
- 🔍 **Tìm kiếm toàn văn (FTS5):** Tìm kiếm nội dung cực nhanh bằng SQLite FTS5.
- 📄 **Xuất PDF:** Cho phép trích xuất ghi chú thành file PDF định dạng chuẩn.

---

## 🛠️ Công nghệ sử dụng (Tech Stack)

- **Frontend:** Flutter & Dart
- **Quản lý trạng thái (State Management):** Provider
- **Local Database:** SQLite (`sqflite`)
- **Cloud Database:** Firebase Firestore & Firebase Storage
- **Xác thực (Authentication):** Firebase Auth (Google Sign-In, Email/Password)
- **Trí tuệ nhân tạo (AI):** Firebase AI SDK (Mô hình `gemini-2.5-flash-lite`)
- **Quản lý ảnh phụ trợ:** Cloudinary API

---

## ⚙️ Hướng dẫn cài đặt (Getting Started)

Làm theo các bước dưới đây để cài đặt và chạy dự án trên máy tính của bạn.

### Yêu cầu hệ thống (Prerequisites)
* Đã cài đặt [Flutter SDK](https://docs.flutter.dev/get-started/install) (Phiên bản >= 3.x)
* Đã cài đặt Android Studio hoặc VS Code.
* Có tài khoản Firebase và Cloudinary.

### 1. Clone mã nguồn
```bash
git clone https://github.com/your-username/Smart-Note-App.git
cd Smart-Note-App
```

### 2. Tải các thư viện phụ thuộc
```bash
flutter pub get
```

### 3. Cấu hình biến môi trường (.env)
Dự án sử dụng file `.env` để bảo mật API Keys. Tạo một file tên là `.env` ở thư mục gốc của dự án (ngang hàng với `pubspec.yaml`) và điền các thông tin sau:
```env
# Cloudinary API Keys (Để upload ảnh)
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
CLOUDINARY_UPLOAD_PRESET=your_upload_preset
```

### 4. Kết nối Firebase
Dự án đã có sẵn các file cấu hình Firebase. Tuy nhiên, nếu bạn muốn kết nối với Firebase của riêng bạn:
1. Cài đặt [Firebase CLI](https://firebase.google.com/docs/cli).
2. Chạy lệnh cấu hình FlutterFire:
```bash
flutterfire configure
```

### 5. Chạy ứng dụng
Khởi chạy máy ảo Android (Emulator) hoặc cắm thiết bị thật, sau đó chạy lệnh:
```bash
flutter run
```

### 6. Build file cài đặt (APK)
Để xuất file APK phát hành cài đặt cho điện thoại:
```bash
flutter build apk --release
```
File APK sẽ nằm ở: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🏛️ Cấu trúc thư mục cốt lõi (Folder Structure)

```text
lib/
 ┣ core/           # Cấu hình UI, Colors, Themes chung
 ┣ models/         # Các Data class (Note, User, Checklist)
 ┣ providers/      # Nơi xử lý State và Logic nghiệp vụ (Auth, NoteProvider)
 ┣ screens/        # Các màn hình giao diện (UI)
 ┣ services/       # Giao tiếp với API, Database (SQLite, Firestore, Gemini AI)
 ┣ utils/          # Các hàm hỗ trợ (Format ngày, kiểm tra kết nối mạng)
 ┗ widgets/        # Các UI Components dùng chung (NoteCard, EmptyState)
```

---

## 👥 Nhóm tác giả (Authors)
* **Phạm Văn Minh** - Mã SV: 23010350 (Đại học Phenikaa)
* **Trần Thị Thu Hường** - Mã SV: 23010344 (Đại học Phenikaa)

*Giảng viên hướng dẫn: Cô Vũ Thị Ngọc Anh*

---
*Cảm ơn bạn đã quan tâm đến dự án Smart Note App! Nếu thấy hữu ích, hãy cho dự án 1 ⭐️ (Star) nhé!*
