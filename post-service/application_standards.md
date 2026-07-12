# Application & Engineering Standards: Post Service (Java)

### 1. Framework & Dependencies

* **Core Runtime:** Java 21 LTS (utilizing Virtual Threads for I/O bound database operations).
* **Framework:** Spring Boot 3.x (`spring-boot-starter-web`, `spring-boot-starter-data-jpa`, `spring-boot-starter-validation`).
* **Database Driver:** PostgreSQL (using `HikariCP` for high-performance connection pooling).
* **JSON Processing:** Jackson (configured to serialize/deserialize Java 8 Date/Time types automatically).

---

### 2. Microservice Isolation & Boundaries

* **Data Ownership:** The Post Service explicitly owns the `posts` table. Under no circumstances should this service access the `users` or `profiles` tables directly via SQL joins or database cross-talk.
* **Logical Relationships:** User data inside this service is stored *only* as a logical foreign key (`UUID user_id`). If user profile info (like their `display_name` or `avatar_url`) is required to render a post summary, it must be fetched at runtime via a gRPC call to the Auth & User Service or assembled by an API Gateway.

---

### 3. Database & Concurrency Rules

* **ID Generation:** All post IDs must be generated as **UUIDv4** types on the application layer using Java’s `UUID.randomUUID()` (or via Hibernate's `@GeneratedValue(strategy = GenerationType.UUID)`) to prevent ID enumeration attacks and streamline distributed tracing.
* **Pagination & Sorting:** All endpoints returning lists of posts must force Spring Data's `Pageable` mechanism. Unpaged queries are strictly forbidden. The default sort order must be explicitly set to `createdAt DESC`.
* **Transaction Management:** Use Spring’s `@Transactional` annotation meticulously.
* Read operations should use `@Transactional(readOnly = true)` to optimize performance and prevent dirty read flushes.
* Write operations must keep transactions as short as possible to minimize row-locking times.



---

### 4. Code Quality & Defensive Programming

* **Input Sanitization:** The `content` field must be strictly validated using JSR-380 validation constraints at the Controller layer:
```java
public record CreatePostRequest(
    @NotBlank(message = "Post content cannot be empty.")
    @Size(max = 1000, message = "Post content cannot exceed 1000 characters.")
    String content
) {}

```


* **Immutability:** Data Transfer Objects (DTOs) used for API request/response mapping must be implemented using **Java Records** to guarantee immutability and thread safety.
* **Mapping:** Use a compile-time mapper like **MapStruct** to convert between internal Entities (JPA) and external Records (DTOs) to keep mapping logic out of the core business service.

---

### 5. Resiliency & Performance

* **Virtual Threads:** Enable Virtual Threads in `application.properties` to ensure that blockages on database operations don't starve the server's thread pool:
```properties
spring.threads.virtual.enabled=true

```


* **Circuit Breakers:** If the Post Service calls external APIs or downstream systems, wrap those outgoing HTTP/gRPC boundaries using `Resilience4j` circuit breakers to fail-fast if external dependencies degrade.
* **Database Connection Pools:** The connection pool size must be explicitly tuned based on active load test results. Default configuration values must be overridden:
```properties
spring.datasource.hikari.maximum-pool-size=20
spring.datasource.hikari.minimum-idle=5

```

