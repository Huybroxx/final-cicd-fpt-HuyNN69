# Đồ Án DevOps: CI/CD Pipeline FastAPI với Docker, SonarQube Quality Gate & Triển Khai Blue-Green

Dự án xây dựng quy trình CI/CD Pipeline hoàn chỉnh cho ứng dụng FastAPI: đóng gói Docker theo mô hình Multi-stage build, kiểm soát chất lượng mã nguồn bắt buộc với SonarQube Quality Gate và triển khai không gián đoạn dịch vụ (Zero-Downtime Deployment) theo chiến lược Blue-Green trên máy chủ Cloud VPS.

---

## Thông Tin Đồ Án & Triển Khai Thực Tế

- **Học viên:** Ngô Ngọc Huy
- **Domain Production:** [http://fuji.io.vn](http://fuji.io.vn) | [http://www.fuji.io.vn](http://www.fuji.io.vn)
- **Máy chủ VPS Production:** `161.118.195.1` (Ubuntu 22.04 LTS)
- **Kho lưu trữ GitHub:** [https://github.com/Huybroxx/final-cicd-fpt-HuyNN69](https://github.com/Huybroxx/final-cicd-fpt-HuyNN69)

---

## Kiến Trúc Quy Trình CI/CD & Triển Khai

```text
[ Git Push (main) ] 
       │
       ▼
 [ Stage 1: Lint ] ──► Kiểm tra chuẩn cú pháp (flake8, black)
       │
       ▼
 [ Stage 2: Test ] ──► Chạy 13 unit tests (pytest), xuất coverage.xml & test-results.xml
       │
       ▼
 [ Stage 3: Scan ] ──► Quét SonarQube & kiểm tra Quality Gate bắt buộc
       │
       ├─────────────────────────────────┐
       ▼ (Quality Gate PASS)             ▼ (Quality Gate FAIL)
 [ Stage 4: Build ]               [ Block Pipeline ]
 (Build Docker Image tối ưu)      (Dừng ngay lập tức, chặn Deploy)
       │
       ▼
 [ Stage 5: Deploy ] ──► SSH VPS 161.118.195.1 (Zero-Downtime Blue-Green)
       │
       ├─────────────────────────┬─────────────────────────┐
       ▼                         ▼                         ▼
  [ Nginx Proxy ]        [ app-blue (8001) ]       [ app-green (8002) ]
  (fuji.io.vn:80)           Môi trường 1              Môi trường 2
```

---

## Cấu Trúc Thư Mục Dự Án

```text
.
├── backend/                        # Mã nguồn ứng dụng FastAPI và context build Docker
│   ├── app/                        # Gói ứng dụng chính
│   │   ├── api/                    # Router và các API endpoint (/health, /items)
│   │   ├── models/                 # Pydantic schemas dữ liệu
│   │   ├── config.py               # Cấu hình môi trường ứng dụng
│   │   └── main.py                 # File khởi chạy ứng dụng FastAPI
│   ├── tests/                      # Bộ kiểm thử tự động pytest
│   ├── Dockerfile                  # Dockerfile Multi-stage build tối ưu cho production
│   ├── .dockerignore               # Loại bỏ file rác khi build Docker context
│   ├── requirements.txt            # Thư viện runtime production
│   ├── requirements-dev.txt        # Thư viện phục vụ dev, lint và test
│   └── pyproject.toml              # Cấu hình cho Pytest, Coverage và Black
├── nginx/
│   └── default.conf                # Cấu hình Nginx Reverse Proxy điều hướng Blue-Green
├── scripts/
│   ├── blue_green_deploy.sh        # Kịch bản tự động triển khai Zero-Downtime & Rollback
│   └── rollback.sh                 # Kịch bản khôi phục phiên bản trước thủ công
├── docker-compose.yml              # Docker Compose môi trường cục bộ
├── docker-compose.blue-green.yml   # Stack Blue-Green Production (Nginx + Blue + Green)
├── sonar-project.properties        # Cấu hình SonarQube Scanner
├── .gitlab-ci.yml                  # Cấu hình pipeline GitLab CI
└── .github/workflows/ci-cd.yml     # Cấu hình pipeline GitHub Actions
```

---

## Hướng Dẫn Chạy & Kiểm Thử Cục Bộ

### 1. Chạy Unit Test và Đo Độ Phủ Mã Nguồn
```bash
cd backend
pip install -r requirements-dev.txt
pytest -v --cov=app --cov-report=term-missing tests/
```

### 2. Khởi Chạy Ứng Dụng với Docker Compose
```bash
docker compose up -d --build
curl http://localhost:8000/health
```

### 3. Thực Thi Triển Khai Blue-Green Thủ Công
```bash
chmod +x scripts/blue_green_deploy.sh scripts/rollback.sh
./scripts/blue_green_deploy.sh
curl http://localhost/health
```

---

## Trả Lời 3 Câu Hỏi Đánh Giá Kỹ Thuật (Q&A)

### Câu 1: Giải thích tại sao kỹ thuật Multi-stage build được sử dụng trong Dockerfile và nó cải thiện kích thước image cùng tính bảo mật như thế nào?

Kỹ thuật **Multi-stage build** sử dụng nhiều chỉ thị `FROM` độc lập trong cùng một file `Dockerfile` để phân tách hoàn toàn môi trường đóng gói (build environment) khỏi môi trường thực thi runtime:

1. **Tối ưu hóa kích thước Image (Image Size Reduction):**
   - Quá trình biên dịch mã nguồn và cài đặt dependencies Python yêu cầu nhiều công cụ hệ thống nặng như `gcc`, `make`, `build-essential` cùng các gói header của hệ điều hành.
   - Trong Dockerfile multi-stage, các công cụ cồng kềnh này chỉ tồn tại tạm thời ở tầng `builder`.
   - Tầng `runner` cuối cùng chỉ kế thừa từ base image siêu gọn `python:3.11-slim` và sao chép đúng thư mục virtual environment `/opt/venv` đã hoàn thiện.
   - Kỹ thuật này giúp giảm dung lượng image từ gần **900MB xuống chỉ còn ~140MB** (giảm tới hơn 80%), tăng tốc độ tải image qua mạng và rút ngắn thời gian khởi động container.

2. **Gia cố bảo mật (Security Hardening):**
   - **Thu hẹp bề mặt tấn công (Attack Surface):** Việc loại bỏ toàn bộ trình biên dịch và công cụ phát triển khỏi image production ngăn chặn tin tặc biên dịch mã độc hay leo thang đặc quyền nếu ứng dụng bị dính lỗ hổng thực thi mã từ xa (RCE).
   - **Giảm thiểu lỗ hổng bảo mật (CVEs):** Image tối giản chứa ít gói phần mềm hệ điều hành hơn, giúp giảm thiểu tối đa các cảnh báo lỗ hổng khi quét bằng các công cụ như Trivy hay Snyk.
   - **Thực thi với Non-root User:** Container được cấu hình chạy dưới tài khoản người dùng thông thường (`appuser:appgroup`, UID 10001) thay vì quyền `root`, ngăn chặn nguy cơ tấn công thoát khỏi container ra máy chủ vật lý (Host breakout).

---

### Câu 2: Mô tả luồng hoạt động hoàn chỉnh của CI/CD Pipeline từ lúc lập trình viên push code cho đến khi ứng dụng được triển khai trên Production?

Quy trình tự động hóa hoàn toàn từ khi commit đến khi release diễn ra qua 5 giai đoạn tuần tự:

1. **Trigger & Checkout**: Lập trình viên push commit hoặc mở Pull Request lên nhánh `main` hoặc `develop`. GitHub Actions phát hiện sự kiện và kích hoạt runner checkout mã nguồn mới nhất.
2. **Stage 1 - Lint**: Runner chạy `flake8` và `black --check` để kiểm tra chuẩn cú pháp PEP 8 và định dạng code. Bất kỳ lỗi định dạng hay vi phạm quy chuẩn nào cũng sẽ khiến pipeline dừng ngay lập tức.
3. **Stage 2 - Test**: Runner thực thi toàn bộ 13 unit tests bằng `pytest`, xuất báo cáo định dạng JUnit (`test-results.xml`) và báo cáo độ phủ mã nguồn Cobertura (`coverage.xml` đạt 100% code coverage).
4. **Stage 3 - Scan (SonarQube Quality Gate)**: Scanner CLI gửi mã nguồn và file `coverage.xml` lên máy chủ SonarQube. Nhờ cờ `sonar.qualitygate.wait=true`, scanner đồng bộ chờ kết quả từ Quality Gate. Nếu có bất kỳ tiêu chí nào không đạt, job scan sẽ kết thúc với exit code khác 0 và **ngắt toàn bộ pipeline, chặn đứng bước build và deploy**.
5. **Stage 4 - Build**: Sau khi vượt qua kiểm định chất lượng, runner tiến hành build Docker image theo mô hình multi-stage, gắn tag Commit SHA và `latest`.
6. **Stage 5 - Deploy (Blue-Green Zero-Downtime)**: Runner kết nối SSH an toàn vào máy chủ VPS `161.118.195.1`:
   - Xác định môi trường đang active (ví dụ: `blue`).
   - Khởi động môi trường dự phòng (`green`) với phiên bản mới nhất.
   - Thực hiện vòng lặp health check thăm dò `curl http://localhost:8002/health` đến khi container mới sẵn sàng.
   - Khi dịch vụ ổn định: Nginx cập nhật upstream và thực hiện hot-reload (`nginx -s reload`) để chuyển toàn bộ lưu lượng người dùng sang `green` mà không làm rớt bất kỳ kết nối mạng nào (Zero-Downtime).
   - Sau đó tắt container `blue` cũ. Nếu container mới bị lỗi trong lúc health check, script tự động giữ nguyên môi trường cũ và tắt container mới (Rollback tức thì).

---

### Câu 3: SonarQube Quality Gate tích hợp vào Pipeline như thế nào, và điều gì sẽ xảy ra khi Quality Gate bị thất bại (Failed)?

- **Cơ chế tích hợp:**
  - File `backend/coverage.xml` sinh ra từ stage test được ánh xạ trực tiếp trong cấu hình `sonar-project.properties` qua thuộc tính `sonar.python.coverage.reportPaths=backend/coverage.xml`.
  - Trong pipeline CI/CD, lệnh quét được cấu hình tham số `-Dsonar.qualitygate.wait=true`. Tham số này chỉ định Scanner CLI sau khi gửi dữ liệu phải giữ kết nối và liên tục thăm dò trạng thái tính toán Quality Gate của máy chủ SonarQube.
- **Hiện tượng xảy ra khi Quality Gate thất bại:**
  - Nếu bất kỳ chỉ số nào vi phạm ngưỡng cho phép (độ phủ code không đạt, phát hiện Bug mới, lỗ hổng Security Vulnerability hoặc độ nợ kỹ thuật Technical Debt vượt chuẩn), máy chủ SonarQube sẽ trả về trạng thái `FAILED/ERROR`.
  - Scanner CLI bắt được trạng thái này và lập tức thoát với mã lỗi `exit 1`.
  - Vì stage `scan` được cấu hình chốt chặn bắt buộc (`allow_failure: false`), job sẽ bị đánh dấu đỏ (Failed).
  - Các stage phía sau (`build` và `deploy`) có quan hệ phụ thuộc (`needs: scan`) sẽ bị **hủy bỏ tự động (Cancelled/Skipped)**.
  - Tuyệt đối không có image lỗi nào được build hay triển khai ra máy chủ production, bảo vệ hệ thống luôn trong trạng thái ổn định và an toàn.