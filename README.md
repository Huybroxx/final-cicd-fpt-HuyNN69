# FastAPI DevOps Pipeline: Docker, SonarQube Quality Gate & Blue-Green Deployment

Enterprise CI/CD pipeline for a FastAPI application featuring multi-stage Docker builds, SonarQube Quality Gate enforcement, and zero-downtime Blue-Green deployment with automatic rollback.

## Architecture

```text
[ Git Push ] ──► [ Lint ] ──► [ Test & Coverage ] ──► [ SonarQube Scan ]
                                                             │
                                              ┌──────────────┴──────────────┐
                                              ▼                             ▼
                                      [ Quality Gate Pass ]        [ Quality Gate Fail ]
                                              │                             │
                                              ▼                             ▼
                                      [ Docker Build ]               [ Block Deploy ]
                                              │
                                              ▼
                                 [ Blue-Green Deploy (Nginx) ]
                                 ┌────────────┴────────────┐
                                 ▼                         ▼
                          app-blue (8001)           app-green (8002)
```

## Project Structure

```text
.
├── backend/                        # Application source and build context
│   ├── app/                        # FastAPI application package
│   │   ├── api/                    # Routers & API endpoints (/health, /items)
│   │   ├── models/                 # Pydantic data schemas
│   │   ├── config.py               # Application settings
│   │   └── main.py                 # App entry point
│   ├── tests/                      # Pytest unit test suite
│   ├── Dockerfile                  # Multi-stage production build
│   ├── .dockerignore               # Isolated Docker context
│   ├── requirements.txt            # Production dependencies
│   ├── requirements-dev.txt        # Development and testing tools
│   └── pyproject.toml              # Pytest, Coverage, and Black configs
├── nginx/
│   └── default.conf                # Reverse proxy configuration
├── scripts/
│   ├── blue_green_deploy.sh        # Zero-downtime deployment script
│   └── rollback.sh                 # Manual/automated rollback script
├── docker-compose.yml              # Local development compose
├── docker-compose.blue-green.yml   # Production Blue-Green deployment stack
├── sonar-project.properties        # SonarQube scanner configuration
├── .gitlab-ci.yml                  # GitLab CI pipeline configuration
└── .github/workflows/ci-cd.yml     # GitHub Actions pipeline configuration
```

## Quick Start

### 1. Run Tests Locally

```bash
cd backend
pip install -r requirements-dev.txt
pytest -v --cov=app --cov-report=term-missing tests/
```

### 2. Run with Docker Compose

```bash
docker compose up -d --build
curl http://localhost:8000/health
```

### 3. Run Blue-Green Deployment

```bash
chmod +x scripts/blue_green_deploy.sh scripts/rollback.sh
./scripts/blue_green_deploy.sh
curl http://localhost/health
```

---

## Technical Evaluation Q&A

### 1. Why are multi-stage builds used in the Dockerfile and how do they improve image size and security?

Multi-stage builds separate the build environment from the runtime environment using multiple `FROM` instructions:

- **Image Size Reduction**:
  - Compiling dependencies and native wheels requires build tools (`gcc`, `make`, `build-essential`) and development headers that take hundreds of megabytes.
  - In a multi-stage Dockerfile, these tools and cache files remain in the `builder` stage.
  - The final `runner` stage starts from a clean `python:3.11-slim` base and copies only `/opt/venv`. This reduces image footprint from ~900MB down to ~140MB (~85% reduction), minimizing network transfer times and container startup latency.

- **Security Hardening**:
  - **Attack Surface Minimization**: Removing compilers, source code repositories, and build tools prevents attackers from compiling native exploits or rootkits inside the container if an application vulnerability (RCE) occurs.
  - **Vulnerability (CVE) Reduction**: Smaller runtime images install fewer OS packages, leading to significantly fewer reported vulnerabilities during container security scanning.
  - **Non-Root Execution**: The runtime stage creates and drops privileges to a dedicated system user (`appuser:appgroup`, UID 10001), ensuring container isolation and preventing host-level privilege escalation.

### 2. Describe the complete CI/CD pipeline flow from developer push to production deployment.

1. **Trigger**: Developer pushes code or creates a Merge Request/Pull Request on `main` or `develop`.
2. **Lint (`lint`)**: Static analysis runs `flake8` and `black --check` to enforce syntax standards and formatting rules.
3. **Test (`test`)**: Automated unit tests execute via `pytest`, generating JUnit test execution (`test-results.xml`) and Cobertura coverage reports (`coverage.xml` with 100% coverage).
4. **Scan (`scan`)**: SonarQube Scanner analyzes source code and coverage reports. The flag `sonar.qualitygate.wait=true` enforces synchronous Quality Gate verification. If thresholds are not met, the job exits with a non-zero code, immediately halting the pipeline.
5. **Build (`build`)**: Upon passing all quality checks, the multi-stage Docker image is built from `backend/Dockerfile`, tagged with the commit SHA and `latest`, and pushed to the Container Registry.
6. **Deploy (`deploy`)**: The Blue-Green deployment script executes on the deployment host:
   - Detects the current active container (`blue` or `green`).
   - Starts the updated release in the idle container slot.
   - Runs automated health check probes against the new instance.
   - On success: Updates Nginx upstream configuration and executes `nginx -s reload` (hot reload with zero dropped connections), then stops the previous container.
   - On failure: Aborts the deployment, terminates the unhealthy target container, and leaves the live environment undisturbed.

### 3. How does the SonarQube Quality Gate integrate with the pipeline, and what happens when the gate fails?

- **Integration**:
  - The `test` stage exports code coverage into `backend/coverage.xml`.
  - In `sonar-project.properties`, `sonar.python.coverage.reportPaths` maps directly to this file, and `sonar.sources` points to `backend/app`.
  - During the `scan` stage, `sonar-scanner` runs with `-Dsonar.qualitygate.wait=true`. Instead of terminating immediately after data upload, the scanner polls SonarQube until the server completes analysis and calculates the Quality Gate status (PASSED or FAILED).
- **Behavior on Failure**:
  - If code coverage falls below the required threshold or new bugs/vulnerabilities are detected, SonarQube sets the analysis status to `ERROR`.
  - The scanner CLI captures this status and exits with return code `1`.
  - Because `allow_failure: false` is configured, the CI engine marks the scan job as failed.
  - Downstream stages (`build` and `deploy`) are automatically blocked. No image is published to the registry, and no deployment commands are triggered, ensuring defective code never enters production.
