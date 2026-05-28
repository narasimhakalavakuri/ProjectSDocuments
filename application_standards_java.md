Here is the completely revised **Engineering & Application Standards Document**, fully adapted from your Go/PostgreSQL guidelines into an idiomatic, production-grade **Java 21** and **Spring Boot 3.x** ecosystem while preserving the exact same architectural rigor, security constraints, and data access policies.

---

# Engineering & Application Standards Document

### System Focus: Identity and Access Management (IAM) Engine

### Primary Stack: Java 21, Spring Boot 3.x, PostgreSQL

---

## 1. Codebase Architecture & Java / Spring Conventions

To ensure uniform code quality, maintainability, and rapid onboarding across the engineering team, all Spring Boot projects must adhere strictly to these structural and idiomatic patterns.

### 1.1 Project Layout (Standard Spring Boot Package-by-Feature)

The repository must separate operational delivery mechanisms from core business logic using a domain-driven, package-by-feature layout. The project follows a standard Maven or Gradle structure:

```text
src/main/java/com/company/iam/
├── IamApplication.java            # Main application entry point and Spring Boot configuration
├── api/                           # API Contract layer (Generated DTOs & Controller interfaces)
├── config/                        # Global framework configuration (Security, Database, Logging)
├── internal/                      # Core business logic (Protected by package-private scoping)
│   ├── auth/                      # OAuth2, JWT generation, and token management domain
│   │   ├── controller/            # REST adapters handling auth routes
│   │   ├── service/               # Token handling, rotation business logic
│   │   └── model/                 # Domain-specific internal abstractions
│   ├── user/                      # User onboarding and profile domain
│   └── common/                    # Global exception handlers and shared middleware filters
└── resources/
    ├── db/migration/              # Flyway/Liquibase timestamped migration files
    └── openapi/
        └── api-contract.yaml      # Truth source for the OpenAPI contract

```

### 1.2 Idiomatic Spring Boot Standards

* **Error Handling (Global Interception):** Standard business logic must not catch structural runtime exceptions manually to map HTTP states. The system relies on a unified `@RestControllerAdvice` to convert checked or custom un-checked domain exceptions (`DomainException`) into HTTP response streams.
* **Reactive and Async Context Propagation:** When processing asynchronous logic (`@Async`), processing pipelines must propagate security and tracing states. Virtual threads (**Project Loom**) should be enabled via `spring.threads.virtual.enabled=true` to handle blocking I/O concurrently without thread-pool exhaustion.
* **Dependency Injection Guardrails:** Field injection (`@Autowired` on fields) is strictly prohibited. Applications must enforce **Constructor Injection** to guarantee immutability, make dependencies explicit, and ease unit testing isolation.

---

## 2. API Contract Enforcement & Generation

The OpenAPI specification (`api-contract.yaml`) remains the absolute source of truth for the system interface. Changes to code interfaces must begin with changes to this file.

### 2.1 Automated Code Generation

To prevent variance between documented contracts and live code, manual translation of the API spec into controllers or Data Transfer Objects (DTOs) is prohibited.

* **Server Scaffolding:** Developers must utilize the `openapi-generator-maven-plugin` (or Gradle equivalent) to automatically generate Spring `@RestController` interfaces and validation-annotated DTOs directly from `api-contract.yaml` during the build compile phase.
* **Frontend Integration:** For any consumer components, type-safe API clients must be generated using Orval, outputting fully typed React Hooks and custom Axios interceptors to enforce cross-boundary compile-time type safety.

### 2.2 Strict Input Validation & Serialization

* **Layer Enforcement:** Inbound JSON payloads must match schema parameters perfectly. Controllers implementing generated interfaces must use Jakarta Validation (`@Valid` or `@Validated`) at the routing boundary.
* **Validation Bounds:** * `POST /users/register`: Reject requests failing standard RFC 5322 regex validation (`@Email`), or those where the plaintext password length is `< 8` characters (`@Size(min = 8)`).
* Structural compliance errors must instantly throw a `MethodArgumentNotValidException`, terminating execution at the framework validation layer before touching internal services.

