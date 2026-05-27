# Engineering & Application Standards Document

**System Focus:** Identity and Access Management (IAM) Engine

**Primary Stack:** Go (Golang), PostgreSQL

---

## 1. Codebase Architecture & Go Conventions

To ensure uniform code quality, maintainability, and rapid onboarding across the engineering team, all Go projects must adhere strictly to these structural and idiomatic patterns.

### 1.1 Project Layout (Standard Go Project Layout)

The repository must separate operational code from core business logic using a domain-driven, idiomatic layout:

```
├── cmd/
│   └── server/          # Main application entry point
├── internal/            # Private application code (cannot be imported by external projects)
│   ├── auth/            # OAuth2, JWT generation, and token management domain
│   ├── user/            # User onboarding and profile domain
│   └── database/        # DB connection pools, transaction helpers, and migrations
├── pkg/                 # Public library code (unprotected utilities, if explicitly needed)
└── api/
    └── api-contract.yaml # Truth source for the OpenAPI contract

```

### 1.2 Idiomatic Go Standards

* **Error Handling:** Errors are values. Functions must return errors explicitly as the final return value. Panic recovery must be isolated to top-level HTTP middleware; bubbling panics for standard application control flow is strictly prohibited.
* **Context Propagation:** The `context.Context` package must be passed as the first parameter to all blocking, I/O, database, and cross-layer function calls (`ctx context.Context`) to guarantee cancellation signals propagation.
* **Concurrency Guardrails:** Goroutines must never be spawned without lifetime ownership. When using channels, buffer sizes must be documented, and writers must have absolute ownership over channel closure to prevent panics.

---

## 2. API Contract Enforcement & Generation

The OpenAPI specification (`api-contract.yaml`) is the absolute source of truth for the system interface. Changes to code interfaces must begin with changes to this file.

### 2.1 Automated Code Generation

To prevent variance between documented contracts and live code, manual translation of the API spec is prohibited.

* **Server Scaffolding:** Developers must utilize `oapi-codegen` to automatically generate Go standard library `net/http` (or chi/echo compatible) routing boilerplate, request/response models, and interface definitions directly from `api-contract.yaml`.
* **Frontend Integration:** For any consumer components, type-safe API clients must be generated using **Orval**, outputting fully typed React Hooks and custom Axios interceptors to enforce cross-boundary compile-time type safety.

### 2.2 Strict Input Validation & Serialization

* **Layer Enforcement:** Before any payload enters the business logic domain, it must be validated at the transport boundary against the spec rules.
* **Validation Bounds:** * `POST /users/register`: Reject requests failing the standard RFC 5322 email regex formatting, or those where `password` length is $< 8$ characters.
* Structural compliance errors must immediately reject the execution loop at the middleware layer.



### 2.3 API Error Uniformity

All application errors exposed over the wire must map to a single JSON structure matching the contract schema:

```go
type ErrorResponse struct {
    Code    string   `json:"code"`
    Message string   `json:"message"`
    Details []string `json:"details,omitempty"`
}

```

#### HTTP Mapping Requirements

* **400 Bad Request:** Provided parameters fail validation bounds.
* **401 Unauthorized:** Invalid, expired, or revoked tokens presented to `/auth/refresh` or protected endpoints.
* **409 Conflict:** Handled explicitly when an email registration collides with an existing account row.

---

## 3. Database Operations & Data Access Standards

All data access targeting PostgreSQL must satisfy robust engineering rules, optimizing for strict type safety, persistence speed, and transaction isolation.

### 3.1 Naming and Schema Conventions

* **Case Configuration:** Database objects (tables, views, columns, and indexes) must utilize strict lowercase `snake_case`. Plural nomenclature must be enforced for entities (e.g., `users`, `refresh_tokens`).
* **Primary Keys:** Primary identifiers must use universally unique values (`UUID`) generated natively via the `uuid-ossp` extension default formula (`uuid_generate_v4()`).

### 3.2 Migrations and Version Control

* **Immutable State Changes:** Direct manual changes against live environments are strictly prohibited. Schema states must be changed through incremental, timestamped, up/down migration files.
* **Tooling:** Use `golang-migrate/migrate` or a similar tool. Migrations must execute idempotently inside execution routines on container startup.

### 3.3 Query Execution, Drivers, and Performance

* **Raw Mapping/Execution:** Write clean SQL expressions using modern code-generation toolkits like `sqlc` or Type-Safe wrappers like `ent`. Heavy ORMs that hide real queries are discouraged.
* **Index Utilization:** Lookups executed inside the system flow must be backed by explicit indexes.
* Every query driving `/auth/login` must pass through `idx_users_email` over the `users` table.
* Every session check driving `/auth/refresh` must execute utilizing `idx_refresh_tokens_token`.


