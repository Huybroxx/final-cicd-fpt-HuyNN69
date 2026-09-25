# DevOps Assignment 01: CI/CD Pipeline with Docker and SonarQube for FastAPI Application

## 1. Description
Build a complete CI/CD pipeline that containerizes a FastAPI application, runs automated tests, enforces code quality with SonarQube Quality Gates, and deploys using a zero-downtime deployment strategy (Blue-Green deployment). This project integrates all core units of the DevOps Essentials module into an enterprise-grade, real-world workflow.

## 2. Objectives
- Write an optimized, production-ready `Dockerfile` using multi-stage builds and security best practices (non-root user, minimal base image, health check).
- Design and implement an automated CI/CD pipeline with `lint`, `test`, `scan`, `build`, and `deploy` stages.
- Integrate SonarQube code quality analysis as a mandatory Quality Gate that blocks deployment upon failure.
- Implement a Blue-Green zero-downtime deployment strategy with automated health check verification and instant rollback capability.

## 3. Technical Requirements Checklist
- [x] **Python 3.11+ Runtime**: Configured in `Dockerfile` and `pyproject.toml`.
- [x] **Multi-Stage Dockerfile**: Builder stage (`python:3.11-slim`) compiles dependencies; final runner stage runs under non-root user (`appuser`, UID 10001).
- [x] **Strict `.dockerignore`**: Excludes tests, caches, git, and local artifacts.
- [x] **Container Health Check**: `HEALTHCHECK` probe targeting `http://localhost:8000/health`.
- [x] **Automated Testing**: 13 unit tests covering endpoints, CRUD, and errors with 100% code coverage.
- [x] **Test Reports**: Cobertura XML (`coverage.xml`) and JUnit XML (`test-results.xml`).
- [x] **SonarQube Configuration**: Configured via `sonar-project.properties`.
- [x] **Quality Gate Blocking**: `sonar.qualitygate.wait=true` with `allow_failure: false` in CI/CD.
- [x] **CI/CD Pipelines**: Provided for both GitLab CI (`.gitlab-ci.yml`) and GitHub Actions (`.github/workflows/ci-cd.yml`).
- [x] **Zero-Downtime Deployment**: Blue-Green deployment with Nginx upstream switching (`scripts/blue_green_deploy.sh`) and instant rollback (`scripts/rollback.sh`).

---

## 4. Assessment Questions & Detailed Answers

### Question 1: Explain why multi-stage builds are used in the Dockerfile and how they improve both image size and security.
- **Image Size Optimization**: In a single-stage build, build tools (compilers, build headers, pip caches, wheel build directories) remain in the final layers, inflating image size to 800MB–1.2GB. In a multi-stage build, compilers and build dependencies reside exclusively in the `builder` stage. The `runner` stage copies solely the compiled virtual environment `/opt/venv`, dropping the final image footprint to ~140MB (~70% reduction).
- **Security Hardening (Attack Surface Minimization)**: By excluding compilers (`gcc`, `clang`, `make`) from production images, attackers who exploit a remote vulnerability cannot compile exploits or install unauthorized binaries inside the container.
- **Vulnerability (CVE) Reduction**: Smaller base images have fewer installed system libraries, resulting in significantly fewer reported CVEs during security scans (Trivy / Clair).
- **Non-Root Execution**: Multi-stage separation cleanly enables running the container process under a dedicated non-root system user (`appuser`, UID 10001), preventing container breakout and root escalation attacks.

### Question 2: Describe the complete CI/CD pipeline flow from a developer pushing code to the app being deployed in production.
1. **Developer Push**: A commit is pushed or a Pull Request/Merge Request is submitted to the repository.
2. **Lint Stage (`lint`)**: Static syntax and style checkers (`flake8` and `black --check`) ensure clean, PEP 8-compliant code.
3. **Test Stage (`test`)**: Automated unit tests execute using `pytest`. Test execution reports (`test-results.xml`) and Cobertura coverage reports (`coverage.xml`, achieving 100% coverage) are generated as artifacts.
4. **Scan Stage (`scan`)**: SonarQube Scanner CLI runs and synchronously waits for Quality Gate results (`-Dsonar.qualitygate.wait=true`). If the Quality Gate fails (e.g. coverage below threshold, new bugs detected), the job fails and strictly halts the pipeline, preventing deployment.
5. **Build Stage (`build`)**: The production multi-stage Docker image is built and tagged with `$CI_COMMIT_SHORT_SHA` and `latest`, then pushed to the Container Registry.
6. **Deploy Stage (`deploy`)**: The Blue-Green zero-downtime deployment script runs:
   - Detects the current active environment (`blue` or `green`).
   - Deploys the new release into the idle slot.
   - Runs automated health check probes against the new release.
   - On success: Swaps Nginx upstream traffic and hot-reloads Nginx (`nginx -s reload`). Old container is stopped.
   - On failure: Triggers automatic rollback immediately, leaving current live traffic untouched.

### Question 3: How does the SonarQube quality gate integrate with the pipeline, and what happens when the gate fails?
- **Integration**:
  - The `test` stage outputs `coverage.xml`.
  - `sonar-project.properties` links this report via `sonar.python.coverage.reportPaths=coverage.xml`.
  - The `scan` stage launches `sonar-scanner` with `-Dsonar.qualitygate.wait=true`. This causes the scanner to synchronously poll the SonarQube server until the Quality Gate status is computed.
- **Behavior on Failure**:
  - If any Quality Gate threshold is violated (e.g., Code Coverage < 80%, new Bug found, Vulnerability rating worse than A, or unreviewed Security Hotspots), SonarQube marks the Quality Gate status as `ERROR`.
  - The scanner CLI receives this status and exits with return code `1`.
  - Because `allow_failure: false` is configured, the CI job fails immediately.
  - Downstream stages (`build` and `deploy`) are automatically blocked/cancelled. No image is deployed to production, guaranteeing zero untested or vulnerable code reaches users.
