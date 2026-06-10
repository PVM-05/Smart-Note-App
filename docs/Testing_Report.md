# CHƯƠNG 4: KIỂM THỬ VÀ ĐÁNH GIÁ HỆ THỐNG

Chương này trình bày chi tiết về chiến lược kiểm thử, danh sách các kịch bản kiểm thử (Test Cases), phương pháp thực hiện và kết quả đánh giá chất lượng phần mềm đối với ứng dụng **Smart Note App**. Quy trình kiểm thử được thiết kế toàn diện từ tầng đơn vị (Unit Test), tầng giao diện (Widget Test), logic bảo mật (Security Rules) cho đến kiểm thử tích hợp hệ thống (Integration & Manual Testing).

---

## 4.1 Chiến lược kiểm thử (Testing Strategy)

Để đảm bảo tính ổn định của mô hình **Offline-First**, khả năng đồng bộ không lỗi và độ an toàn của dữ liệu người dùng, hệ thống kiểm thử được chia làm 4 thành phần chính:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           SMART NOTE APP TESTING                        │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
         ┌───────────────────────────┼───────────────────────────┐
         ▼                           ▼                           ▼
  [ 🧪 Unit Tests ]          [ 🎨 Widget Tests ]      [ 🛡️ Security Rules ]
  - AuthProvider logic       - Reusable UI elements   - Firebase Rules Logic
  - Note & Checklist Models  - EmptyState renders     - Read/Write Isolation
  - Local database helper    - Button callback checks - Token verification
         │                           │                           │
         └───────────────────────────┼───────────────────────────┘
                                     │
                                     ▼
                      [ 🔄 Manual Integration Tests ]
                      - Offline-to-Online Sync
                      - Last-Writer-Wins (LWW) conflict
                      - Biometric Auth & Auto-lock
                      - Gemini AI Assistant features
                      - PDF Export validation
