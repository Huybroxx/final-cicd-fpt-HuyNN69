# FastAPI Enterprise DevOps Pipeline: Docker, SonarQube Quality Gate & Blue-Green Zero-Downtime Deployment

> **Course:** DevOps Essentials for Developer — Assignment 01 (Final Module)  
> **Student:** Ngô Ngọc Huy  
> **Student ID / Email:** `Huynn69@fpt.com`  
> **Branch:** `huynn69`  
> **Target Application:** FastAPI Python 3.11+ High-Performance REST Service  
> **Containerization:** Multi-Stage Dockerfile with Non-Root User & Healthcheck  
> **Quality Gate:** SonarQube Automated Analysis & Strict Deployment Blocker  
> **Deployment Strategy:** Blue-Green Zero-Downtime with Automated Health Probes & Instant Rollback  

---

## 1. System Architecture & Workflow

```text
 ┌────────────────────────────────────────────────────────────────────────────────────────┐
 │                                   CI/CD PIPELINE LIFECYCLE                             │
 └────────────────────────────────────────────────────────────────────────────────────────┘

 [ Developer ] ────► [ Git Push ]
                           │
                           ▼
                 ┌───────────────────┐
                 │    Stage 1: LINT  │ ──► flake8 & black code style check
                 └─────────┬─────────┘
                           │ (pass)
                           ▼
                 ┌───────────────────┐
                 │    Stage 2: TEST  │ ──► pytest & pytest-cov (100% Coverage)
                 └─────────┬─────────┘     Outputs: coverage.xml & test-results.xml
                           │ (pass)
                           ▼
                 ┌───────────────────┐
                 │    Stage 3: SCAN  │ ──► SonarQube Scanner CLI
                 └─────────┬─────────┘     Enforces: sonar.qualitygate.wait=true
                           │
              ┌────────────┴────────────┐
              │                         │
       [ Quality Gate PASS ]     [ Quality Gate FAIL ]
              │                         │
              ▼                         ▼
     ┌──────────────────┐      ╔══════════════════════════╗
     │  Stage 4: BUILD  │      ║   PIPELINE TERMINATED    ║
     └────────┬─────────┘      ║  Deployment Blocked!     ║
              │ (push image)   ╚══════════════════════════╝
              ▼
     ┌──────────────────┐
     │  Stage 5: DEPLOY │ ──► Blue-Green Zero-Downtime Deployment
     └──────────────────┘

                                    │
                                    ▼
       ┌─────────────────────────────────────────────────────────┐
       │             PRODUCTION RUNTIME INFRASTRUCTURE           │
       └─────────────────────────────────────────────────────────┘

                         [ Client HTTP Request ]
                                    │
                                    ▼
                      ┌───────────────────────────┐
                      │  Nginx Reverse Proxy (80) │
                      └─────────────┬─────────────┘
                                    │
                  ┌─────────────────┴─────────────────┐
                  │ (Live Traffic)                    │ (Idle / Deploy Target)
                  ▼                                   ▼
        ┌───────────────────┐               ┌───────────────────┐
        │  app-blue (8001)  │               │  app-green (8002) │
        │  FastAPI Runtime  │               │  FastAPI Runtime  │
        │  Non-Root User    │               │  Non-Root User    │
        │  Active Release   │               │  Target Release   │
        └───────────────────┘               └───────────────────┘
```

---

## 2. Directory Structure

```text
07_DevOps/Final/
├── .github/
│   └── workflows/
│       └── ci-cd.yml             # GitHub Actions CI/CD Pipeline
├── .gitlab-ci.yml                 # GitLab CI/CD Pipeline
├── .dockerignore                  # Strict Docker context filter
├── Dockerfile                     # Multi-stage production build (builder + runner)
├── docker-compose.yml             # Standalone development compose
├── docker-compose.blue-green.yml  # Production Blue-Green deployment compose
├── pyproject.toml                 # Pytest, Coverage, and Black configurations
├── requirements.txt               # Application runtime dependencies
├── requirements-dev.txt           # Testing, coverage & linting dependencies
├── sonar-project.properties       # SonarQube scanner properties & coverage linkage
├── requirement.md                 # Assignment specifications and guidelines
├── README.md                      # Comprehensive technical documentation & Q&A
├── app/
│   ├── __init__.py
│   ├── config.py                  # Pydantic Settings configuration
│   ├── main.py                    # FastAPI application instance & root routes
│   ├── api/
│   │   ├── __init__.py
│   │   ├── router.py              # Consolidated API v1 router
│   │   └── endpoints/
│   │       ├── __init__.py
│   │       ├── health.py          # /health probe endpoint for Docker & Nginx
│   │       └── items.py           # RESTful CRUD operations
│   └── models/
│       ├── __init__.py
│       └── item.py                # Pydantic domain & request/response schemas
├── nginx/
│   └── default.conf               # Nginx reverse proxy & upstream routing
├── scripts/
│   ├── blue_green_deploy.sh       # Automated zero-downtime deployment & rollback
│   └── rollback.sh                # Emergency instant rollback script
└── tests/
    ├── __init__.py
    ├── conftest.py                # Pytest fixtures & TestClient configuration
    ├── test_health.py             # Health probe unit tests
    └── test_items.py              # CRUD, validation, and search unit tests
```