### 2.3 API Error Uniformity

All application errors exposed over the wire must map to a single JSON structure matching the contract schema:

```java
public record ErrorResponse(
    String code,
    String message,
    List<String> details
) {}

```

#### HTTP Mapping Requirements

* **400 Bad Request:** Provided parameters or JSON validation bounds fail.
* **401 Unauthorized:** Invalid, expired, or revoked tokens presented to `/auth/refresh` or protected endpoints.
* **409 Conflict:** Handled explicitly via a handler matching a unique constraint violation when an email registration collides with an existing account row.

---

## 3. Database Operations & Data Access Standards

All data access targeting PostgreSQL must satisfy robust engineering rules, optimizing for strict type safety, persistence speed, and transaction isolation.

### 3.1 Naming and Schema Conventions

* **Case Configuration:** Database objects (tables, views, columns, and indexes) must utilize strict lowercase `snake_case`. Plural nomenclature must be enforced for entities (e.g., `users`, `refresh_tokens`). Spring Data JPA must be configured using the physical naming strategy:
```properties
spring.jpa.hibernate.naming.physical-strategy=org.hibernate.boot.model.naming.CamelCaseToUnderscoresNamingStrategy

```


* **Primary Keys:** Primary identifiers must use universally unique values (`java.util.UUID`) generated natively via the PostgreSQL `uuid-ossp` extension default formula (`uuid_generate_v4()`).

### 3.2 Migrations and Version Control

* **Immutable State Changes:** Direct manual changes against live database schemas are strictly prohibited. Schema states must be mutated through incremental, timestamped, up/down migration files.
* **Tooling:** Use **Flyway** or **Liquibase**. Migrations must execute idempotently inside execution routines automatically during Spring Boot application context initialization.

### 3.3 Query Execution, Drivers, and Performance

* **Raw Mapping/Execution:** Write explicit SQL expressions or use highly predictable mapping toolkits. While Spring Data JPA is acceptable for basic CRUD, heavy abstract object graphs that hide real queries are discouraged. For performance-critical auth operations, developers must use **Spring Data JDBC**, **jOOQ**, or write explicit native queries via `@Query` or `JdbcClient` to avoid N+1 issues and Hibernate session overhead.
* **Index Utilization:** Lookups executed inside the system flow must be backed by explicit indexes:
* Every query driving `/auth/login` must pass through `idx_users_email` over the `users` table.
* Every session check driving `/auth/refresh` must execute utilizing `idx_refresh_tokens_token`.


* **Connection Pooling:** Set strict HikariCP database configurations via `application.properties`:
```properties
spring.datasource.hikari.maximum-pool-size=25
spring.datasource.hikari.minimum-idle=25
spring.datasource.hikari.max-lifetime=300000
spring.datasource.hikari.connection-timeout=30000

```



---

## 4. Security & Cryptographic Standards

Security logic must follow industry-standard zero-trust practices to protect data at rest and in transit using **Spring Security 6.x**.

### 4.1 Transport Security (In-Transit)

* **TLS Requirements:** Every live endpoint must mandate TLS 1.3 encryption execution blocks. Cleartext HTTP requests must instantly terminate or route to an identical HTTPS endpoint using an edge gateway or load balancer proxy layer. Spring Security must be configured to require secure channels (`requiresChannel(c -> c.anyRequest().requiresSecure())`) if an edge proxy is not available.

### 4.2 Credential Protection (At-Rest)

