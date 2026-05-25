## High-Level Timeline Summary

* **Total Duration:** **8 Working Days** (Approx. 1.5 to 2 calendar weeks)
* **Execution Strategy:** Sequential, milestone-driven sprints.

| Phase / Module | Estimated Duration | Focus |
| --- | --- | --- |
| **Phase 1: Foundation & DB Setup** | 1 Day | DB Schema, Migrations, Infrastructure scaffolding. |
| **Phase 2: Module 1 (Onboarding)** | 3 Days | Validation, Argon2/BCrypt hashing, User Creation API. |
| **Phase 3: Module 2 (OAuth & JWT)** | 3–5 Days | Token generation, Refresh/Rotation logic, Revocation. |
| **Phase 4: Security, E2E & Hardening** | 1–2 Days | HTTPS config, global exception handling, penetration testing. |

---

### Phase 1: Foundation & Database Architecture (Day 1) (26/05/2026)

Even with sequential development, you must lay down the bedrock first.

* **Tasks:** * Set up the repository boilerplate, linting, and CI/CD pipeline scaffolding.
* Design and execute database migrations for the `Users` table and the `RefreshTokens` storage table.
* Configure the database connection pool.


* **Deliverable:** A running backend skeleton connected to a live database.

---

### Phase 2: Module 1 – User Creation (Days 3) (27/05/2026 - 29/05/2026)

This phase focuses entirely on data ingestion, validation, and cryptography.

* **Day 2: Validation & Security Infrastructure**
* Implement input validation layer (RFC 5322 email regex, password strength checkers).
* Integrate cryptography library for password hashing (Argon2id recommended for modern apps, or BCrypt).


* **Day 3: Core API & Persistence**
* Build the `POST /auth/register` endpoint.
* Implement user checking logic (`409 Conflict` if email exists).
* Persist the record with `is_active: true`.


* **Day 4: Unit Testing & Boundary QA**
* Since tasks cannot run in parallel, the developer writes exhaustive unit tests for edge cases (e.g., SQL injection attempts in fields, extreme password lengths).


---

### Phase 3: Module 2 – OAuth 2.0 & Token Management (Days 5) (30/05/2026 - 03/06/2026)

This is the most complex phase of the FSD. It requires careful sequential handling of token states.

* **Day 5: Authentication & Access Token Generation (`/login`)**
* Implement `POST /auth/login` verifying the request against the Argon2/BCrypt hash.
* Build the JWT signing engine (injecting `sub`, `exp`, and `iat` claims).
* Return the short-lived Access Token.


* **Day 6: Refresh Token Lifecycle & Persistence**
* Implement long-lived cryptographically secure random string or JWT for the Refresh Token.
* Save hashed refresh tokens to the database linked to the User ID.
* Implement the `POST /auth/refresh` endpoint to exchange a valid refresh token for a new access token.


* **Day 7: Token Rotation & Replay Attack Protection**
* Add the "disposed and rotated" logic: when a refresh token is used, invalidate it immediately, and issue a fresh pair.
* *Security catch:* If an invalidated refresh token is used again, flag a potential breach and clear all active sessions for that user.


* **Day 8: Revocation (`/logout`)**
* Implement `POST /auth/logout`.
* Delete/invalidate the active refresh token from the database, rendering future refresh attempts impossible.


---

### Phase 4: Technical Constraints, Security & Hardening (Days 9 – 10) (04/06/2026 - 05/06/2026)

Finishing the implementation by wrapping the entire sequential pipeline in the requested constraints.

* **Day 9: Global Error Handling & Middleware**
* Implement interceptors/middleware to enforce token validation on protected endpoints.
* Standardize RFC-compliant error responses (`401 Unauthorized`, `403 Forbidden`).


* **Day 10: HTTPS, Secrets, & Final E2E Sign-off**
* Ensure all cookie flags are set to `HttpOnly`, `Secure`, and `SameSite=Strict`.
* Move signing keys to an environment secret manager.
* Run an uninterrupted, end-to-end integration test loop: Register $\rightarrow$ Login $\rightarrow$ Access Protected Resource $\rightarrow$ Refresh Token $\rightarrow$ Logout $\rightarrow$ Verify Old Tokens Failure.


---