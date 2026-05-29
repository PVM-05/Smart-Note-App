# Smart Note App

[![Flutter](https://img.shields.io/badge/Flutter-3.0.0%20%2B-02569B?logo=flutter\&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0--4.0-0175C2?logo=dart\&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Core%20%7C%20Auth%20%7C%20Firestore-FFCA28?logo=firebase\&logoColor=black)](https://firebase.google.com)
[![SQLite](https://img.shields.io/badge/SQLite-FTS5%20Enabled-003B57?logo=sqlite\&logoColor=white)](https://sqlite.org)
[![Provider](https://img.shields.io/badge/Provider-State%20Management-00b4ab?logo=flutter\&logoColor=white)](https://pub.dev/packages/provider)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20Architecture-green)](https://clean-architecture)

> **Smart Note App** là ứng dụng ghi chú thông minh hoạt động theo mô hình **Offline-First**, hỗ trợ đồng bộ hóa đám mây thời gian thực, thiết kế theo phong cách Google Keep và được trang bị trình soạn thảo Rich Text vô cùng mạnh mẽ.
> 
> Dự án được xây dựng bằng Flutter + Firebase + SQLite, áp dụng mô hình Clean Architecture để tối ưu khả năng mở rộng, bảo trì và hiệu năng siêu tốc.

---

## ✨ Tính năng nổi bật

### 1. Offline-First & Last-Writer-Wins Architecture
* **Lưu trữ tức thì:** Ghi chú được lưu ngay lập tức vào SQLite cục bộ.
* **Không độ trễ:** Hoạt động trơn tru kể cả khi hoàn toàn mất mạng internet.
* **Xử lý Xung đột Thông minh:** Sử dụng thuật toán **Last-Writer-Wins** (Dữ liệu mới nhất sẽ chiến thắng) để tự động đối chiếu thời gian chỉnh sửa (`updatedAt`) giữa Firebase và SQLite, ngăn chặn tuyệt đối việc mất dữ liệu khi người dùng chỉnh sửa cùng 1 ghi chú trên nhiều thiết bị.

### 2. Background Cloud Sync
* **Đồng bộ ngầm:** Tự động đẩy dữ liệu lên Firebase Cloud Firestore ngay khi có mạng trở lại.
* **Tối ưu băng thông:** Chỉ đồng bộ những bản ghi thực sự có sự thay đổi (Dựa trên cờ `is_synced`).
* **Đồng bộ tự động:** Hỗ trợ tính năng tự động tải (Pull) ghi chú mới nhất từ đám mây xuống.

### 3. Multimedia Rich Text Editor (Mới)
* **flutter_quill WYSIWYG:** Trình soạn thảo văn bản phong phú, cho phép In đậm, In nghiêng, Đổi màu chữ/nền, Heading (H1, H2...), Danh sách đạn, Checkbox công việc.
* **Chuyển đổi dữ liệu tự động:** Khả năng tương thích ngược siêu việt, tự động chuyển đổi các text thuần (plain text) cũ sang định dạng siêu nhẹ `Delta JSON`.
* **Đính kèm Đa phương tiện:** Hỗ trợ đính kèm hình ảnh và bản Ghi âm (`.m4a`) chất lượng cao. Audio có thể phát lại trực tiếp ngay trong ứng dụng với thanh thời gian thực.

### 4. Giao diện Google Keep-Style
* **Staggered Grid View:** Bố cục hiển thị lưới sinh động, thông minh.
* **Ghim (Pin) & Lưu trữ (Archive):** Sắp xếp ghi chú quan trọng lên đầu, cất gọn những ghi chú cũ.
* **Bộ chọn nhãn (Labels):** Nhóm các ghi chú dễ dàng.
* **Tìm kiếm toàn văn bản:** Tích hợp bộ lọc và tìm kiếm theo thời gian thực để truy xuất thông tin trong tíc tắc.

---

## 🏗️ Clean Architecture

Ứng dụng tuân thủ nghiêm ngặt mô hình Clean Architecture để tách biệt giao diện, logic trạng thái, và thao tác dữ liệu:

```mermaid
flowchart TB
    subgraph UI["UI Layer (Screens & Widgets)"]
        HS[HomeScreen]
        ES[EditorScreen]
        LS[LoginScreen]
    end

    subgraph STATE["State Layer (Providers)"]
        NP[NoteProvider]
        AP[AuthProvider]
        SP[SyncProvider]
    end

    subgraph REPO["Repository Layer (Interfaces & Impl)"]
        NR[NoteRepository]
        SR[SyncRepository]
    end

    subgraph SERVICE["Service Layer (APIs & Local)"]
        LNS[LocalNoteService]
        FTS[FirestoreService]
        PDS[PendingDeleteService]
    end

    subgraph STORAGE["Storage (Data Sources)"]
        SQ[(SQLite)]
        FB[(Firestore)]
    end

    UI --> STATE
    STATE --> REPO
    REPO --> SERVICE
    SERVICE --> STORAGE
```

---

## 🔄 Đồng bộ dữ liệu Offline-First (Last-Writer-Wins)

```mermaid
flowchart TD
    A[Người dùng Sửa Ghi chú] --> B[Lưu ngay vào SQLite cục bộ]
    B --> C{Có kết nối Internet?}

    C -- Có --> D[Lấy updatedAt từ Firestore]
    D --> E{Local mới hơn Cloud?}
    E -- Có --> F[Push lên Firestore]
    F --> G[Cập nhật is_synced = 1]
    
    E -- Không --> H[Kéo bản cập nhật từ Cloud về đè lên Local]

    C -- Không --> I[Giữ is_synced = 0]
    I --> J[Hàng đợi Background Sync Queue]
    J --> D
```

---

## 🗄️ ERD Database Design

```mermaid
erDiagram
    USERS {
        string id PK
        string email
        string displayName
        string photoUrl
    }

    NOTES {
        string id PK
        string userId FK
        string title
        string content "Delta JSON Format"
        string status "active / pinned / archived"
        string color
        int isSynced
        int createdAt
        int updatedAt
    }

    TAGS {
        string noteId PK,FK
        string tag
    }

    MEDIA_ITEMS {
        string id PK
        string noteId FK
        string type "image / audio"
        string url
    }

    USERS ||--o{ NOTES : owns
    NOTES ||--o{ TAGS : has
    NOTES ||--o{ MEDIA_ITEMS : contains
```

---

## 📂 Project Structure

```bash
lib/
├── models/         # Entity models (Note, User, SyncStatus)
├── providers/      # State Management (NoteProvider, SyncProvider, AuthProvider)
├── repositories/   # Abstract repositories & Implementations
├── screens/        # UI Screens (Home, Editor, Sync, Login)
├── services/       # Local database handlers, Firebase handlers
├── widgets/        # Reusable UI components (NoteCard, Toolbar)
└── main.dart       # App entry point
```

---

## 🛠️ Technologies Used

| Technology       | Purpose                     |
| ---------------- | --------------------------- |
| **Flutter**      | Cross-platform UI Framework |
| **Firebase Auth**| Google Sign-In & Authentication |
| **Cloud Firestore**| Realtime Cloud Database    |
| **Firebase Storage**| Audio & Image Storage       |
| **SQLite (sqflite)**| Offline Local Database      |
| **Provider**     | App State Management        |
| **flutter_quill**| Rich Text Editor (WYSIWYG)  |
| **just_audio / record** | Voice Note Playback & Recording |
| **flutter_dotenv**| Environment Variables Security |

---

## 🚀 Installation & Setup

### Requirements

* Flutter SDK >= 3.0.0
* Dart SDK >= 3.0.0
* Android Studio / VS Code

### Setup

```bash
# 1. Clone dự án
git clone <YOUR_REPOSITORY_URL>
cd smart-note-app

# 2. Xóa cache và nạp lại thư viện
flutter clean
flutter pub get
```

### Firebase & Môi trường Configuration
1. Tạo project trên Firebase Console. Thêm ứng dụng Android (`com.example.smart_note_app`).
2. Tải `google-services.json` và đặt vào thư mục `android/app/`.
3. Bật **Authentication** (Google Sign In), **Firestore**, và **Storage** trên Firebase Console.
4. Tạo file `.env` ở thư mục gốc của dự án để cấu hình các biến môi trường nếu có.

---

## 🧪 Testing Scenarios (Kịch bản Kiểm thử)

### 1. App ↔ Firebase Realtime
* Tạo ghi chú mới có chứa ảnh và định dạng chữ. 
* Quay lại màn hình chính, kiểm tra Firestore xem dữ liệu (JSON Delta) đã được tải lên chưa.

### 2. Multi-device Conflict Resolution
* Đăng nhập cùng 1 tài khoản trên 2 máy (A và B).
* Tắt mạng máy A, sửa Ghi chú 1.
* Trên máy B, sửa Ghi chú 1 và lưu lại lên Cloud.
* Bật mạng máy A, bấm "Đồng bộ ngay". App sẽ báo phát hiện Cloud có dữ liệu mới hơn và tự động kéo dữ liệu từ máy B về mà không đè mù dữ liệu cũ.

### 3. Offline Mode
* Tắt WiFi/4G. Viết ghi chú mới, thu âm giọng nói.
* Ghi chú vẫn lưu mượt mà. Đóng app mở lại dữ liệu vẫn còn.
* Bật WiFi lại, hệ thống tự động tải file thu âm lên Firebase Storage và đẩy ghi chú lên Firestore.

---

## 📦 Production Build

Để xuất file cài đặt APK tối ưu dung lượng và bảo mật mã nguồn:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

---

## 🔮 Future Improvements (Dự định Tương lai)

* AI Note Summarization (Tóm tắt ghi chú bằng AI)
* OCR Text Recognition (Trích xuất chữ từ hình ảnh)
* Real-time Collaboration (Cùng sửa ghi chú thời gian thực)
* Biometric Security (Khóa ghi chú bằng vân tay/FaceID với `local_auth`)
* Web/Desktop Native Support

---

*Được phát triển với niềm đam mê dành cho Flutter & Kiến trúc phần mềm hoàn hảo! 💙*