* **Hashing Standard:** Plaintext passwords must be discarded immediately upon request validation. They must be passed directly into a cryptographically strong hashing mechanism before hitting storage.
* **Algorithm Choice:** Use **Argon2id** (via Spring Security's `Argon2PasswordEncoder`) or **BCrypt** with a minimum work factor of 12 (`new BCryptPasswordEncoder(12)`).

### 4.3 OAuth 2.0 & Token Architecture

* **Access Tokens:** Standardized JWT strings encoding necessary claims (`sub` [User ID], `exp` [Expiration], `iat` [Issued At]) issued using the Spring Security Jose / JWT framework. Access tokens must have short lifespans (15–60 minutes) and remain strictly stateless.
* **Refresh Tokens:** Long-lived tokens (7–30 days) stored as cryptographically random hashes in the database.
* **Token Rotation Guardrails:** When a user invokes `/auth/refresh`, the old `refresh_token` string must be flagged as `is_revoked = true` or purged instantly within an explicit database transaction (`@Transactional`). A new token pair must be returned.
* **Replay Attack Breaker Filter:** If an app consumer attempts to authenticate using an already revoked token, a custom Spring Security filter must instantly flag this behavior as a potential leak, identify the associated `user_id`, and revoke all active valid child token sessions belonging to that user.

---

## 5. Testing & Quality Assurance Standards

Code cannot be integrated into master execution branches unless it passes automated testing criteria.

```text
       ▲
      ╱ ╲     End-to-End Testing (MockMvc / WebTestClient Full Lifecycle Integration)
     ╱   ╲    
    ╱     ╲   Integration Testing (PostgreSQL Dynamic Containers via Testcontainers)
   ╱       ╲  
  ╱         ╲ Unit Testing (Mocking Engine, Payload Constraints, Custom Encoders)
 ─────────────

```

### 5.1 The Testing Pyramid

* **Unit Tests:** Must cover all validation logic, text manipulation engines, custom algorithms, response writers, and middleware. Mock database dependencies using **Mockito** framework isolations.
* **Integration Tests:** Must run against real local instances of PostgreSQL utilizing **Testcontainers** for Java. Integration tests must cover database transactions, schema indexes, constraint triggers, and raw migrations.
* **End-to-End (E2E) Tests:** Must use `@SpringBootTest` alongside `MockMvc` or `WebTestClient` to execute an unbroken automation block sequence simulating real user habits: `Register` → `Login` → `Access Protected Route` → `Refresh Token Pair` → `Logout` → `Verify Revoked Access`.

### 5.2 Automation Gates

* **Pre-Commit Hooks:** Local machines must run checkstyle/spotless check plugins and format files before pushing code to remote trees.
* **CI Validation:** Pushes to remote development branches must pass Maven/Gradle build compilation validation, complete checkstyle/SonarQube quality scans, and hit a minimum of **80% coverage** on new features.

---

## 6. Cross-Cutting Concerns & Production Readiness

### 6.1 Structured Logging

* **Standard application output logs** must be emitted exclusively via structured formatters using **Logback** configured with a JSON provider (like `logstash-logback-encoder`). Output format must be JSON to simplify collection by processing agents.

```json
{"@timestamp":"2026-05-27T23:52:42.000Z","level":"ERROR","message":"failed token verification","trace_id":"4a5b6c7d8e","user_id":"550e8400-e29b-41d4-a716-446655440000"}

```

* **Trace Propagation:** Integrated using **Spring Cloud Sleuth** or **Micrometer Tracing**. Every inbound request must be assigned a unique `trace_id` via a servlet filter. This ID must accompany every downstream log entry automatically (via MDC) to simplify tracing.
* **Data Masking:** Logs must never write sensitive parameters. Logback configuration rules or custom layout filters must mask values for keys like `password`, `refresh_token`, or personal identifying details before serialization.

### 6.2 Application Configuration

* **Twelve-Factor Methodology:** Application configuration must be injected solely using Environment Variables. Hardcoded environment strings or config file tracking within source repositories are prohibited. Configuration properties must be bound cleanly via typesafe `@ConfigurationProperties`.
* **Startup Self-Checks:** On initialization, the application context must read and validate all required configurations (such as database credentials and JWT signing keys) before completing the bootstrap lifecycle. If any required variable is missing or malformed, a custom lifecycle component or `@PostConstruct` block must fail initialization, causing the Spring container to terminate immediately with a non-zero exit code.