---

## 3. Technical Implementation Details

### 3.1. Multi-Stage Dockerfile
- **Stage 1 (builder):** Uses `python:3.11-slim`, installs `build-essential` if C-compilation is needed, creates an isolated virtual environment at `/opt/venv`, and pre-compiles wheels.
- **Stage 2 (runner):** Starts from a fresh `python:3.11-slim`. Copies solely `/opt/venv` from builder, installs minimal runtime `curl` for the health check probe, creates a dedicated system user (`appuser:appgroup`, UID 10001), drops root privileges with `USER appuser:appgroup`, and defines an automated `HEALTHCHECK`.
- **Image Size:** Reduced by ~70% compared to single-stage build.

### 3.2. Automated Testing & 100% Code Coverage
- Pytest suite executes 13 tests covering root endpoints, health probes, CRUD item handling, 404 error responses, Pydantic validation failures, search query parameters, and pagination.
- Generates:
  - `coverage.xml`: Cobertura format report ingested directly by SonarQube.
  - `test-results.xml`: JUnit XML report ingested by CI/CD test visualizers.
- **Coverage Result:** **100% code coverage** achieved across all application files.

### 3.3. SonarQube Quality Gate Integration
- Configured in `sonar-project.properties`:
  - `sonar.sources=app`
  - `sonar.tests=tests`
  - `sonar.python.coverage.reportPaths=coverage.xml`
  - `sonar.python.xunit.reportPath=test-results.xml`
  - `sonar.qualitygate.wait=true`
- In CI/CD: Job runs with `allow_failure: false`. If SonarQube Quality Gate fails (e.g. coverage drops below threshold or vulnerabilities are detected), the pipeline fails immediately and terminates before build/deploy.

### 3.4. Zero-Downtime Blue-Green Deployment
- **Architecture:** Nginx reverse proxy routes public port 80 traffic to either `app-blue:8000` (port 8001) or `app-green:8000` (port 8002).
- **Execution (`scripts/blue_green_deploy.sh`):**
  1. Identifies the active container (e.g., `blue`).
  2. Spawns the updated container in the idle slot (e.g., `green`).
  3. Executes a health check loop querying `http://localhost:8002/health`.
  4. If healthy: Nginx upstream configuration is switched to `app-green:8000` and reloaded with `nginx -s reload` (hot reload without terminating active worker connections). Previous container is stopped.
  5. If unhealthy: Script executes automatic rollback, stops the failed container, and leaves the live container running untouched.

---

## 4. Answers to Mandatory Questions

### Question 1: Explain why multi-stage builds are used in the Dockerfile and how they improve both image size and security.

**Answer:**
Multi-stage builds allow developers to define multiple `FROM` instructions within a single `Dockerfile`. Each stage represents a discrete, isolated build step, and artifacts can be selectively transferred from one stage to another using `COPY --from=<stage>`.

1. **Improvement in Image Size:**
   - **Isolation of Build Tools:** In Python applications, compiling binary wheels (such as `psycopg2`, cryptography, or native C extensions) requires `gcc`, `make`, `build-essential`, and development headers. These packages add 400MB to 1GB of overhead.
   - **Elimination of Build Artifacts:** In a single-stage build, build caches, temporary source archives, and package manager indexes remain trapped in intermediate image layers. With multi-stage builds, all compilers and caches remain in the `builder` stage. The final `runner` stage copies solely the compiled virtual environment `/opt/venv`, reducing final image size down to ~140MB.
   - **Fast Distribution:** Smaller images pull and push significantly faster over the network, dramatically speeding up CI/CD pipeline runs and auto-scaling events.

2. **Improvement in Security:**
   - **Minimization of Attack Surface:** By excluding build tools (`gcc`, `pip`, development headers) from the production image, attackers who achieve code execution cannot compile arbitrary C exploits, rootkits, or cryptominers directly inside the container.
   - **Reduction of Vulnerabilities (CVEs):** Container scanners (e.g., Trivy, Snyk, Clair) audit every installed package. By removing unnecessary OS packages and build dependencies, the number of Common Vulnerabilities and Exposures (CVEs) is reduced to the bare minimum.
   - **Enforcement of Non-Root User:** Multi-stage builds facilitate clean privilege separation. The final stage sets up a dedicated system user (`appuser`, UID 10001) without administrative rights. Even in the event of an application compromise, the attacker cannot modify system binaries or escape the container namespace.

---

### Question 2: Describe the complete CI/CD pipeline flow from a developer pushing code to the app being deployed in production.

**Answer:**
The complete end-to-end lifecycle follows an automated 5-stage pipeline:

1. **Trigger & Checkout:**
   - A developer pushes code or opens a Merge Request to `main`/`develop`.
   - The CI server (GitLab CI / GitHub Actions) detects the event, spawns an isolated runner container, and checks out the commit repository with full Git history.