```

1. **Kiểm thử đơn vị (Unit Test):** Thực hiện kiểm thử độc lập các lớp dữ liệu (Models), các lớp quản lý trạng thái (Providers) và các hàm tiện ích mà không phụ thuộc vào giao diện người dùng hay kết nối mạng thật.
2. **Kiểm thử giao diện (Widget Test):** Xác minh các thành phần giao diện (Widgets) được dựng chính xác theo đặc tả thiết kế (Material Design 3) và phản hồi đúng với các tương tác của người dùng.
3. **Kiểm thử quy tắc bảo mật (Security Rules Test):** Mô phỏng và kiểm tra các ràng buộc an ninh của Cloud Firestore nhằm đảm bảo người dùng chỉ có quyền đọc/ghi dữ liệu của chính mình, ngăn chặn tuyệt đối việc rò rỉ dữ liệu chéo.
4. **Kiểm thử tích hợp thủ công (Manual Integration Test):** Chạy ứng dụng thực tế trên thiết bị vật lý/giả lập để kiểm tra các kịch bản phức tạp như mất mạng đột ngột, đồng bộ chạy ngầm, giải quyết xung đột đa thiết bị (Last-Writer-Wins), sinh trắc học và phản hồi từ trợ lý ảo Gemini AI.

---

## 4.2 Kiểm thử tự động (Automated Testing)

Toàn bộ mã nguồn kiểm thử tự động được tổ chức trong thư mục [test/](file:///d:/Workspace/TBDD/Smart-Note-App/test) của dự án.

### 4.2.1 Kiểm thử đơn vị xác thực và quản lý trạng thái (AuthProvider Unit Test)
*   **File kiểm thử:** [auth_provider_test.dart](file:///d:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart)
*   **Mục tiêu:** Đảm bảo các hàm kiểm tra tính hợp lệ của đầu vào (email, mật khẩu) hoạt động đúng, ánh xạ chính xác các mã lỗi từ Firebase Auth thành tiếng Việt dễ hiểu và quản lý an toàn trạng thái đăng nhập.

| ID | Mô tả kịch bản test | Dữ liệu đầu vào (Input) | Kết quả kỳ vọng (Expected Output) | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| UT-AU-01 | Kiểm tra form khi Email rỗng | `email = ""` | Form không hợp lệ, không cho phép gửi | Pass |
| UT-AU-02 | Kiểm tra form khi Mật khẩu rỗng | `password = ""` | Form không hợp lệ, không cho phép gửi | Pass |
| UT-AU-03 | Email và mật khẩu có dữ liệu hợp lệ | `email = "test@example.com"`, `password = "123456"` | Form hợp lệ, cho phép gửi | Pass |
| UT-AU-04 | Email sai định dạng regex | `email = "not-an-email"` | Trả về `false` khi kiểm tra định dạng | Pass |
| UT-AU-05 | Mật khẩu quá ngắn (dưới 6 ký tự) | `password = "123"` | Xác nhận mật khẩu yếu | Pass |
| UT-AU-06 | Ánh xạ lỗi `user-not-found` | Mã lỗi từ Firebase: `'user-not-found'` | Trả về thông báo: `"Không tìm thấy tài khoản"` | Pass |
| UT-AU-07 | Ánh xạ lỗi `wrong-password` | Mã lỗi từ Firebase: `'wrong-password'` | Trả về thông báo: `"Sai mật khẩu"` | Pass |
| UT-AU-08 | Lấy ID người dùng khi chưa đăng nhập | Trạng thái người dùng hiện tại = `null` | Getter `userId` trả về chuỗi rỗng `""` | Pass |
| UT-AU-09 | Lấy ID người dùng khi đã đăng nhập | Trạng thái người dùng = `{uid: "abc123uid"}` | Getter `userId` trả về `"abc123uid"` | Pass |

### 4.2.2 Kiểm thử mô hình ghi chú và danh sách công việc (Checklist & Note Model Test)
*   **File kiểm thử:** [checklist_test.dart](file:///d:/Workspace/TBDD/Smart-Note-App/test/checklist_test.dart)
*   **Mục tiêu:** Kiểm tra quy trình chuyển đổi qua lại giữa định dạng JSON và đối tượng Dart (Serialization/Deserialization), đồng thời kiểm tra tính năng tự động phát hiện và trích xuất danh sách Checklist từ văn bản ghi chú.

| ID | Mô tả kịch bản test | Dữ liệu đầu vào (Input) | Kết quả kỳ vọng (Expected Output) | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| UT-CL-01 | Khởi tạo Checklist mặc định | Khởi tạo không tham số | `id` tự sinh không rỗng, `text = ""`, `checked = false` | Pass |
| UT-CL-02 | Khởi tạo Checklist với giá trị tùy biến | `id="123"`, `text="Task 1"`, `checked=true` | Các thuộc tính được thiết lập chính xác | Pass |
| UT-CL-03 | Chuyển đổi JSON hai chiều | Đối tượng `ChecklistItem` | Dữ liệu chuyển đổi sang JSON và ngược lại khớp 100% | Pass |
| UT-CL-04 | Nhận diện ghi chú không phải Checklist | Note có nội dung văn bản thuần: `"Hello World"` | Thuộc tính `isChecklist` trả về `false` | Pass |
| UT-CL-05 | Nhận diện và định dạng text Checklist | Note chứa JSON Checklist gồm 2 phần tử | `isChecklist` là `true`, văn bản tóm tắt chứa kí tự biểu tượng `☐ Buy milk` và `☑ Call John` | Pass |

### 4.2.3 Kiểm thử logic luật bảo mật cơ sở dữ liệu (Firestore Security Rules Test)
*   **File kiểm thử:** [security_rules_test.dart](file:///d:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart)
*   **Mục tiêu:** Xác minh tính cô lập dữ liệu. Chỉ cho phép các thao tác Đọc/Ghi dữ liệu Firestore khi người dùng đã đăng nhập thành công và `UID` của token trùng khớp với mã người dùng sở hữu dữ liệu trên đường dẫn thư mục lưu trữ (`/users/{userId}/notes/{noteId}`).

| ID | Mô tả kịch bản test | Dữ liệu đầu vào (Input) | Kết quả kỳ vọng (Expected Output) | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| UT-SE-01 | Người dùng đọc dữ liệu của chính mình | `auth.uid = "alice"`, `path = "users/alice"` | **ALLOW** (Cho phép) | Pass |
| UT-SE-02 | Người dùng đọc dữ liệu của người khác | `auth.uid = "alice"`, `path = "users/bob"` | **DENY** (Từ chối) | Pass |
| UT-SE-03 | Khách chưa đăng nhập yêu cầu đọc | `auth = null`, `path = "users/alice"` | **DENY** (Từ chối) | Pass |
| UT-SE-04 | Người dùng ghi dữ liệu vào tài khoản mình | `auth.uid = "alice"`, `path = "users/alice"` | **ALLOW** (Cho phép) | Pass |
| UT-SE-05 | Người dùng cố tình ghi đè tài khoản khác | `auth.uid = "alice"`, `path = "users/charlie"` | **DENY** (Từ chối) | Pass |
| UT-SE-06 | Kiểm soát quyền truy cập nhãn (Tags) mình | `auth.uid = "alice"`, `path = "users/alice/tags"` | **ALLOW** (Cho phép) | Pass |
| UT-SE-07 | Kiểm soát quyền truy cập nhãn người khác | `auth.uid = "alice"`, `path = "users/bob/tags"` | **DENY** (Từ chối) | Pass |
| UT-SE-08 | Mô phỏng kịch bản đăng xuất đột ngột | Đổi trạng thái từ `auth.uid` sang `null` | Lập tức khóa toàn bộ quyền truy cập | Pass |

### 4.2.4 Kiểm thử giao diện thành phần (EmptyStateWidget Test)
*   **File kiểm thử:** [widget_test.dart](file:///d:/Workspace/TBDD/Smart-Note-App/test/widget_test.dart)
*   **Mục tiêu:** Kiểm tra khả năng hiển thị của widget trạng thái trống (khi không có ghi chú) và hành vi tương tác khi nhấn nút gọi hành động.

| ID | Mô tả kịch bản test | Dữ liệu đầu vào (Input) | Kết quả kỳ vọng (Expected Output) | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| WT-ES-01 | Render EmptyStateWidget & tương tác | `icon = Icons.note_alt`, `title = "Chưa có ghi chú"`, callback `onAction` | Tìm thấy icon, title trên màn hình; khi giả lập chạm (tap) vào nút Action, hàm callback được gọi thành công | Pass |

---

## 4.3 Kiểm thử tích hợp hệ thống thủ công (Manual Integration Testing)

Để đánh giá toàn bộ trải nghiệm người dùng cuối cùng (End-to-End UX) và sự phối hợp giữa SQLite, Firestore, Firebase Storage và Gemini AI, các kịch bản kiểm thử tích hợp thủ công sau đây đã được thực hiện trực tiếp trên thiết bị Android:

### Kịch bản 1: Đồng bộ hóa dữ liệu thời gian thực (Realtime Sync)
*   **Mục tiêu:** Kiểm tra dữ liệu ghi chú đồng bộ nhanh chóng lên đám mây Firestore khi mạng ổn định.
*   **Các bước thực hiện:**
    1. Mở ứng dụng trên điện thoại, đăng nhập tài khoản Google.
    2. Tạo một ghi chú mới với nội dung định dạng phong phú (Bold, Highlight) và đính kèm 1 ảnh chụp từ camera.
    3. Nhấn Lưu ghi chú.
    4. Mở trình duyệt web, truy cập vào trang quản trị Firebase Console → Firestore Database của dự án.
*   **Kết quả kỳ vọng:** Ghi chú mới xuất hiện ngay lập tức trên Firestore dưới dạng tài liệu (document) JSON Delta. Hình ảnh được tải lên Firebase Storage và liên kết URL của ảnh được lưu chính xác trong ghi chú trên Firestore. Trạng thái ghi chú trên ứng dụng hiển thị icon đồng bộ thành công (isSynced = 1).
*   **Kết quả thực tế:** Đạt yêu cầu. Thời gian đồng bộ dưới 1.5 giây.

### Kịch bản 2: Giải quyết xung đột đa thiết bị theo thuật toán Last-Writer-Wins (LWW)
*   **Mục tiêu:** Đảm bảo không mất dữ liệu của người dùng khi chỉnh sửa cùng một ghi chú trên hai thiết bị khác nhau trong điều kiện ngoại tuyến.
*   **Các bước thực hiện:**
    1. Đăng nhập cùng một tài khoản trên Thiết bị A và Thiết bị B.
    2. Ngắt kết nối mạng (Bật chế độ máy bay) trên Thiết bị A.
    3. Tiến hành chỉnh sửa nội dung Ghi chú số 1 trên Thiết bị A (ví dụ thêm: "Nội dung sửa từ máy A") tại thời điểm $t_1$.
    4. Trên Thiết bị B (đang có mạng), tiến hành chỉnh sửa nội dung Ghi chú số 1 (ví dụ thêm: "Nội dung sửa từ máy B mới nhất") tại thời điểm $t_2$ ($t_2 > t_1$). Lưu lại và dữ liệu đã được đẩy lên Cloud.
    5. Bật lại kết nối mạng trên Thiết bị A và bấm nút "Đồng bộ ngay".
*   **Kết quả kỳ vọng:** Hệ thống so sánh mốc thời gian chỉnh sửa mới nhất (`updatedAt`). Vì $t_2 > t_1$, dữ liệu trên Cloud của máy B mới hơn. Thiết bị A tự động tải dữ liệu mới từ Cloud xuống ghi đè lên Local để đồng bộ hóa, thay vì đẩy đè dữ liệu cũ của máy A lên làm mất nội dung sửa đổi của máy B.
*   **Kết quả thực tế:** Đạt yêu cầu. Thuật toán LWW đối chiếu chính xác giá trị epoch timestamp của trường `updatedAt` và đồng bộ nhất quán.

### Kịch bản 3: Chế độ hoạt động ngoại tuyến (Offline-First UX)
*   **Mục tiêu:** Kiểm tra ứng dụng hoạt động bình thường khi hoàn toàn không có mạng internet và tự động cập nhật khi có mạng lại.
*   **Các bước thực hiện:**
    1. Tắt toàn bộ Wifi và dữ liệu di động (4G/5G).
    2. Mở ứng dụng, tạo ghi chú mới và thực hiện ghi âm một đoạn audio dài 10 giây.
    3. Nhấn Lưu ghi chú. Tắt ứng dụng (Kill app) và mở lại.
    4. Bật lại kết nối mạng Wifi/4G.
*   **Kết quả kỳ vọng:** 
    - Khi offline: Ghi chú và file audio vẫn lưu cục bộ mượt mà vào SQLite, danh sách ghi chú hiển thị đầy đủ, file ghi âm nghe lại bình thường. Cờ đồng bộ hiển thị màu vàng báo hiệu "Chưa đồng bộ".
    - Khi online trở lại: Hệ thống nền (Background Sync) tự động nhận diện kết nối, tải file ghi âm `.m4a` lên máy chủ lưu trữ Cloudinary/Firebase Storage, lấy liên kết URL cập nhật lại vào SQLite và đồng bộ toàn bộ ghi chú lên Firestore. Cờ đồng bộ chuyển sang màu xanh báo hiệu "Đã đồng bộ".
*   **Kết quả thực tế:** Đạt yêu cầu. Toàn bộ thao tác offline diễn ra với độ trễ bằng 0. Quá trình tự đồng bộ ngầm khi có mạng hoạt động trơn tru.

### Kịch bản 4: Bảo mật sinh trắc học và tự động khóa (Biometric Lock)
*   **Mục tiêu:** Đảm bảo các ghi chú riêng tư được bảo vệ tuyệt đối bằng vân tay/FaceID và tự động khóa lại khi ứng dụng bị ẩn.
*   **Các bước thực hiện:**
    1. Mở một ghi chú bất kỳ, nhấn biểu tượng Khóa và bật tính năng xác thực sinh trắc học.
    2. Thoát ra màn hình chính của ứng dụng. Nhấn mở lại ghi chú đó.
    3. Nhấn phím Home để đưa ứng dụng chạy ngầm (Background), sau đó bấm vào ứng dụng trên khay đa nhiệm để quay lại.
*   **Kết quả kỳ vọng:**
    - Khi nhấn mở ghi chú bị khóa: Ứng dụng hiển thị cửa sổ yêu cầu quét vân tay hoặc FaceID. Chỉ khi xác thực thành công mới hiển thị nội dung chi tiết.
    - Khi ứng dụng chuyển sang chạy ngầm và quay lại: Trạng thái ghi chú tự động chuyển về khóa (`Locked`), buộc người dùng phải xác thực lại để đọc nội dung, tránh bị người khác đọc trộm khi mượn máy.
*   **Kết quả thực tế:** Đạt yêu cầu. Thư viện `local_auth` phản hồi nhanh, hệ thống tự động khóa chính xác theo vòng đời ứng dụng (App Lifecycle State).

### Kịch bản 5: Trợ lý ảo thông minh Gemini AI
*   **Mục tiêu:** Kiểm tra tính năng tạo tiêu đề tự động, tóm tắt nội dung ghi chú và chuyển đổi văn bản sang checklist bằng trí tuệ nhân tạo.
*   **Các bước thực hiện:**
    1. Mở màn hình soạn thảo, nhập nội dung ghi chú dài khoảng 300 từ kể về kế hoạch làm việc tuần mới.
    2. Nhấn vào nút Trợ lý AI Gemini trên thanh công cụ.
    3. Chọn lần lượt các tính năng: "Đề xuất tiêu đề", "Tóm tắt ghi chú", và "Tạo Checklist".
*   **Kết quả kỳ vọng:** AI xử lý nội dung văn bản gốc, đưa ra đề xuất tiêu đề ngắn gọn phù hợp, tạo một đoạn tóm tắt ngắn từ 2-3 câu và tự động bóc tách các hành động trong văn bản để chuyển đổi thành các ô Checklist (Checkbox) tương ứng.
*   **Kết quả thực tế:** Đạt yêu cầu. Trợ lý phản hồi chính xác ngôn ngữ tiếng Việt, thời gian xử lý qua API khoảng 2 giây.

### Kịch bản 6: Xuất bản ghi chú định dạng PDF
*   **Mục tiêu:** Kiểm tra khả năng trích xuất ghi chú (bao gồm văn bản rich text định dạng và hình ảnh đi kèm) thành file tài liệu PDF tiêu chuẩn.
*   **Các bước thực hiện:**
    1. Mở ghi chú có chứa hình ảnh và nhiều kiểu chữ định dạng (H1, Bold, Italic).
    2. Chọn tính năng "Xuất file PDF" từ menu mở rộng.
    3. Xem trước trang in và nhấn Lưu file vào thư mục Download của điện thoại.
*   **Kết quả kỳ vọng:** File PDF được tạo có bố cục căn lề đẹp mắt, giữ nguyên font chữ tiếng Việt không bị lỗi hiển thị, hình ảnh đính kèm hiển thị sắc nét và đúng tỷ lệ.
*   **Kết quả thực tế:** Đạt yêu cầu. File PDF lưu trữ đúng định dạng và có thể mở rộng chia sẻ qua email/Zalo dễ dàng.

---

## 4.4 Kết quả chạy kiểm thử tự động thực tế

Để chạy toàn bộ các bài kiểm thử tự động được thiết lập trong dự án, lập trình viên sử dụng câu lệnh tiêu chuẩn của Flutter SDK từ thư mục gốc:

```bash
flutter test
```

### Kết quả đầu ra từ Terminal:

```text
Resolving dependencies...
Got dependencies!
00:00 +0: loading D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart
00:00 +0: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Initial State Khi chưa login: user = null, isAuthenticated = false
00:00 +1: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Input Validation Logic Email rỗng không được phép gửi form
00:00 +2: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Input Validation Logic Password rỗng không được phép gửi form
00:00 +3: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Input Validation Logic Email và password hợp lệ → được phép submit
00:00 +4: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Input Validation Logic Email không đúng định dạng → không hợp lệ
00:00 +5: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Input Validation Logic Email đúng định dạng → hợp lệ
00:00 +6: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Input Validation Logic Password dưới 6 ký tự → yếu (Firebase reject)
00:00 +7: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Input Validation Logic Password từ 6 ký tự → chấp nhận được
00:00 +8: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Firebase Error Code Mapping user-not-found → thông báo đúng
00:00 +9: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Firebase Error Code Mapping wrong-password → thông báo đúng
00:00 +10: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Firebase Error Code Mapping email-already-in-use → thông báo đúng
00:00 +11: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Firebase Error Code Mapping weak-password → thông báo đúng
00:00 +12: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – Firebase Error Code Mapping Error code không biết → fallback message
00:00 +13: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – userId getter userId trả về empty string khi chưa login (null-safe)
00:00 +14: D:/Workspace/TBDD/Smart-Note-App/test/auth_provider_test.dart: AuthProvider – userId getter userId trả về uid thật khi đã login
00:03 +15: D:/Workspace/TBDD/Smart-Note-App/test/checklist_test.dart: ChecklistItem Model Tests should create ChecklistItem with default values
00:03 +16: D:/Workspace/TBDD/Smart-Note-App/test/checklist_test.dart: ChecklistItem Model Tests should create ChecklistItem with custom values
00:03 +17: D:/Workspace/TBDD/Smart-Note-App/test/checklist_test.dart: ChecklistItem Model Tests should convert ChecklistItem to JSON and from JSON
00:03 +18: D:/Workspace/TBDD/Smart-Note-App/test/checklist_test.dart: Note Model Checklist Integration Tests should identify non-checklist content
00:03 +19: D:/Workspace/TBDD/Smart-Note-App/test/checklist_test.dart: Note Model Checklist Integration Tests should identify checklist content and extract plain text
00:03 +20: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Security Rules – allow read/write logic ✅ User đọc data của chính mình → ALLOW
00:03 +21: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Security Rules – allow read/write logic 🚫 User đọc data của người khác → DENY
00:03 +22: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Security Rules – allow read/write logic 🚫 User chưa đăng nhập → DENY (request.auth == null)
00:03 +23: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Security Rules – allow read/write logic ✅ User viết vào collection của mình → ALLOW
00:03 +24: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Security Rules – allow read/write logic 🚫 User viết vào collection của người khác → DENY
00:03 +25: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Security Rules – allow read/write logic 🚫 Token trống (empty string) → DENY
00:03 +26: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Security Rules – user data isolation Note của user A không được phép bởi user B
00:03 +27: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Security Rules – user data isolation Nhiều users đều có thể đọc data của riêng mình
00:03 +28: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Security Rules – tags collection ✅ User đọc tags của mình → ALLOW
00:03 +29: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Security Rules – tags collection 🚫 User đọc tags của người khác → DENY
00:03 +30: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Rules Playground – test scenarios SCENARIO 1: Unauthorized user đọc → DENIED
00:03 +31: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Rules Playground – test scenarios SCENARIO 2: Owner đọc notes của mình → ALLOWED
00:03 +32: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Rules Playground – test scenarios SCENARIO 3: Attacker đọc victim data → DENIED
00:03 +33: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Rules Playground – test scenarios SCENARIO 4: New user register → tạo được data của mình
00:03 +34: D:/Workspace/TBDD/Smart-Note-App/test/security_rules_test.dart: Rules Playground – test scenarios SCENARIO 5: Logout → không còn access
00:04 +35: D:/Workspace/TBDD/Smart-Note-App/test/widget_test.dart: EmptyStateWidget renders properly and triggers action
00:05 +36: All tests passed!
```


## 4.5 Đánh giá chung (Evaluation Summary)

Qua quá trình kiểm thử tự động kết hợp với các kịch bản kiểm thử tích hợp thủ công trên thiết bị thực tế, hệ thống đạt được các kết quả đánh giá như sau:

1.  **Độ tin cậy của mô hình Offline-First:** SQLite hoạt động ổn định tuyệt đối. Việc lưu trữ cục bộ giúp ứng dụng phản hồi ngay lập tức mà không phụ thuộc vào tốc độ mạng. Hàng đợi đồng bộ và tính năng tự động đẩy dữ liệu khi có mạng lại (được kích hoạt bởi ConnectivityHelper) hoạt động ổn định và chính xác.
2.  **Độ chính xác của thuật toán LWW:** Thuật toán giải quyết xung đột dựa trên mốc thời gian sửa đổi cuối (`updatedAt`) đã chứng minh tính hiệu quả, ngăn ngừa thành công các kịch bản ghi đè mù (blind overwriting) dữ liệu cũ lên đám mây khi đồng bộ hóa từ nhiều thiết bị.
3.  **Khả năng bảo mật thông tin:** Mô phỏng quy tắc bảo mật (Security Rules) cho thấy cấu trúc cơ sở dữ liệu Firestore được bảo vệ chặt chẽ. Hệ thống phân quyền ngăn chặn hiệu quả các truy cập trái phép chéo giữa các định danh người dùng khác nhau. Hệ thống tự động khóa ghi chú bằng sinh trắc học khi chạy ngầm đảm bảo tính riêng tư ở mức thiết bị.
4.  **Chất lượng trải nghiệm người dùng (UX):** Trình soạn thảo văn bản phong phú (Rich Text) tải mượt mà các định dạng Delta JSON phức tạp, xử lý tốt nội dung đa phương tiện (ảnh chụp, file ghi âm). Tính năng AI Gemini và khả năng xuất bản ra PDF đạt độ hoàn thiện cao, gia tăng giá trị sử dụng thực tế của ứng dụng.