* **Connection Pooling:** Set strict database handles configurations via `database/sql` driver bindings:

```go
db.SetMaxOpenConns(25)
db.SetMaxIdleConns(25)
db.SetConnMaxLifetime(5 * time.Minute)

```

---

## 4. Security & Cryptographic Standards

Security logic must follow industry-standard zero-trust practices to protect data at rest and in transit.

### 4.1 Transport Security (In-Transit)

* **TLS Requirements:** Every live endpoint must mandate TLS 1.3 encryption execution blocks. Cleartext HTTP requests must instantly terminate or route to an identical HTTPS endpoint using a proxy layer.

### 4.2 Credential Protection (At-Rest)

* **Hashing Standard:** Plaintext passwords must be discarded immediately upon request validation. They must be passed directly into a cryptographically strong hashing mechanism before hitting storage.
* **Algorithm Choice:** Use **Argon2id** (or BCrypt with a minimum work factor of 12).

### 4.3 OAuth 2.0 & Token Architecture

* **Access Tokens:** Standardized JWT strings encoding necessary claims (`sub` [User ID], `exp` [Expiration], `iat` [Issued At]). Access tokens must have short lifespans (15–60 minutes) and remain strictly stateless.
* **Refresh Tokens:** Long-lived tokens (7–30 days) stored as cryptographically random hashes in the database.
* **Token Rotation Guardrails:** When a user invokes `/auth/refresh`, the old `refresh_token` string must be flagged as `is_revoked = true` or purged instantly within an explicit database transaction. A new token pair must be returned.
* **Replay Attack Breaker Middleware:** If an app consumer attempts to authenticate using an already revoked token, the backend must instantly flag this behavior as a potential leak, identify the associated `user_id`, and revoke all active valid child token sessions belonging to that user.

---

## 5. Testing & Quality Assurance Standards

Code cannot be integrated into master execution branches unless it passes automated testing criteria.

```
       ▲
      ╱ ╲     End-to-End Testing (HTTPS, Full Auth Lifecycle)
     ╱   ╲    
    ╱     ╲   Integration Testing (PostgreSQL Execution Loops)
   ╱       ╲  
  ╱         ╲ Unit Testing (Argon2id, Payload Validation, Router Handlers)
 ─────────────

```

### 5.1 The Testing Pyramid

* **Unit Tests:** Must cover all validation logic, text manipulation engines, custom algorithms, response writers, and middleware. Mock database dependencies using interfaces or tools like `go-sqlmock`.
* **Integration Tests:** Must run against real local instances of PostgreSQL (using Testcontainers-Go or Docker infrastructure). Integration tests must cover database transactions, schema indexes, constraint triggers, and raw migrations.
* **End-to-End (E2E) Tests:** Must execute an unbroken automation block sequence simulating real user habits: `Register` $\rightarrow$ `Login` $\rightarrow$ `Access Protected Route` $\rightarrow$ `Refresh Token Pair` $\rightarrow$ `Logout` $\rightarrow$ `Verify Revoked Access`.

### 5.2 Automation Gates

* **Pre-Commit Hooks:** Local machines must run `golangci-lint` and format files with `go fmt` before pushing code.
* **CI Validation:** Pushes to remote development branches must pass compilation validation, complete code style scanning, and hit a minimum of 80% coverage on new features.

---

## 6. Cross-Cutting Concerns & Production Readiness

### 6.1 Structured Logging

Standard application output logs must be emitted exclusively via structured formatters (`slog` package introduced in modern Go standard libraries or `uber-go/zap`). Output format must be JSON to simplify collection by processing agents.

```json
{"time":"2026-05-27T23:52:42Z","level":"ERROR","msg":"failed token verification","trace_id":"4a5b6c7d8e","user_id":"550e8400-e29b-41d4-a716-446655440000"}

```

* **Trace Propagation:** Every inbound request must be assigned a unique `trace_id` at the HTTP router middleware layer. This ID must accompany every downstream log entry to simplify tracing.
* **Data Masking:** Logs must never write sensitive parameters. Fields like `password`, `refresh_token`, or personal identifying details must be stripped or masked before serialization.

### 6.2 Application Configuration

* **Twelve-Factor Methodology:** Application configuration must be injected solely using Environment Variables. Hardcoded environment strings or config file tracking within source repositories are prohibited.
* **Startup Self-Checks:** On initialization, the application binary must read and validate all required configurations (such as database credentials and JWT signing keys) before spinning up the HTTP server. If any required variable is missing or malformed, the process must terminate immediately with a non-zero exit code.