2. **Stage 1 — Linting (`lint`):**
   - Runner executes static analysis tools (`flake8` and `black --check`).
   - Ensures strict adherence to PEP 8 standards, syntax correctness, and uniform code formatting. Any syntax errors or styling violations fail fast here (Shift-Left principle).
3. **Stage 2 — Automated Testing & Coverage (`test`):**
   - Runner installs test dependencies (`requirements-dev.txt`) and executes `pytest`.
   - All 13 unit tests are run against the FastAPI application.
   - Generates two machine-readable artifacts: `test-results.xml` (JUnit test execution report) and `coverage.xml` (Cobertura code coverage report, achieving 100% coverage).
4. **Stage 3 — SonarQube Quality Gate (`scan`):**
   - The SonarQube Scanner CLI launches and transfers source code, test metadata, and `coverage.xml` to the SonarQube server.
   - SonarQube analyzes the code for Bugs, Vulnerabilities, Security Hotspots, and Code Smells.
   - Using `-Dsonar.qualitygate.wait=true`, the scanner synchronously polls SonarQube until the Quality Gate evaluation completes.
   - **Critical Gate:** If code coverage is below the threshold or new bugs exist, SonarQube returns `FAIL`. The CI job exits with code 1, **blocking all downstream build and deploy stages**.
5. **Stage 4 — Container Build & Push (`build`):**
   - If and only if the Quality Gate passes, Docker-in-Docker builds the optimized multi-stage image.
   - The image is immutably tagged with `$CI_COMMIT_SHORT_SHA` and `latest`, then pushed to the Container Registry.
6. **Stage 5 — Zero-Downtime Deployment (`deploy`):**
   - The deployment script executes the Blue-Green workflow on the target environment:
     - Identifies the current active container (e.g., `blue`).
     - Launches the new release container in the idle slot (e.g., `green`).
     - Polls `http://localhost:8002/health` up to 10 times.
     - Upon receiving `"status": "ok"`, updates Nginx configuration to point to `app-green:8000` and issues `nginx -s reload` (hot reload with zero dropped connections).
     - Stops the retired `blue` container.
     - If the health check fails, triggers automatic rollback, destroys the unhealthy container, and leaves the live container undisturbed.

---

### Question 3: How does the SonarQube quality gate integrate with the pipeline, and what happens when the gate fails?

**Answer:**

1. **How the Quality Gate Integrates:**
   - **Coverage Linkage:** The pipeline's `test` stage outputs `coverage.xml`. The `sonar-project.properties` explicitly maps this file via `sonar.python.coverage.reportPaths=coverage.xml`.
   - **Synchronous Execution:** By default, `sonar-scanner` performs an asynchronous upload and terminates immediately. In our pipeline, we configure `sonar.qualitygate.wait=true` (or pass `-Dsonar.qualitygate.wait=true`). This forces the CLI scanner to pause the CI job and poll the SonarQube server API until the Quality Gate computation finishes.
   - **Authentication & Security:** Authentication is handled securely via protected CI/CD environment variables (`SONAR_TOKEN` and `SONAR_HOST_URL`), ensuring no secrets are exposed in source code.

2. **What Happens When the Quality Gate Fails:**
   - **Non-Zero Exit Code:** If any Quality Gate metric fails (e.g., code coverage < 80%, presence of Blocker/Critical bugs, unreviewed Security Hotspots, or high technical debt), SonarQube flags the analysis as `FAILED`. The scanner CLI immediately intercepts this status and exits with return code `1`.
   - **Pipeline Stage Halting:** In the pipeline definition, the scan stage has `allow_failure: false`. An exit code of 1 causes the CI engine to immediately mark the job as failed (red state).
   - **Deployment Prevention:** Subsequent stages (`build` and `deploy`) have explicit dependencies (`needs: [sonarqube:scan]` or standard stage ordering). Because the scan stage failed, all subsequent jobs are automatically skipped/aborted. No Docker image is pushed to production, and no deployment script is ever called.
   - **Developer Feedback:** The developer receives instant notification in the Merge Request / Commit view with a direct URL to the SonarQube dashboard highlighting the exact lines of code that violated the quality policy.

---

## 5. Local Execution & Verification Guide

### 5.1. Run Unit Tests & Generate Coverage
```bash
# 1. Install dependencies
pip install -r requirements-dev.txt

# 2. Run pytest with coverage
pytest -v --cov=app --cov-report=term-missing --cov-report=xml:coverage.xml --junitxml=test-results.xml tests/
```

### 5.2. Build & Run Single Container
```bash
# Build multi-stage image
docker build -t fastapi-devops-app:latest .

# Run container with health check
docker run -d --name fastapi_app -p 8000:8000 fastapi-devops-app:latest

# Verify health probe
curl http://localhost:8000/health
```

### 5.3. Execute Blue-Green Zero-Downtime Deployment
```bash
# Make deployment scripts executable
chmod +x scripts/blue_green_deploy.sh scripts/rollback.sh

# Run automated deployment
./scripts/blue_green_deploy.sh

# Test public proxy
curl http://localhost/health
curl http://localhost/api/v1/items
```
