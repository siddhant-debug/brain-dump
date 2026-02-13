# Brain Dump Backend Documentation

## 1. System Overview
The Brain Dump backend is a high-performance API built with **FastAPI**, designed to handle user authentication, note management, and file storage for "The Vault".

### Technical Stack
- **Framework**: FastAPI (Python 3.13+)
- **Database**: PostgreSQL
- **ORM**: SQLAlchemy
- **Authentication**: JWT (JSON Web Tokens) with OAuth2 Password Bearer flow
- **Validation**: Pydantic v2
- **File Storage**: Local Disk Storage (for binary files) & Database (for metadata and text content)

### Folder Structure
```text
backend/
├── main.py          # Application entry point & router registration
├── database.py      # SQLAlchemy engine and session configuration
├── models.py        # SQLAlchemy database models
├── schemas.py       # Pydantic schemas for request/response validation
├── auth.py          # Authentication logic, JWT issuance, and signup/login
├── files.py         # File upload, retrieval, and "The Vault" logic
└── notes.py         # "Quick Save" notes CRUD operations
```

---

## 2. Database Schema (ERD)
The database uses a relational schema with a one-to-many relationship from the User to their Notes and Files.

```mermaid
erDiagram
    USER ||--o{ NOTE : creates
    USER ||--o{ STORED_FILE : uploads

    USER {
        int id PK
        string email UK
        string hashed_password
        string full_name
        string profile_pic
        datetime created_at
    }

    NOTE {
        int id PK
        int user_id FK
        string content
        boolean is_favorite
        datetime created_at
    }

    STORED_FILE {
        int id PK
        int user_id FK
        string filename
        string file_type
        int file_size
        string content_text
        string file_path
        datetime created_at
    }
```

---

## 3. Critical Backend Flows

### Flow A: Authentication (Login)
Handles credential verification and JWT generation.

```mermaid
sequenceDiagram
    participant User as Flutter Client
    participant API as FastAPI (auth.py)
    participant Sec as Pydantic (schemas.py)
    participant DB as PostgreSQL (DB)

    User->>API: POST /auth/login {email, password}
    API->>Sec: Validate Request (UserLogin)
    Sec-->>API: Validated Data
    API->>DB: Query User by Email
    DB-->>API: User Record (Hashed Password)
    API->>API: Verify Password Hash (Bcrypt)
    alt Valid Credentials
        API->>API: Generate access_token (JWT)
        API-->>User: 200 OK {access_token, token_type}
    else Invalid Credentials
        API-->>User: 401 Unauthorized
    end
```

### Flow B: The "Quick Save" (Text Note)
Persists user thoughts directly to the database.

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant API as FastAPI (notes.py)
    participant Auth as Auth Middleware
    participant DB as PostgreSQL (DB)

    App->>API: POST /notes/ {content}
    API->>Auth: Bearer Token Validation
    Auth-->>API: Current User Object
    API->>API: Validation (NoteCreate Schema)
    API->>DB: INSERT INTO notes (content, user_id)
    DB-->>API: Created Note Object
    API-->>App: 201 Created (NoteResponse)
```

### Flow C: File Upload (The Vault)
Handles multi-modal storage for markdown, text, and binary files.

```mermaid
sequenceDiagram
    participant User as Flutter Client
    participant API as FastAPI (files.py)
    participant Disk as Local Storage
    participant DB as PostgreSQL (DB)

    User->>API: POST /files/upload (Multipart/form-data)
    API->>API: Extract File Content & Metadata
    alt Text-based (.md, .txt)
        API->>API: Decode UTF-8 Content
        API->>DB: Save metadata + content_text
    else Binary-based (e.g. .pdf)
        API->>Disk: Save file to /uploads/{user_id}_{name}
        API->>DB: Save metadata + file_path
    end
    DB-->>API: Success
    API-->>User: 200 OK (FileResponseSchema)
```

---

## 4. API Reference

| Method | Endpoint | Description | Input Schema |
| :--- | :--- | :--- | :--- |
| `POST` | `/auth/signup` | Register a new user | `UserCreate` |
| `POST` | `/auth/login` | Authenticate and get JWT | `UserLogin` |
| `GET` | `/auth/me` | Get current user info | `None` (Bearer) |
| `POST` | `/notes/` | Create a new quick note | `NoteCreate` |
| `GET` | `/notes/` | List all user notes | `None` (Bearer) |
| `POST` | `/files/upload` | Upload file to Vault | `Multipart/Form` |
| `GET` | `/files/` | List all user files | `None` (Bearer) |
| `GET` | `/files/{id}` | Get file content or download | `None` (Bearer) |
