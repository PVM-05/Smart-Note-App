# 📐 Bộ Sơ đồ Kiến trúc & Luồng Hoạt động – Smart Note App

> **Mô tả:** Tài liệu này tổng hợp toàn bộ các sơ đồ kỹ thuật của dự án Smart Note, bao gồm kiến trúc hệ thống, luồng dữ liệu, sơ đồ lớp, sơ đồ trạng thái, ERD và sơ đồ trình tự (Sequence Diagram).

---

## 📑 Mục lục

1. [Sơ đồ Kiến trúc Tổng thể (Architecture Diagram)](#1-sơ-đồ-kiến-trúc-tổng-thể)
2. [Sơ đồ Cấu trúc Thư mục (Project Structure)](#2-sơ-đồ-cấu-trúc-thư-mục)
3. [Sơ đồ Lớp (Class Diagram)](#3-sơ-đồ-lớp-class-diagram)
4. [Sơ đồ Thực thể Quan hệ (ERD)](#4-sơ-đồ-thực-thể-quan-hệ-erd)
5. [Sơ đồ Trạng thái Ghi chú (State Diagram)](#5-sơ-đồ-trạng-thái-ghi-chú)
6. [Luồng Đồng bộ Dữ liệu (Sync Flow)](#6-luồng-đồng-bộ-dữ-liệu)
7. [Luồng Lưu Ghi chú Đầy đủ (Full Save Flow)](#7-luồng-lưu-ghi-chú-đầy-đủ)
8. [Luồng Xác thực Sinh trắc học (Biometric Auth Flow)](#8-luồng-xác-thực-sinh-trắc-học)
9. [Sơ đồ Trình tự – Tạo Ghi chú (Sequence Diagram: Create Note)](#9-sơ-đồ-trình-tự--tạo-ghi-chú)
10. [Sơ đồ Trình tự – Đăng nhập & Đồng bộ (Sequence Diagram: Login & Sync)](#10-sơ-đồ-trình-tự--đăng-nhập--đồng-bộ)
11. [Luồng Điều hướng Màn hình (Navigation Flow)](#11-luồng-điều-hướng-màn-hình)
12. [Luồng Upload Đa phương tiện (Multimedia Upload Flow)](#12-luồng-upload-đa-phương-tiện)
13. [Sơ đồ Deployment (CI/CD Pipeline)](#13-sơ-đồ-deployment-cicd-pipeline)

---

## 1. Sơ đồ Kiến trúc Tổng thể

> Kiến trúc 4 lớp theo **Clean Architecture**: UI → Provider → Repository → Service/Storage.

```mermaid
flowchart TB
    subgraph UI["🖥️ UI Layer (screens/ + widgets/)"]
        direction LR
        HS[HomeScreen]
        ES[EditorScreen]
        DS[DetailScreen]
        SS[SettingsScreen]
    end

    subgraph STATE["⚙️ State Layer (providers/)"]
        direction LR
        NP[NoteProvider]
        AP[AuthProvider]
        SY[SyncProvider]
        TP[ThemeProvider]
    end

    subgraph REPO["🗂️ Repository Layer (repositories/)"]
        direction LR
        NR["NoteRepository\n(abstract interface)"]
    end

    subgraph SERVICE["🔌 Service Layer (services/)"]
        direction LR
        LS[LocalNoteService]
        FS[FirestoreService]
        ST[StorageService]
    end

    subgraph STORAGE["💾 Storage"]
        direction LR
        SQ[(SQLite\nLocal DB)]
        FB[(Cloud\nFirestore)]
        FBS[(Firebase\nStorage)]
    end

    UI --> STATE
    STATE --> REPO
    REPO --> SERVICE
    LS --> SQ
    FS --> FB
    ST --> FBS

    style UI fill:#D5E8F0,stroke:#2E75B6,color:#000
    style STATE fill:#E2EFDA,stroke:#375623,color:#000
    style REPO fill:#FFF2CC,stroke:#7D5C00,color:#000
    style SERVICE fill:#FCE4D6,stroke:#843C0C,color:#000
    style STORAGE fill:#F2F2F2,stroke:#555555,color:#000
```

---

## 2. Sơ đồ Cấu trúc Thư mục

```mermaid
graph LR
    ROOT["📁 lib/"]

    ROOT --> CORE["📁 core/\n─ AppColors\n─ AppStrings\n─ AppTheme"]
    ROOT --> MODELS["📁 models/\n─ NoteModel\n─ UserModel\n─ TagModel\n─ MediaItem"]
    ROOT --> PROVIDERS["📁 providers/\n─ NoteProvider\n─ AuthProvider\n─ SyncProvider\n─ ThemeProvider"]
    ROOT --> REPOS["📁 repositories/\n─ NoteRepository (abstract)\n─ UserRepository (abstract)"]
    ROOT --> SERVICES["📁 services/\n─ LocalNoteService\n─ FirestoreService\n─ StorageService\n─ SyncService\n─ BiometricService"]
    ROOT --> SCREENS["📁 screens/\n─ SplashScreen\n─ HomeScreen\n─ EditorScreen\n─ DetailScreen\n─ ArchiveScreen\n─ TrashScreen\n─ SettingsScreen"]
    ROOT --> WIDGETS["📁 widgets/\n─ NoteCard\n─ TagChip\n─ AudioPlayer\n─ SyncStatusIcon\n─ FABAdaptive"]
    ROOT --> UTILS["📁 utils/\n─ ImageCompressor\n─ DateFormatter\n─ ConnectivityHelper\n─ DataPrinter (Generic)"]

    style ROOT fill:#1A3A5C,color:#FFF
    style CORE fill:#D5E8F0,stroke:#2E75B6
    style MODELS fill:#E2EFDA,stroke:#375623
    style PROVIDERS fill:#FFF2CC,stroke:#7D5C00
    style REPOS fill:#FCE4D6,stroke:#843C0C
    style SERVICES fill:#F2F2F2,stroke:#555
    style SCREENS fill:#D5E8F0,stroke:#2E75B6
    style WIDGETS fill:#E2EFDA,stroke:#375623
    style UTILS fill:#FFF2CC,stroke:#7D5C00
```

---

## 3. Sơ đồ Lớp (Class Diagram)

```mermaid
classDiagram
    direction TB

    class NoteModel {
        +String id
        +String title
        +String content
        +String status
        +bool isLocked
        +bool isSynced
        +String userId
        +DateTime createdAt
        +DateTime updatedAt
        +DateTime? reminderAt
        +List~String~ tagIds
        +List~MediaItem~ mediaItems
        +toMap() Map
        +fromMap(Map) NoteModel
        +copyWith() NoteModel
    }

    class MediaItem {
        +String id
        +String noteId
        +String type
        +String localPath
        +String? remoteUrl
        +bool isSynced
    }

    class TagModel {
        +String id
        +String name
        +String color
        +String userId
    }

    class NoteRepository {
        <<interface>>
        +getNotes(String userId) Future~List~NoteModel~~
        +getNoteById(String id) Future~NoteModel?~
        +saveNote(NoteModel note) Future~void~
        +deleteNote(String id) Future~void~
        +searchNotes(String query) Future~List~NoteModel~~
        +getUnsyncedNotes() Future~List~NoteModel~~
    }

    class LocalNoteService {
        -Database _db
        +getNotes(String userId) Future~List~NoteModel~~
        +saveNote(NoteModel note) Future~void~
        +deleteNote(String id) Future~void~
        +getUnsyncedNotes() Future~List~NoteModel~~
    }

    class FirestoreNoteService {
        -FirebaseFirestore _firestore
        +getNotes(String userId) Future~List~NoteModel~~
        +saveNote(NoteModel note) Future~void~
        +deleteNote(String id) Future~void~
    }

    class NoteProvider {
        -NoteRepository _repo
        -List~NoteModel~ _notes
        -bool _isLoading
        -String _searchQuery
        +List~NoteModel~ get notes
        +fetchNotes() Future~void~
        +addNote(NoteModel) Future~void~
        +updateNote(NoteModel) Future~void~
        +deleteNote(String id) Future~void~
        +togglePin(String id) Future~void~
        +toggleArchive(String id) Future~void~
    }

    class SyncProvider {
        -SyncService _syncService
        +SyncStatus syncStatus
        +int pendingCount
        +DateTime? lastSyncedAt
        +syncNow() Future~void~
        +startBackgroundSync() void
    }

    class DataPrinter~T~ {
        +T data
        +printInfo() void
        +toJson() String
    }

    NoteRepository <|.. LocalNoteService : implements
    NoteRepository <|.. FirestoreNoteService : implements
    NoteProvider --> NoteRepository : uses
    SyncProvider --> LocalNoteService : reads unsynced
    SyncProvider --> FirestoreNoteService : pushes to cloud
    NoteModel "1" --> "many" MediaItem : contains
    NoteModel "many" --> "many" TagModel : tagged with
    DataPrinter --> NoteModel : generic type
```

---

## 4. Sơ đồ Thực thể Quan hệ (ERD)

```mermaid
erDiagram
    USERS {
        string id PK
        string email
        string displayName
        string photoUrl
        int createdAt
    }

    NOTES {
        string id PK
        string userId FK
        string title
        string content
        string status
        int isLocked
        int isSynced
        int createdAt
        int updatedAt
        int reminderAt
    }

    TAGS {
        string id PK
        string userId FK
        string name
        string color
    }

    NOTE_TAGS {
        string noteId FK
        string tagId FK
    }

    MEDIA_ITEMS {
        string id PK
        string noteId FK
        string type
        string localPath
        string remoteUrl
        int isSynced
        int createdAt
    }

    NOTE_HISTORY {
        string id PK
        string noteId FK
        string content
        int savedAt
        int version
    }

    USERS ||--o{ NOTES : "owns"
    USERS ||--o{ TAGS : "creates"
    NOTES ||--o{ NOTE_TAGS : "has"
    TAGS ||--o{ NOTE_TAGS : "applied to"
    NOTES ||--o{ MEDIA_ITEMS : "contains"
    NOTES ||--o{ NOTE_HISTORY : "versioned by"
```

---

## 5. Sơ đồ Trạng thái Ghi chú

```mermaid
stateDiagram-v2
    [*] --> Normal : Tạo ghi chú mới

    Normal --> Pinned : Ghim (togglePin)
    Pinned --> Normal : Bỏ ghim

    Normal --> Archived : Lưu trữ (archive)
    Archived --> Normal : Khôi phục (restore)

    Normal --> Trash : Chuyển vào thùng rác
    Pinned --> Trash : Chuyển vào thùng rác
    Archived --> Trash : Chuyển vào thùng rác

    Trash --> Normal : Khôi phục từ thùng rác
    Trash --> [*] : Xóa vĩnh viễn\n(thủ công hoặc sau 30 ngày)

    Normal --> Locked : Bật khóa sinh trắc (isLocked=true)
    Locked --> Normal : Xác thực thành công

    note right of Locked
        Hiển thị Biometric Prompt
        khi mở ghi chú
    end note
```

---

## 6. Luồng Đồng bộ Dữ liệu

```mermaid
flowchart TD
    A([👤 Người dùng\nLưu ghi chú]) --> B[Ghi ngay vào SQLite\nisSynced = false]
    B --> C{📶 Có kết nối\nmạng?}

    C -- Có mạng --> D[Đẩy lên Firestore]
    D --> E{Đẩy\nthành công?}
    E -- Thành công --> F[Cập nhật\nisSynced = true]
    F --> G([✅ Hoàn tất đồng bộ])

    E -- Thất bại --> H[Giữ isSynced = false\nGhi log lỗi]
    H --> I([⏳ Thử lại lần sau])

    C -- Mất mạng --> J[Đánh dấu\nisSynced = false\nHiển thị icon ⟳]
    J --> K([ConnectivityHelper\nLắng nghe kết nối])
    K -->|Có mạng trở lại| L[BackgroundSyncService\nquét notes isSynced=false]
    L --> D

    style A fill:#2E75B6,color:#fff
    style G fill:#375623,color:#fff
    style I fill:#FFF2CC,stroke:#7D5C00
    style K fill:#FCE4D6,stroke:#843C0C
```

---

## 7. Luồng Lưu Ghi chú Đầy đủ

```mermaid
flowchart LR
    START([👤 Nhấn Lưu]) --> VALID{Validate\nnội dung}
    VALID -- Rỗng --> ERR([❌ Báo lỗi\n"Tiêu đề không được trống"])
    VALID -- Hợp lệ --> UUID[Sinh UUID\ncho note]
    UUID --> MEDIA{Có file\nMedia?}

    MEDIA -- Có ảnh --> COMPRESS[Nén ảnh\n< 1MB]
    COMPRESS --> SQLMEDIA[Lưu MediaItem\nvào SQLite]
    MEDIA -- Không --> SQLNOTE

    SQLMEDIA --> SQLNOTE[Lưu NoteModel\nvào SQLite]
    SQLNOTE --> NOTIFY[Cập nhật\nNoteProvider.notes]
    NOTIFY --> UI([🖥️ UI refresh\nHiển thị ghi chú mới])

    NOTIFY --> SYNC{Có mạng?}
    SYNC -- Có --> UPLOAD_MEDIA{Có Media\nchưa sync?}
    UPLOAD_MEDIA -- Có --> STORAGE[Upload ảnh\nlên Firebase Storage]
    STORAGE --> FIRESTORES[Lưu Note\nlên Firestore]
    UPLOAD_MEDIA -- Không --> FIRESTORES
    FIRESTORES --> MARK[Đánh dấu\nisSynced = true]

    SYNC -- Không --> QUEUE([📋 Queue đồng bộ\ncho lần sau])

    style START fill:#2E75B6,color:#fff
    style UI fill:#375623,color:#fff
    style ERR fill:#D32F2F,color:#fff
    style QUEUE fill:#FFF2CC,stroke:#7D5C00
```

---

## 8. Luồng Xác thực Sinh trắc học

```mermaid
flowchart TD
    TAP([👤 Nhấn vào\nghi chú bị khóa]) --> CHECK_LOCKED{isLocked\n= true?}
    CHECK_LOCKED -- Không --> OPEN([📄 Mở ghi chú\nbình thường])
    CHECK_LOCKED -- Có --> SUPPORT{Thiết bị hỗ trợ\nBiometrics?}

    SUPPORT -- Không --> PIN[Yêu cầu nhập\nPIN/Password]
    SUPPORT -- Có --> BIO[Hiển thị\nBiometric Prompt]

    BIO --> RESULT{Kết quả\nxác thực}
    RESULT -- Thành công --> OPEN
    RESULT -- Thất bại --> RETRY{Số lần\nthử < 3?}
    RETRY -- Có --> BIO
    RETRY -- Không --> LOCK([🔒 Khóa tạm thời\n30 giây])
    LOCK --> WAIT([⏱️ Chờ 30s]) --> BIO

    PIN --> PIN_RESULT{PIN\nđúng?}
    PIN_RESULT -- Đúng --> OPEN
    PIN_RESULT -- Sai --> PIN

    style TAP fill:#2E75B6,color:#fff
    style OPEN fill:#375623,color:#fff
    style LOCK fill:#D32F2F,color:#fff
```

---

## 9. Sơ đồ Trình tự – Tạo Ghi chú

```mermaid
sequenceDiagram
    actor User as 👤 Người dùng
    participant UI as 🖥️ EditorScreen
    participant Provider as ⚙️ NoteProvider
    participant Repo as 🗂️ NoteRepository
    participant Local as 💾 SQLite
    participant Sync as 🔄 SyncService
    participant Cloud as ☁️ Firestore

    User->>UI: Nhập tiêu đề và nội dung
    User->>UI: Nhấn "Lưu"
    UI->>Provider: addNote(NoteModel)
    Provider->>Provider: Validate dữ liệu
    Provider->>Repo: saveNote(note)
    Repo->>Local: INSERT INTO notes (...)
    Local-->>Repo: rowId (success)
    Repo-->>Provider: void (success)
    Provider->>Provider: Cập nhật _notes list
    Provider-->>UI: notifyListeners()
    UI-->>User: ✅ Hiển thị ghi chú mới trong danh sách

    Note over Provider,Cloud: Đồng bộ ngầm (async)
    Provider->>Sync: triggerSync(note.id)
    Sync->>Sync: Kiểm tra kết nối mạng
    alt Có mạng
        Sync->>Cloud: set(notes/{noteId}, data)
        Cloud-->>Sync: success
        Sync->>Local: UPDATE notes SET isSynced=1
    else Mất mạng
        Sync->>Sync: Ghi vào sync queue
        Note over Sync: Thử lại khi có mạng
    end
```

---

## 10. Sơ đồ Trình tự – Đăng nhập & Đồng bộ

```mermaid
sequenceDiagram
    actor User as 👤 Người dùng
    participant App as 📱 App
    participant Auth as 🔐 AuthProvider
    participant Firebase as 🔥 Firebase Auth
    participant SyncSvc as 🔄 SyncService
    participant Local as 💾 SQLite
    participant Cloud as ☁️ Firestore

    User->>App: Mở ứng dụng
    App->>Auth: checkAuthState()
    Auth->>Firebase: authStateChanges()

    alt Đã đăng nhập trước đó
        Firebase-->>Auth: User session còn hạn
        Auth-->>App: Điều hướng → HomeScreen
        App->>SyncSvc: startBackgroundSync()
        SyncSvc->>Local: getUnsyncedNotes()
        Local-->>SyncSvc: List<Note> (isSynced=false)
        SyncSvc->>Cloud: Batch write unsync notes
        Cloud-->>SyncSvc: success
        SyncSvc->>Local: Cập nhật isSynced = true
    else Chưa đăng nhập
        Firebase-->>Auth: null
        Auth-->>App: Điều hướng → LoginScreen
        User->>App: Nhấn "Đăng nhập với Google"
        App->>Firebase: signInWithGoogle()
        Firebase-->>App: UserCredential
        App->>Cloud: Tải notes của user về
        Cloud-->>App: List<Note>
        App->>Local: INSERT notes vào SQLite
        App-->>User: ✅ Hiển thị HomeScreen với dữ liệu
    end
```

---

## 11. Luồng Điều hướng Màn hình

```mermaid
flowchart TD
    SPLASH[🚀 SplashScreen\n2s animation] --> AUTH_CHECK{Đã\nđăng nhập?}

    AUTH_CHECK -- Không --> LOGIN[🔐 LoginScreen\nGoogle / Email]
    LOGIN --> HOME

    AUTH_CHECK -- Có --> HOME[🏠 HomeScreen\nStaggered Grid]

    HOME --> EDITOR_NEW[📝 EditorScreen\nTạo ghi chú mới]
    HOME --> DETAIL[👁️ DetailScreen\nXem chi tiết]
    HOME --> SEARCH[🔍 SearchScreen\nTìm kiếm full-text]
    HOME --> MENU[☰ Navigation Drawer]

    MENU --> ARCHIVE[🗄️ ArchiveScreen]
    MENU --> TRASH[🗑️ TrashScreen]
    MENU --> TAGS[🏷️ TagManagerScreen]
    MENU --> SETTINGS[⚙️ SettingsScreen]

    DETAIL --> EDITOR_EDIT[📝 EditorScreen\nChỉnh sửa]
    DETAIL --> BIO[🔒 BiometricPrompt\n(nếu isLocked=true)]
    BIO --> DETAIL

    SETTINGS --> THEME[🎨 Theme Settings]
    SETTINGS --> ACCOUNT[👤 Account Settings]
    SETTINGS --> SECURITY[🛡️ Security Settings]

    style SPLASH fill:#1A3A5C,color:#fff
    style HOME fill:#2E75B6,color:#fff
    style LOGIN fill:#FCE4D6,stroke:#843C0C
    style BIO fill:#D32F2F,color:#fff
```

---

## 12. Luồng Upload Đa phương tiện

```mermaid
flowchart TD
    START([📎 Người dùng\nthêm ảnh / ghi âm]) --> TYPE{Loại\nMedia?}

    TYPE -- Ảnh --> SRC{Nguồn?}
    SRC -- Camera --> CAM[Chụp ảnh\nImagePicker.camera]
    SRC -- Thư viện --> GAL[Chọn từ Gallery\nImagePicker.gallery]

    CAM --> COMPRESS[🗜️ Nén ảnh\nImageCompressor\nmax 1MB / max 1080px]
    GAL --> COMPRESS

    COMPRESS --> SAVE_LOCAL_IMG[Lưu file ảnh\nvào local storage]
    SAVE_LOCAL_IMG --> DB_IMG[Tạo MediaItem\ntrong SQLite\nlocalPath = ✓\nremoteUrl = null\nisSynced = false]

    TYPE -- Ghi âm --> REC[🎙️ Bắt đầu ghi\nflutter_sound]
    REC --> STOP([🛑 Dừng ghi])
    STOP --> SAVE_LOCAL_AUD[Lưu file .m4a\nvào local storage]
    SAVE_LOCAL_AUD --> DB_AUD[Tạo MediaItem\ntrong SQLite]

    DB_IMG --> SYNC_TRIGGER
    DB_AUD --> SYNC_TRIGGER

    SYNC_TRIGGER{📶 Có mạng?}
    SYNC_TRIGGER -- Có --> UPLOAD[⬆️ Upload lên\nFirebase Storage]
    UPLOAD --> GET_URL[Lấy downloadUrl]
    GET_URL --> UPDATE_DB[Cập nhật MediaItem\nremoteUrl = ✓\nisSynced = true]
    UPDATE_DB --> DONE([✅ Hoàn tất])

    SYNC_TRIGGER -- Không --> QUEUE([📋 Queue\ncho lần sau])

    style START fill:#2E75B6,color:#fff
    style DONE fill:#375623,color:#fff
    style QUEUE fill:#FFF2CC,stroke:#7D5C00
```

---

## 13. Sơ đồ Deployment (CI/CD Pipeline)

```mermaid
flowchart LR
    DEV([👨‍💻 Developer\nCommit code]) --> PUSH[git push\nfeature/* branch]
    PUSH --> PR[Pull Request\n→ develop]
    PR --> CI

    subgraph CI["🤖 GitHub Actions CI"]
        direction TB
        LINT[flutter analyze\nKiểm tra lint]
        TEST[flutter test\nUnit + Widget tests]
        BUILD[flutter build apk\n--release --obfuscate]
        LINT --> TEST --> BUILD
    end

    CI -- ✅ Pass --> DIST[Firebase App Distribution\nUpload APK cho testers]
    CI -- ❌ Fail --> NOTIFY_DEV([📧 Thông báo\ncho developer])

    DIST --> QA([👥 QA Testing\ntrên thiết bị thật])
    QA -- Approved --> MERGE[Merge vào main\ngit tag v1.x.x]
    MERGE --> RELEASE

    subgraph RELEASE["🚀 Release Build"]
        direction TB
        APK_REL[flutter build apk\n--release → Google Play]
        IPA_REL[flutter build ipa\n--release → App Store]
    end

    RELEASE --> STORE([🏪 App Store\nGoogle Play / Apple])

    style CI fill:#E2EFDA,stroke:#375623
    style RELEASE fill:#D5E8F0,stroke:#2E75B6
    style STORE fill:#1A3A5C,color:#fff
    style NOTIFY_DEV fill:#FCE4D6,stroke:#843C0C
```

---

## 📊 Tổng kết Sơ đồ

| # | Tên sơ đồ | Loại | Mục đích |
|---|-----------|------|----------|
| 1 | Kiến trúc Tổng thể | Flowchart | Tổng quan 4-layer Clean Architecture |
| 2 | Cấu trúc Thư mục | Graph | Tổ chức code trong dự án |
| 3 | Sơ đồ Lớp | Class Diagram | Quan hệ giữa các class |
| 4 | ERD | ER Diagram | Schema SQLite & Firestore |
| 5 | Sơ đồ Trạng thái | State Diagram | Vòng đời của một ghi chú |
| 6 | Luồng Đồng bộ | Flowchart | Offline-First Sync Strategy |
| 7 | Luồng Lưu Ghi chú | Flowchart | Chi tiết quá trình save note |
| 8 | Biometric Auth | Flowchart | Luồng xác thực sinh trắc |
| 9 | Sequence: Tạo Note | Sequence | Tương tác giữa các lớp khi tạo note |
| 10 | Sequence: Login & Sync | Sequence | Luồng đăng nhập và đồng bộ dữ liệu |
| 11 | Navigation Flow | Flowchart | Điều hướng giữa các màn hình |
| 12 | Multimedia Upload | Flowchart | Luồng xử lý ảnh và ghi âm |
| 13 | CI/CD Pipeline | Flowchart | Quy trình build và deploy |

---

> **Lưu ý:** Tất cả sơ đồ được viết bằng cú pháp **Mermaid**. Để render, mở file này trong VS Code với extension *Markdown Preview Mermaid Support*, hoặc truy cập [mermaid.live](https://mermaid.live) để xem trực tiếp.
>
> File tài liệu chi tiết: `Smart_Note_Project_Description.docx`
