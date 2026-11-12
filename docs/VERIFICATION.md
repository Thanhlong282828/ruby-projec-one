# Quy ước Docker / kiểm chứng và release riêng — 13/11/2026

AGENTS.md hợp nhất quy ước Docker: Actions build Dockerfile của repo bằng Ruby 3.4.12 / Bundler 2.6.9, full suite MySQL hrm_test, quality gates và image smoke không mount source. CI chỉ mount public CA theo compose.ci.yaml. GHCR chỉ dùng khi có yêu cầu release riêng; bản phát hành phải ghi full commit SHA và registry manifest digest, không nhầm local image ID với registry digest. Đợt này không publish/deploy hoặc đổi runtime, quyền, SQL, strict scope.

Đã đọc lại log run cũ [42943473135](https://github.com/Thanhlong282828/ruby-projec-one/actions/runs/42943473135) của SHA 9b9c014: ERROR 1410 tại cấp DB, tests chưa chạy. Workflow/bootstrap hiện tại đã bỏ user hrm hardcode, GRANT theo MYSQL_USER allowlist qua MYSQL_PWD; không cần sửa lại lỗi đã được xử lý. Run [43287729963](https://github.com/Thanhlong282828/ruby-projec-one/actions/runs/43287729963) trên commit `710ba310054c091b199745657211a0539cd4ae11` đã xanh cả hai job: lint 554/0, types/negative probe, full MySQL 355 tests / 2311 assertions / 0 failures/errors/skips, RBI, secrets, freshSQL, image smoke, autoload, Brakeman, audit, lockfile; required steps không skip.

Lượt cập nhật quy ước này dùng branch riêng từ commit 710ba31; review/stage chỉ AGENTS.md và tài liệu kiểm chứng, giữ diff học tập bên ngoài. Các kết quả local/remote của SHA mới sẽ được bổ sung sau khi chạy; số liệu run 710ba31 ở trên là bằng chứng lịch sử, không thay cho SHA mới.

---

# Review và chuẩn bị branch kiểm chứng GitHub — 13/11/2026

Branch `codex/verify-erp-baseline`, origin `Thanhlong282828/ruby-projec-one`. Giữ main và production ngoài phạm vi. Lựa chọn source đã kiểm chứng gồm12Engines, CQRS/contracts, Payroll snapshot/export/concurrency fixes, IAM/Leave security hiện có, SQL schema/migrations, Sorbet/RBI/tests/tooling và evidence liên quan. Tài liệu TXT đang học, mapping/roadmap không cần cho runtime/test và file make chưa review được giữ ngoài commit; docs/env-feature-map.json cần cho EnvFeatureAuditTest nên đi cùng tooling. File .DS_Store bị loại, không force-add.

Log run cũ42943473135 tại SHA9b9c014: ERROR1410 khi GRANT cho hrm không tồn tại, tests skipped. Bootstrap mới lấy MYSQL_USER thật (allowlist ký tự) thay hardcode user; dùng MYSQL_PWD tránh password argument. .env.example dùng placeholder DB password, setup sinh ngẫu nhiên, không sửa .env thật. compose.ci.yaml chỉ dành cho jobverify: app từ image, mount publicCAreadonly, tránh bind checkout UIDrunner khácUID1000; local Compose mặc định không đổi.

Git index được xuất ra thư mục tạm riêng và kiểm inventory trước commit: không privateenv/key/dump business/CSV/log; SQL chỉstructureDDL +schema_migrations. Gitleaks quét chính snapshot staged (cả file cũ còn trong commit), synthetic-token rejection/redaction đạt, không thêm ignore. Kết quả test/Actions của commit được đối chiếu sau khi tạo SHA; không dùng kết quả dirty tree thay bằng chứng commit.

---

# Baseline tái lập và nâng cấp MySQL lịch sử — 13/11/2026

Tiếp theo A–D, baseline **355 test / 2.311 assertions**, RuboCop **554 file / 0 lỗi**, **10 file Payroll strict**. HEAD giữ `9b9c014facc2f4c2cbcf423d7d7685eef429f408` nhưng **source chưa commit/push**. Snapshot 948 file ứng dụng/config/schema/RBI/CLI/test/receiver/build có SHA256 `8db982ba24d68f339bbcce6a31e65eb0e6062c92983181d2b00d73b17f87ac7a`. [Manifest và kết quả](evidence/2026-11-13-reproducible-baseline.json) ghi hash từng file, gồm source mới chưa tracked; docs/evidence thêm sau build không thuộc manifest. Giữ mọi diff cũ, không sửa Laravel hoặc DB development.

| Gate | Kết quả lần này |
|---|---|
| Ruby/Bundler | `.ruby-version`3.3.6 → **3.4.12**; Docker base ruby:3.4.12-slim, cài Bundler2.6.9 rõ ràng; CI ruby/setup-ruby3.4.12 + Bundler2.6.9. Gemfile~>3.4.0 và lock ruby3.4.12p148/Bundler2.6.9 giữ nguyên. Runtime thực Ruby3.4.12 +PRISM aarch64-linux /Bundler2.6.9; bundle check pass. |
| Full source | **355 runs / 2311 assertions / 0 failures/errors/skips**, seed51915,76.512139s. |
| Full clean image | **355 / 2311 / 0 failures/errors/skips**, seed51915,72.578318s; không source mount. |
| bin/quality | RuboCop **554 file / 0 offenses**; routes 13; architecture48 controllers / 12 Engines / 38 bindings; Sorbet pass; RBI gem inventory/DSL drift/shim duplicate pass; Zeitwerk pass. |
| Scanners/probes | Brakeman0 errors / 0 warnings; bundler-audit refreshed 1359 advisories, 0 known vulnerabilities, advisory commit4d71b123428e33f694e805ce15351ee3d8d62ef7. Gitleaks 0 findings; synthetic-token rejection/redaction pass. Negative type probe rejects String for PayRun contract with 7002, removes probe. actionlint1.7.7 pass. Python receiver 8 tests pass. |
| Fresh MySQL |75 FK / 19 CHECK / 34 PK / 45 unique / 232 index-column entries / 17 versions / 2 triggers; exact definition comparison pass; temporary schema dropped. Definition hash e8767887ae49a19c8aa8bcbaa98e0bfe55b0fb277613c2456e95e6ad1dc399cd. |
| Image | `sha256:5f358807ea15b7220f4f12877b7037886dda1d7c321ecceba1420f4b43b91bd9`; canonical Dockerfile, UID 1000; /up 200, /session/new 200, /pay_runs 302. Có structure.sql, không schema.rb/.env/master.key/credentials*.key.948 file SHA256 khớp source, 0 mismatch; chỉ public CA mount. ENV runtime vẫn có secrets local theo Compose. |

Nguồn upgrade: `git show 9b9c014facc2f4c2cbcf423d7d7685eef429f408:db/schema.rb`, version**20261028000002**, fileSHA256 `0e8eaacf9f40c586d58cee2fa1dc9fa5c12454563eeff0b11c77f7370b853847`. Chọn schema committed mới nhất có nguồn xác định trước các phần ERP đang sửa; cả ba migration tương ứng tồn tại cùng commit. Không suy ngược schema mới hoặc nhập business-data dump.

- MySQL**8.4.13** dùng một lần, container/volume ngẫu nhiên, network none, kết nối Unix socket; secrets sinh mới, mode 0600, không đọc .env thật. `hrm_test` chứa hai công ty mẫu; `hrm_fresh` chỉ đối chiếu cấu trúc. Root chỉ trong tiến trình fixture/DDL riêng; không đổi app grants/TLS/CA. Container/volume dọn trong finally, đã xác nhận không còn.
- Trước:3 migration, 35 FK / 1 CHECK / 18 PK / 18 unique, 98 index-column entries. Sau:17 migration tới**20261112000009**,75 FK / 19 CHECK / 34 PK / 45 unique, 232 index-column entries, 2 triggers.304 columns/defaults, named indexes, key-column references, CHECK, trigger timing/event/body và versions khớp freshSQL. Chuẩn hóa riêng whitespace ngoài SQL quoted literals/identifiers vì migration squish nhưng dump có xuống dòng.223 KEY_COLUMN_USAGE rows không phải 223 FK.
- Mọi cột cũ company/user/API token/employee/payrun/payslip giữ nguyên ngay sau upgrade; hai token backfill principal đúng user gốc. Hai phiếu finalized cũ đọc qua ListPayslips,20/30 triệu VND; identity/reconciliation snapshot lịch sử không bịa/backfill. CSV mới cho phiếu cũ thiếu identity bị từ chối đúng InvalidSource.
- Dùng grants thật do migration cấp, cả hai company tạo kỳ mới → sửa live name/salary sau draft → chốt → tải CSV 182 bytes qua Command; snapshot vẫn20/30 triệu VND. Payslip chéo company bị từ chối. Ghi SQL cố tình sai bị CHECK 3819 / composite FK 1452 / trigger 1644 / unique 1062 chặn đúng. Không thêm migration hoặc sửa nghiệp vụ.
- Rehearsal dùng dữ liệu giả, không chứng nhận mọi dataset hoặc backup/restore production. MySQL image có sẵn là amd64 emulation trên host arm64; Ruby image arm64. [Evidence và toàn bộ harness](evidence/2026-11-13-mysql-upgrade-rehearsal.json).

Lệnh đã chạy từ repo:

```sh
docker compose build web
docker run --rm xinviec-hrm-web:latest sh -c 'ruby -v && bundle --version && bundle check'
docker run --rm --env-file .env --network xinviec-hrm_default \
  --mount type=bind,src=/Users/lahoathanh/Desktop/xinviec/ruby/tmp/mysql-schema-client/ca.pem,dst=/run/mysql-ca.pem,readonly \
  -e DATABASE_SSL_CA=/run/mysql-ca.pem -e RAILS_ENV=test \
  xinviec-hrm-web:latest sh -c 'ruby bin/quality && bundle exec rails test --seed 51915'
docker compose exec -T -e RAILS_ENV=test web sh -c 'ruby -v && bundle --version && bundle check && bundle exec rails test --seed 51915'
docker run --rm xinviec-hrm-web:latest ruby bin/typecheck --self-test
docker run --rm xinviec-hrm-web:latest ruby bin/check-secrets --self-test
docker run --rm -v "$PWD/.github/workflows:/work:ro" rhysd/actionlint:1.7.7 -color /work/ci.yml
docker compose run --rm --no-deps event_sink python test_server.py
RAILS_ENV=test /usr/bin/ruby bin/verify-test-schema
/usr/bin/ruby bin/smoke-image
python3 /private/tmp/hrm-run-upgrade.py
python3 /private/tmp/hrm_compare_rebaseline_image.py
```

Tái tạo harness từ JSON đã lưu (không chứa credential, sinh mới khi chạy):

```sh
python3 - <<'PY'
import json
from pathlib import Path
proof=json.loads(Path('docs/evidence/2026-11-13-mysql-upgrade-rehearsal.json').read_text())
Path('/private/tmp/hrm-upgrade-rehearsal.rb').write_text(proof['reproduction']['rails_runner'])
Path('/private/tmp/hrm-run-upgrade.py').write_text(proof['reproduction']['host_python'])
PY
python3 /private/tmp/hrm-run-upgrade.py
```

Host rbenv chưa cài 3.4.12: lệnh ruby bin/smoke-image ban đầu dừng ở rbenv trước khi chạy app; dùng /usr/bin/ruby chỉ điều phối Docker. Mọi Ruby gate ứng dụng chạy 3.4.12 trong container. Harness ban đầu sửa readiness server khởi tạo, automatic schema versions và fixture columns/grants; không đổi policy hay bỏ assertion. Phạm vi strict vẫn 10 file Payroll; IAM/Leave typing để đợt sau. Không tạo ảnh mới/khôi phục ảnh đã xóa.

CI local tái lập lint/types/routes/architecture/actionlint, tests MySQL/RBI/security/autoload, receiver, freshSQL và imageSmoke. Không bootstrap/seed/down toàn stack hiện tại; không giả lập GitHub checkout/setup/cache/upload trên hostedrunner. Git diff Gemfile.lock soHEAD vẫn chứa diff đã có trước; checksum lockfile đầu/cuối đợt này không đổi, không xóa diff để làm gate giả xanh.

Remote: REST GET Actions đúng HEAD thấy [origin run42943473135](https://github.com/Thanhlong282828/ruby-projec-one/actions/runs/42943473135), eventpush, completed/**failure**. Workflow cũ chỉ có job verify, lỗi **Provision isolated test database**; Test and autoload skipped. Workflow 2 jobs/source mới đang dirty nên **remote CI snapshot này còn chờ**, không lấy run cũ làm bằng chứng pass. Omega lookup404 qua kết nối hiện tại; không kết luận repo bị xóa hoặc CI pass. Không rerun/commit/push.

Review riêng đợt này: `.ruby-version`, `Dockerfile`, `.github/workflows/ci.yml`, `docs/QUALITY.md`, `docs/VERIFICATION.md`, hai JSON mới. Danh sách toàn bộ tracked diff/untracked đang có nằm trong JSONbaseline; cần review và đưa đủ source/structure.sql/Sorbet/RBI/tests/tooling vào commit sau này, không .env/privatekeys/backups. Web container dài hạn cho VSCode và worker không bị recreate.

Quét source cuối sau khi thêm evidence: **1024 publishable files, 0 findings**, synthetic-token rejection/redaction đạt. Manifest ban đầu đặt path chứa token/key cùng dòng checksum nên generic-api-key báo nhầm; đã tách trường path/sha256, không thêm ignore/allowlist. Harness lưu trong JSON đã chạy lại bằng đúng application/MySQL image ID bất biến và đạt cùng kết quả.

---

# Sorbet / kiến trúc / MySQL / security / image — 13/11/2026

Kết quả **local trên source chưa commit** và image canonical; không phải GitHub Actions của commit mới. HEAD nền: `9b9c014facc2f4c2cbcf423d7d7685eef429f408`. Giữ diff đang làm, không commit/push, không chỉnh Laravel hoặc DB development.

| Đợt | Thay đổi và bằng chứng |
|---|---|
| A | Gemfile/lock + Payroll gemspec, Sorbet config/RBI, 10 file strict trong Payroll, 18 policy Scope ghi rõ ApplicationPolicy::Scope, bin/typecheck/check-rbi/quality và CI. Baseline đúng342/2143, RuboCop539/0. Sorbet0.6.13672 + Tapioca0.20.0; 106 gem RBI,142 DSL,15 annotations,1 shim Bundler thật; không todo stubs. Gate chặn String thay PayRun qua contract (7002), xóa probe rồi pass. Cả contract, implementation, snapshot shape và gọi thật đều kiểm; cast động có chú thích. |
| B | config/engine_boundaries.yml, check-architecture, negative gate tests và EngineBindingsTest:12 Engines/38 bindings/48 controller files. Schema tạm nạp structure.sql, đối chiếu chính xác metadata với hrm_test:75 FK,19 CHECK,34 PK,45 unique,232 index-column entries,17 migration versions,2 membership triggers. Schema tạm đã xóa. Thêm audit rollback và nil projection tests; giữ race leave/payroll hiện có. Không thêm migration; historical upgrade chưa được kiểm độc lập do không có image/baseline lịch sử phù hợp. |
| C | Sửa lỗi tái hiện: query cache giữ quyền đọc nguồn đối soát đã thu hồi. Read repository đọc/authorize uncached. Test CSV thu hồi quyền khi chờ khóa vẫn chặn đúng. Gitleaks pinned, quét source có cả untracked với giá trị redacted; negative synthetic-token probe pass. Private config bị force-add phải bị chặn theo tên trước khi đọc (test env giả chmod000:7 assertions). Probe secret dùng chính config repo và verbose để xác nhận REDACTED. Một ngoại lệ path+exact public URI doc, env example không dùng chuỗi giống key; bootstrap sinh key ngẫu nhiên0600 và giữ env cũ. API/webhook/worker/Cable/idempotency/outbox hiện có được kiểm bởi full suite; receiver8 tests pass. Browser A/B hoàn tất công/phép/đối soát/chốt:2 phiếu mỗi company,40/60 triệu VND; B không mở được kỳ A. A tải CSV; 390px không tràn ngang document, table scroll trong panel; Tab/Enter và outline quan sát được. Hai company QA và Puma test đã dọn. |
| D | Source **355 tests/2311 assertions/0 failures/errors/skips**, image cùng kết quả, seed51915. RuboCop554/0, typecheck + negative probe, RBI inventory/DSL/shim, routes13, architecture, Zeitwerk, Brakeman0 errors/warnings, audit0 known vulnerabilities (1359 advisories), Gitleaks0 findings, actionlint1.7.7 pass. Canonical image `sha256:9fe48b167ddf1a088f7cbf8c6750bdb6abdccac0c4ef109d914a207fbcf3a432` chạy uid1000, không mount source, chỉ public CA; /up200,/session/new200,/pay_runs302; có SQL schema, không chứa file db/schema.rb, .env hoặc private key. SHA256 **926 application/config/RBI/schema/CLI files khớp source,0 mismatch**; docs/evidence bổ sung sau build không thuộc manifest ứng dụng. |

Strict scope chính xác và lệnh tái lập: [QUALITY.md](QUALITY.md). Chi tiết máy đọc: [evidence/2026-11-13-types-security-verification.json](evidence/2026-11-13-types-security-verification.json).

Query count uncached ở1/20 nhân viên: list9/9, đối soát20/20, tạo CSV49/49. Gate tăng tối đa1 query và ceiling11/22/52; không phải benchmark latency/load production. Giữ ca mở/đơn chờ là cảnh báo; không đổi công thức OT/thuế/khấu trừ. Snapshot và sealed CSV giữ policy/transaction hiện tại. Full run phát hiện lỗi type alias cold-autoload do triển khai mới; đã tách Snapshot đúng file Zeitwerk, thêm cold-boot test và chạy lại seed lỗi thành công. Rà soát loại toàn bộ todo RBI tự động, nạp đúng optional API và chỉ giữ shim namespace vendored có chứng minh runtime.

Giới hạn: chỉ10 file strict, framework động vẫn có untyped trong generated RBI; không tuyên bố full-project typing/production pentest/cloud. `.ruby-version` đang có sửa dở3.3.6 được giữ; Docker/Gemfile/lock/CI đã kiểm bằng3.4.12. Không nhập backup business-data để bịa baseline upgrade; không có kết quả remote CI của source chưa commit.

---

# Chấm công / phép / đối soát / chốt lương hai công ty — 12/11/2026

- Build canonical bằng `docker compose build web worker`, source hiện tại. Image không có db/schema.rb, có db/structure.sql, không .env/master.key; chạy hrm. SHA256 của 14 file code/schema/lockfile khớp source. Image ID và manifest trong evidence/2026-11-12-payroll-reconciliation-two-companies.json.
- Smoke HTTP Puma container tạm không mount source: /up 200, /session/new 200, /pay_runs chưa đăng nhập 302. Chỉ dùng hrm_test, không tạo dữ liệu mẫu development.
- Tái hiện trước sửa: 3 regression Payroll thất bại vì code nhân viên lấy từ live profile, sửa số tiền sau chốt qua model được, và ListPayslips tin company_id trên object truyền vào. Race ReviewLeave trong outer REPEATABLE READ transaction cũng tái hiện vượt số dư.
- Sửa: capture tên/mã nhân viên cùng lương dưới source locks; normal update/destroy payslip bị chặn, finalized PayRun không sửa được; CSV dùng captured code. Read repository nhận actor và tìm lại persisted tenant-scoped run; finalize kiểm lại quyền sau run lock. Audit đúng actor kể cả gọi Command ngoài HTTP.
- Duyệt phép giữ employee -> request lock, gắn đúng Employee vừa khóa, dùng current-read approved rows cho tính số dư; read-only report/prewarm không tự khóa. Hai connection + query cache kiểm concurrent approval và snapshot cũ.
- Thêm Query đối soát vào trang kỳ lương. Counts/totals được lưu ở thời điểm chốt trong cùng transaction với status/audit/outbox; rollback nếu outbox lỗi. Counts nguồn chỉ hiện khi có attendance.read_all + leave.read_all; payroll.read vẫn là quyền xem bảng lương toàn company.
- Samples A/B: mỗi công ty 1 attendance đã checkout, phép đã duyệt lần lượt 1/2 ngày, lương snapshot 20/30 triệu VND. Sau tạo kỳ đổi hồ sơ/lương, chốt và CSV vẫn đúng dữ liệu lúc tạo. Kiểm HTTP/API chéo công ty và thu hồi quyền trên cùng session. Duplicate close chỉ 1 audit; revoked finalizer khi chờ khóa không chốt.
- **Full source: 342 tests / 2143 assertions / 0 failures/errors/skips. Full canonical native image: cùng 342 / 2143, đạt.** RuboCop 539 files/0 offenses; route13, architecture48, Zeitwerk đạt; Brakeman0 errors/warnings; dependency audit cập nhật không known vulnerability. Scoped whitespace đạt.
- Migration 20261112000009 thêm nullable employee_code_snapshot/employee_name_snapshot và reconciliation JSON. Development có 0 kỳ/phiếu trước migration; backup riêng0600; không backfill lịch sử, không reset/seed, không sửa Laravel. Structure SQL giữ membership guards.
- Giữ chính sách đóng kỳ hiện tại: ca mở/đơn chờ là cảnh báo được lưu, không tự cấm chốt. Không tự tính khấu trừ công/phép, OT hoặc thuế. Model/API immutability không tuyên bố chặn privileged raw SQL; test artifact độc lập vẫn chống corruption. Phiếu lịch sử thiếu identity không được bịa snapshot mới; artifact cũ vẫn tải được.
- Một vòng full test ban đầu bị fixture của harness race lỗi cleanup để lại outbox, làm mock dispatcher fail. Đã dọn đúng company fixture đó trên hrm_test, sửa scope biến cleanup; không sửa assertion hay dispatcher để giấu lỗi. Các full runs cuối đều xanh.

# Ruby / Rails quality gates — kiểm chứng 12/11/2026

- GitHub Actions tách hai job push/PR: lint-format/architecture và MySQL tests/autoload/security; read-only contents, timeout, concurrency cancellation, JSON artifact 7 ngày. Không tự sửa code, không continue-on-error; chưa push/chạy remote hoặc cấu hình branch protection.
- RuboCop 1.92.2 + Rails 2.38.0 + Performance 1.27.0 + Omakase 1.1.0, lockfile cố định. Bật thực sự Lint/Security/Rails/Performance, preset format; gồm mọi engine/test/migration/gemspec và 12 Ruby CLI extensionless. **532 files / 0 offenses**. Không todo baseline/module exclusion. 27 SQL-bypass statements trong test có ngoại lệ cục bộ giải thích vì kiểm DB guards/corrupt rows; không tắt security rule production.
- Sửa theo từng nhóm sau đồng ý người dùng: định dạng/comment whitespace, explicit super, query APIs, inverse associations, static message I18n giữ nguyên text, immutable lookup reuse, params.expect kiểm hình dạng root. Regression malformed scalar/array form roots đạt 1 test / 10 assertions, không ghi dữ liệu.
- Full native image cuối không mount source: **332 tests / 2035 assertions / 0 failures/errors/skips**. RootPathname refactor từng gây lỗi test vì Pathname#split khác String#split; đã sửa to_s rõ ràng, giữ test. Schema SQL canonical; image sạch không giữ schema.rb cũ từ base layer.
- Native bin/quality đạt: 13 route files, 48 controller/concern files, Zeitwerk. Brakeman 47 controllers/34 models/67 templates: 0 errors/warnings. Dependency audit cập nhật 1359 advisories, commit 4d71b123428e33f694e805ce15351ee3d8d62ef7: không known vulnerability. actionlint 1.7.7 đạt.
- Image non-root hrm; giữ web container cho VS Code, cập nhật worker. Không reset/migrate development, không đổi credential/CA hoặc sửa Laravel. Scanners không thay pentest. Chưa có full-project static typing tương đương PHPStan10; xem QUALITY.md và evidence/2026-11-12-ruby-quality-gates.json.

# Phiên đăng nhập cá nhân — kiểm chứng 12/11/2026

- Web GET /my/sessions và DELETE /my/sessions/:id khai báo riêng. Link Bảo mật trên thanh tài khoản, thẻ responsive gồm company/created/expiry/current. Không IP/User-Agent, không API token management.
- Personal ownership theo principal identity, không quyền admin công ty. Query/Command qua read/write contracts hiện có; 38 bindings giữ nguyên. Repository chiếu metadata không digest/raw token, bound25+1 keyset, validate cursor/ID.
- Thu hồi khóa principal -> profile -> caller session -> scoped target, kiểm caller active/expiry/ownership/context mới sau chờ khóa; current session phải logout thông thường. Audit cùng transaction; không phát realtime/outbox private-session metadata.
- Full hrm_test cuối cùng **331 runs / 2025 assertions / 0 failures/errors/skips**. Focused security+races **8 runs / 64 assertions**; gồm foreign IDOR/admin, same identity different company, stale context, expired caller, CSRF thật, audit rollback, keyset và race caller revoked khi chờ MySQL lock với query cache bật.
- Route 13 files; architecture 48 controllers/concerns; Zeitwerk đạt. Brakeman 0 errors/warnings; dependency audit cập nhật không có known vulnerability. Browser chỉ đọc phiên admin local hiện tại, không thu hồi phiên development thật. Native image không rebuild ở increment này.
- Không migration, không thay password/CA/database Laravel. Thu hồi chặn auth tiếp theo và Cable trước transmit; không hủy request đang xử lý hoặc đóng socket tức thì. Bằng chứng evidence/2026-11-12-personal-sessions.json; hướng dẫn ../HUONG_DAN_PHIEN_DANG_NHAP_LARAVEL_RUBY.txt.

# Danh mục chi nhánh — kiểm chứng 12/11/2026

- Thêm tìm mã/tên (literal LIKE escape), lọc hiệu lực và keyset pagination 25 dòng cho web/API. KPI tổng công ty và số khớp bộ lọc tách rõ; giữ bộ lọc ở link tiếp, có trang đầu/xóa bộ lọc.
- Query/contract/repository CQRS; policy và company scope giữ ở cả Query/repository. Domain validator giới hạn q/status/cursor, sai trả 422; không nhận company_id từ client.
- Organization suite **32 tests / 176 assertions, 0 failures/errors/skips**. Focused directory/branches **4 tests / 57 assertions**: hơn 100 dòng, không lặp ID, literal wildcard/SQL text, cross-company, denied/anonymous, malformed input và inclusive dates.
- Architecture 47 controller/concern files, route 13 files, Zeitwerk đạt; Brakeman 0 errors/warnings; dependency audit cập nhật không có known vulnerability. Full suite không chạy lại cho increment giới hạn Organization này.
- Browser kiểm search submit/clear và empty state; không thêm dữ liệu development. Cursor không phải snapshot; parent selector vẫn cap100; chưa branch ABAC toàn ERP. Xem evidence/2026-11-12-branch-directory.json và TXT so sánh nhiều công ty.

# Nhiều công ty và chi nhánh — kiểm chứng 12/11/2026

- Migration development hoàn tất sau backup riêng. Ruby MySQL cổng 13306 độc lập Laravel MySQL cổng 3306; không sửa database/cấu hình/chứng chỉ Laravel.
- Registry quản trị tổng, SystemGrant MySQL riêng, identity đăng nhập và membership không chứa mật khẩu với role riêng từng công ty. Chuyển context chỉ cập nhật credential hiện tại, không đổi company_id của tài khoản. Branch dùng OrganizationUnit thật.
- Hai trigger MySQL chặn self/chain membership và thay đổi quan hệ identity/company; FK, unique, CHECK giữ nguyên. SQL schema lưu trigger, test từ chối chạy khi thiếu guard. Root chỉ dùng trong bước migration/schema local; không cấp SUPER cho app.
- TLS giữ CA gốc, sửa SAN đúng hostname, verify_identity và test CA lạ bị từ chối. Private keys chỉ nằm trong volume MySQL; bản sao public CA phục vụ client.
- Full suite và native image không mount source đều đạt **322 tests / 1924 assertions / 0 failures/errors/skips**. Gates: 13 route files, 47 controller/concern files, Zeitwerk đạt. Brakeman 46 controllers/34 models/66 templates, 0 errors/warnings. Dependency audit cập nhật 1359 advisories, không có known vulnerability.
- Web hot restart đúng container, worker restart, health 200. Browser đăng nhập local đã kiểm tra directory, detail, membership selector và empty branch screen; không tạo dữ liệu nghiệp vụ thật. Thao tác tạo/switch nhiều công ty kiểm bằng automated web/API và concurrency tests.
- Hiện database có 1 công ty, 0 chi nhánh; admin local được cấp quyền quản trị tổng, không đổi mật khẩu. 38 bindings và 76 permissions.
- Giới hạn: quyền hiện tại theo công ty, chưa ABAC theo từng chi nhánh trên toàn ERP. Các tab dùng cùng session chia sẻ context. Chưa triển khai cloud production hoặc chứng nhận pentest. Bằng chứng: evidence/2026-11-12-multi-company-branches.json. Hướng dẫn: ../HUONG_DAN_NHIEU_CONG_TY_CHI_NHANH_LARAVEL_RUBY.txt.

# Payroll → Integration descriptor bridge — kiểm chứng 12/11/2026

- Đã nối snapshot thật bằng GET/POST web/API `/integration/payroll-exports/:id`, nút từ PayrollExport và link ngược từ Delivery. Chỉ thông báo payroll.export.ready với UUID/period/format/version/MIME/size/checksum; không upload CSV/amounts/employee rows/download URL. Không claim DJI accounting/provider/government parity.
- Module + MVC + CQRS, thêm Payroll source contract và Integration bridge contract, tổng 36 bindings; 4 explicit routes. Payroll sở hữu verify artifact; Integration sở hữu deterministic source/connection/target intent và durable delivery. Generic typed roots/key namespace vẫn đóng.
- Migration 20261112000007 sau private backup 0600: nullable source ID giữ generic rows, same-company composite FK/index, immutable source ở model. MySQL thêm payroll.exports.notify, tổng 74 permissions; provision admin defaults, runtime grants/deny không bypass. No-store/CSRF/Bearer/input allowlist giữ nguyên.
- Worker/replay kiểm source grants, artifact toàn vẹn và exact server descriptor/digest. Khóa delivery → connection → source trước consistent grant reads dưới MySQL REPEATABLE READ; kiểm quyền dưới khóa uncached. Thu quyền/chặn source không có network attempt. Original requester/event/body giữ qua retry. Audit/outbox nguyên tử; receiver vẫn phải dedupe Event ID khi remote HTTP/local commit lệch nhau.
- Metadata/attempt/audit/realtime lọc quyền đọc nguồn. Realtime guard đăng ký class name tin cậy; resolve đúng same-company/type OutboxEvent ID (không nhầm Delivery ID), rồi current source scope. Generic Integration row vẫn xem được khi mất payroll grants. Portal bỏ deleted delivery history cho người thiếu source grants vì không xác minh được nguồn; global audit.read vẫn là grant rộng riêng.
- **Full hrm_test: 302 runs / 1777 assertions, 0 failures/errors/skips**. **Native image không mount source: 90 runs / 769 assertions**, đạt. Có source FK/IDOR, quyền notify khác download, source/body corruption, API/CSRF/no payload leak, duplicate/destination idempotency, outbox rollback, source-aware audit/realtime. Race thực hai kết nối MySQL: duplicate enqueue, revoke khi chờ connection/source lock, cache-enabled enqueue revoke.
- Native gates đạt: 13 route files, 41 controller/concern files, zeitwerk. Brakeman 40 controllers/32 models/62 templates, 0 errors/warnings; bundler-audit --update 1359 advisories, commit 4d71b123428e33f694e805ce15351ee3d8d62ef7, không có known vulnerability. Scoped whitespace đạt. Scanner không thay pentest.
- Local gem dependency Integration → Payroll khai báo rõ, lock --local không nâng external gem. Image non-root/bundle check đạt, không .env/master.key. Nạp đúng web container dài hạn giữ VS Code; worker restart, /up 200. Runtime 36 bindings/74 permissions; dev 7 users, 0 PayRun/PayrollExport/Delivery/Attempt. Không gọi provider thật hoặc tạo business samples.
- Browser đăng nhập admin local theo chấp thuận trước, Dashboard/menu và empty payroll exports hiện đúng. Không có nguồn lương ở dev nên form bridge kiểm bằng HTTP tests trên hrm_test; chưa submit nghiệp vụ trong browser, chưa kiểm mobile. Không gán ảnh trang cũ làm bằng chứng form bridge.
- TXT mới `../HUONG_DAN_BRIDGE_BANG_LUONG_LARAVEL_RUBY.txt`: tóm tắt, ba bảng ngang, file flow và Security/Cloud giới hạn. Các dòng đang ghi thiếu bridge trong hướng dẫn/README/roadmap đã cập nhật; checkpoint cũ giữ lịch sử. ENV audit names-only 140/293 Laravel, 19/27 Ruby, không thêm biến runtime/secret.
- Cloud production/IAM/secret manager/TLS ingress/private DB/Redis/backup restore drill là yêu cầu triển khai được ghi rõ, chưa provision hoặc kiểm chứng hạ tầng cloud thực. Còn artifact transport, accounting/provider/statutory formats, receipt reconciliation, retention/legal hold/amendment. Không push GitHub.
- Evidence: `evidence/2026-11-12-payroll-integration-bridge.json`. Các phần dưới là checkpoint lịch sử.

---

# Outbound integrity gate — kiểm chứng 12/11/2026

- Bổ sung Domain OutboundEnvelope dùng chung cho generic enqueue/replay/worker: bytes <=64KiB, UTF-8, JSON/schema/depth, reserved roots payroll/erp/government. Worker và replay so SHA256 nội dung đã giải mã trước ký/gửi; không parse rồi generate lại JSON.
- Payload/ciphertext hỏng -> blocked trước HTTP, không tăng network attempt; trạng thái + audit/outbox commit cùng nhau, outbox lỗi rollback. Rails tự thêm encrypted-column length validator gây decrypt trên status-only update; private quarantine chỉ cho đúng status mutation trên row đã khóa, save(validate:false) hẹp, giữ optimistic lock/DB CHECK/callback. Validation thông thường giữ nguyên. Metadata JSON không decrypt rồi mới except payload.
- Suite riêng **23 runs / 182 assertions**; toàn hrm_test **287 runs / 1671 assertions**; native image không mount source **25 runs / 194 assertions**. Đều 0 failures/errors/skips. Có reserved event API, ciphertext corruption, changed JSON/digest, schema/size/UTF-8, replay denial, metadata recovery, outbox rollback và race MySQL permission/idempotency.
- Gates đạt: 13 route files, 39 controller/concern files, zeitwerk; Brakeman 38 controllers/32 models/61 templates, 0 errors/warnings. bundler-audit --update: 1359 advisories, commit 4d71b123428e33f694e805ce15351ee3d8d62ef7, không có known vulnerability. Scoped whitespace đạt.
- Không migration/ENV/dependency mới. Image non-root trên dependency image hiện hữu, bundle check đạt. Hot reload đúng container web giữ VS Code, restart worker, health 200. Runtime nạp reserved roots đúng; dev vẫn 7 users, 0 PayRun/PayrollExport/Delivery/Attempt. Không submit business sample, không gọi provider thật, không push GitHub.
- TXT mới `../HUONG_DAN_BAO_VE_OUTBOUND_LARAVEL_RUBY.txt`: tóm tắt, 3 bảng ngang, file flow và khái niệm Laravel/Ruby. AGENTS và các hướng dẫn/roadmap/inventory đã cập nhật. Không thay UI nên không ghi browser screenshot/mobile PASS cho lượt này.
- **Chưa triển khai source-bound PayrollExport bridge.** Đây là tiền đề bảo vệ, chưa phải gửi CSV/provider/accounting/government parity. Reserved namespace không thay thế source FK/grants/worker checks trong bridge tương lai. SHA256 không chống người có quyền sửa cả body lẫn digest; blocked hiện chưa có reason code riêng.
- Evidence: `evidence/2026-11-12-outbound-integrity.json`. Các checkpoint dưới giữ lịch sử.

---

# Payroll reconciliation CSV — kiểm chứng 12/11/2026

- Đối chiếu DJI ErpExportService/EnterpriseDomainIntegrationBridge: DJI cần immutable artifact từ posted journal/mapping/approval rồi mới transport. Ruby hiện chưa có accounting foundation đó; đợt này hoàn thiện artifact đối soát từ PayRun đã chốt, không claim ERP accounting parity hoặc tự gửi provider.
- Payroll Engine giữ Module + MVC + CQRS: 2 contracts mới (tổng 34), 8 route web/API riêng; Query chỉ metadata, DownloadExport là Command vì ghi access log. Controller/view không query DB. Menu/Board chung nhóm Thời gian & tiền lương, cần đủ payroll.read + payroll.exports.read; matcher :all không đổi các entry OR cũ.
- MySQL payroll_exports/payroll_export_accesses: private backup trước migration, unique company/pay-run/UUID, composite tenant FKs và CHECK format/version/rows/size/results. Thêm 3 quyền DB, tổng 73, chỉ provision admin defaults; runtime đọc grant/deny MySQL. Dev giữ 7 user, 0 PayRun/export/access mẫu, không reset hoặc copy dữ liệu Laravel.
- Lock source PayRun/slips/employee identifiers, chỉ finalized + finalized_at, 1..2000 dòng, <=1MiB plaintext, tiền nguyên không âm và net=gross-deductions. Mã NV UTF-8 <=100 byte trước escape, không NUL. CSV BOM/CRLF đúng quoting, apostrophe chống các formula/control prefixes. Không xuất full_name/email/bank/national ID. CSV VND scale0 bảo toàn integer theo UI hiện tại, không tự chia 100 vì tên cột legacy *_cents.
- Artifact mã hóa MEDIUMTEXT, model readonly; một snapshot v1/kỳ, request lặp trả cùng record. API 201 mới/200 có sẵn bằng previously_new_record?. Metadata select/serialization không có artifact. Tải riêng download grant, no-store/nosniff/attachment và API Bearer không cookie fallback. Verify SHA256/size/header/UUID/period/count/currency/amount relation trước trả bytes. Lịch sử access/Audit/Outbox commit trước trả; integrity failure vẫn lưu evidence rồi 409, outbox lỗi không trả file. Access allowed không khẳng định browser đã lưu xong.
- Realtime prefix PayrollExport/Access yêu cầu cả payroll.read và payroll.exports.read ngoài realtime.read; nonempty arrays conjunctive, malformed config fail closed, thu quyền tác động subscription/token hiện hữu. Privacy metadata/audit/outbox/Redis giữ nguyên, không broadcast CSV.
- Payroll/realtime suite: **20 runs / 191 assertions** đạt. Toàn hrm_test: **282 runs / 1599 assertions, 0 failures/errors/skips**. Native image không mount source: **28 runs / 379 assertions**, đạt. Có race hai kết nối MySQL -> một artifact/outbox; IDOR/company/FK, separate grants/revocation, corruption/ciphertext/identity checks, rollback, actual CSRF, header/privacy, malformed filters, binary UTF-8, formula injection, immutable snapshot và precise HTTP idempotency.
- Native routes/architecture/zeitwerk đạt: 13 route files, 39 controller/concern files. Brakeman 38 controllers/32 models/61 templates, 0 errors/warnings. Dependency audit --update: 1359 advisories, commit `4d71b123428e33f694e805ce15351ee3d8d62ef7`, không có vulnerability đã biết. Không coi scanner là pentest.
- CSV 3.3.2 đã cài từ Organization, nay Payroll khai báo direct dependency; bundle lock --local cập nhật path metadata, không nâng external gem. Đóng gói source trên dependency image hiện có, bundle check đạt; native uid1000, artifact encrypted, không .env/master.key. Hot restart đúng web container giữ VS Code, worker nạp provider, /up 200.
- Browser local admin được user cho phép: page/menu/month GET filter/reset đúng, viewport/page width 1280px, console 0 errors. Không submit tạo/chốt/tải business data trong development. Screenshot private temp; mobile chưa kiểm.
- Hướng dẫn: `../HUONG_DAN_XUAT_BANG_LUONG_LARAVEL_RUBY.txt`, tóm tắt rồi 3 bảng ngang và giải thích source/units/interface/transaction/download/CSV formula/realtime. ENV audit vẫn names-only, 140/293/301 Laravel và 19/27 Ruby, không biến runtime mới. Roadmap/inventory vẫn partial.
- Còn accounting journal/mapping/maker-checker, source-bound outbound bridge với worker source permission, government provider/formats, amendment/reversal/v2, historical employee code at finalization, retention/legal hold/quota tuning. SQL đặc quyền vẫn bypass readonly; checksum không phải tamper-proof ledger. Không gọi provider thật, không push GitHub.
- Evidence: `evidence/2026-11-12-payroll-exports.json`. Các phần dưới là checkpoint lịch sử.

---

# Integration operational audit — kiểm chứng 12/11/2026

- Đối chiếu DJI thật: `IntegrationController#audit` gọi repository map audit tới delivery attempts, còn service histories lưu from/to riêng. Ruby thêm portal `/integration/audit` và Bearer API tương ứng bằng cách đọc AuditLog hiện có, bổ sung safe attempt outcome/HTTP và source link; không giả lập from/to chưa lưu.
- Module + MVC + CQRS: Query/Request/Filters/Policy/repository riêng, 1 contract mới (tổng 32, Integration có 7), 2 GET route riêng (Integration tổng 30). Không có mutation endpoint cho audit. Scope company + 4 Integration record types, Query và repository cùng authorize; không query/persist trong controller/view. Nav Nhận/Gửi/Nhật ký cùng menu Integration, tab hiện tại có aria-current.
- MySQL permission `integration.audit.read` + `integration.read`, độc lập với grant audit tổng `audit.read`; tổng 70 quyền, Integration 8. Chỉ provision admin role, runtime không bypass. Migration index `(company_id,record_type,created_at,id)` có private backup trước áp dụng. Development giữ 7 user, 0 connection/inbound/outbound/attempt/audit Integration; không seed dữ liệu giả hoặc gửi provider.
- Projection explicit: chỉ ID/action/type/actor ID/time/tên cột đổi/source URL/attempt fields an toàn. Arbitrary metadata, secret/payload/response body/email không trả ra. Nguồn lookup theo batch scoped, chỉ pluck ID/select safe attempt columns; nguồn đã xóa giữ log và không tạo link hỏng. Plain HTML escape và no-store giữ nguyên.
- Filter 30 ngày mặc định, <=93 ngày, biên ngày theo Time.zone (hiện Asia/Ho_Chi_Minh), resource/record/operation/before validate cả kiểu và BIGINT bounds. Dùng `operation` tránh đụng params[:action] của Rails routing. Cursor ID 25+1 không lặp khi insert log mới. 3 KPI cùng ngày/loại/ID, bấm đổi operation và giữ filter; không cache quyền hoặc projection.
- Riêng feature: **13 runs / 107 assertions** đạt. Toàn bộ hrm_test: **264 runs / 1402 assertions, 0 failures/errors/skips**. Native image không mount source: **68 runs / 575 assertions**, đạt, gồm Integration/concurrency/container/realtime. Kiểm permission revocation trên token cũ, global-vs-module grants, unauthenticated/cookie-vs-Bearer, direct repository denial, cross-company counts/IDOR, arbitrary metadata redaction, malformed filters/SQL-like input, ngày, cursor, source links và read side effects.
- Native routes/architecture/zeitwerk đạt (13 routing files, 37 controller/concern files). Brakeman 36 controllers/30 models/59 templates, 0 errors/warnings. Dependency advisory update: 1359 advisories, commit `4d71b123428e33f694e805ce15351ee3d8d62ef7`, không có vulnerability đã biết. Git diff whitespace check ở các tracked files của đợt này đạt; giữ nguyên comment người dùng ở các file khác.
- Không đổi dependency trong increment; đóng gói source trên image locked-dependency đã build, dùng private temporary Dockerfile. Native image uid1000, không .env/master.key, có đúng 32 bindings/audit implementation. Web Puma hot reload giữ container VS Code, worker nạp provider mới, /up 200.
- Một lượt service-wide SIGUSR2 đã ngắt nhầm test/dependency-audit; không tính lượt đó là PASS. Đã chạy lại thành công. AGENTS bổ sung quy tắc chỉ target container web dài hạn được quan sát, không signal một service khi one-off tests/migration/scanners còn chạy.
- Browser dùng phiên admin local đã được user cho phép: trang/filter/3 KPI/nav hiện đúng, bấm Cập nhật giữ kỳ/resource, aria-current đúng, viewport/page width 1304px, 0 console errors. Screenshot ở private temp, không commit ảnh tài khoản; không submit business data. Mobile chưa kiểm.
- TXT mới: `../HUONG_DAN_AUDIT_INTEGRATION_LARAVEL_RUBY.txt`: tóm tắt trước, 3 bảng ngang Laravel/Ruby, rồi giải thích files, namespaced Pundit, Audit ID vs record_id, reserved action param, index, keyset và projection. Đã cập nhật README/roadmap/inventory/TXT/ENV comparison chỗ portal audit còn ghi thiếu. Audit ENV vẫn chỉ tên/tham chiếu: Laravel 140 declared/293 referenced/301 union, Ruby 19 declared/27 referenced, không có biến runtime mới hoặc secret copy.
- Chưa có lịch sử giá trị before/after, tamper-evident ledger, export audit CSV, retention/redaction/legal hold; privileged SQL vẫn có thể sửa DB. Provider business adapters/OAuth/mTLS, ERP/government exports/external references và business dispatch vẫn chưa chuyển đủ. Không claim full 47 module, production provider delivery hay security tuyệt đối. Không push GitHub.
- Evidence: `evidence/2026-11-12-integration-audit.json`. Các phần phía dưới là checkpoint lịch sử.

---

# Integration outbound — kiểm chứng 12/11/2026

- Thêm durable MySQL delivery queue và attempt journal, Sidekiq sender + scheduler mỗi phút (quét tối đa 100 dòng), retry/backoff, dead-letter filter và version-guarded replay. Giữ Module + MVC + CQRS; thêm 3 contracts, tổng 31; 10 route riêng mới, tổng 28 route Integration. Provider không thay policy; web/API không query DB trong controller.
- MySQL thêm 2 quyền send/retry, tổng 69; runtime đọc DB, provisioning admin không phải bypass. Composite FK cùng company, unique case-sensitive idempotency/event/sequence và CHECK lifecycle/count/timestamp. Hai migration đều backup private trước áp dụng. Development giữ 7 user, 0 connection/inbound/outbound/attempt; không tạo dữ liệu giả hoặc gửi ra provider thật.
- Queue body mã hóa, immutable payload/Event ID/target/requester; cùng key cùng bytes trả dòng cũ, key đổi body/connection/target nhận conflict. Row lock chặn duplicate worker; Audit/Outbox/Attempt/state atomic. Redis handoff lỗi không mất hàng MySQL. Mỗi chu kỳ <=5 attempts, <=10 replay thủ công, tổng <=55. Receiver vẫn phải deduplicate Event ID cho cửa sổ remote nhận xong nhưng DB chưa commit; HTTP 2xx không chứng minh remote business hoàn tất.
- Quyền/company/account/connection được kiểm lại trước HTTP. Regression hai worker chỉ gửi một lần; regression permission bị thu hồi khi worker đang đợi connection lock chặn mạng. Resolve association trước transaction để không tạo snapshot REPEATABLE READ cũ trước khi chờ lock; locking read xong mới reload requester/kiểm quyền. Không thay requester gốc khi replay để né thu quyền.
- `INTEGRATION_TARGETS_JSON` chỉ operator cấu hình `{target: {url, company_ids}}`; default `{}`. UI chỉ tên đích đúng company, worker kiểm lại. HTTPS:443/verify TLS, DNS mọi IP phải public IPv4 và pin IP, không proxy/redirect, 3s open/read/write +10s transport, response discard <=4096 bytes. Không nhận URL client. IPv6 hiện từ chối; signing secret connection hiện đối xứng dùng chung ingress/outbound, chưa tách hai chiều.
- Payload permission riêng, allowlist Request, CSRF/no-store/XSS protections và filtered body; Redis args chỉ ID. Delivery/Attempt realtime prefixes yêu cầu integration.read trên từng transmit. Native image chạy uid1000, không có .env/master.key.
- Toàn bộ hrm_test: **251 runs, 1293 assertions, 0 failures/errors/skips**. Native image không mount source: **55 runs, 466 assertions**, đạt, gồm Integration/concurrency/container/realtime. Không chạy hai suite chung MySQL đồng thời.
- Native routes/architecture/zeitwerk đạt (13 route files, 35 controller/concern files). Brakeman: 34 controllers/30 models/57 templates, 0 errors/warnings. Dependency audit --update: 1359 advisories, commit `4d71b123428e33f694e805ce15351ee3d8d62ef7`, không có vulnerability đã biết. Không coi scanner là pentest.
- Compose web/worker build đạt. Sau khi chốt source, đóng gói source cuối trên image dependency vừa build từ lockfile không đổi bằng Dockerfile tạm riêng; native tests/gates kiểm chính image cuối. Không thay Dockerfile project. Worker đã restart; web hot reload Puma SIGUSR2 giữ container VS Code, /up 200. Giữ container phpMyAdmin cũ.
- Browser admin local đã được user cho phép: outbound page hoạt động, 5 KPI href đúng bộ lọc, bấm dead-letter dẫn đúng status; 1280px không tràn ngang, 0 console errors. Không submit form tạo credential/dữ liệu development. Mobile chưa kiểm. Screenshot giữ private temp.
- ENV audit cập nhật tên/tham chiếu: Laravel 140 declared/293 referenced/301 union, Ruby 19 declared/27 referenced; không copy hoặc xuất secret values. `EVENT_URL` nội bộ vẫn khác Hub/allowlist mới.
- TXT mới: `../HUONG_DAN_OUTBOUND_QUEUE_LARAVEL_RUBY.txt`: tóm tắt trước, 3 bảng ngang Laravel/Ruby, rồi giải thích luồng/file/locks/permission/SSRF/retry. Đã sửa chỗ cũ ghi “chưa có outbound/attempt/retry/DLQ/replay” trong hướng dẫn và roadmap; các checkpoint cũ bên dưới là lịch sử.
- Còn thiếu adapter nghiệp vụ provider/OAuth/mTLS, secret riêng hai chiều, ERP/government export/external references, business dispatch, retention/redaction và portal audit Integration riêng. Không claim full DJI 47 module, production provider delivery hoặc security tuyệt đối; không push GitHub.
- Evidence: `evidence/2026-11-12-integration-outbound.json`.

---

# Integration Hub inbound — kiểm chứng 12/11/2026

- Thêm Engine Integration theo Module + MVC + CQRS, 3 contracts mới (tổng 28), 18 route web/API/public khai báo riêng; gate tổng 13 routing files, 33 controller/concern files. Hub `/integration` nằm trong nhóm Quản trị & bảo mật; KPI thứ 6 Dashboard dẫn đúng danh sách nguồn; 3 KPI Hub lọc đúng trạng thái, inbox 25/trang.
- MySQL integration_connections/integration_webhooks có company FK/composite FK, UUID/code/event identity unique, Event ID binary collation và CHECK status/timestamp. Migration đã backup private trước khi áp dụng. Thêm 5 quyền, tổng 67; runtime grant từ MySQL, chỉ provision role admin, không admin bypass. Development giữ 7 user, 0 connection/webhook mẫu.
- Secret random riêng từng connection, inactive mặc định, trả một lần từ create/rotate; secret/payload/review_note dùng Active Record Encryption, metadata/normal JSON không có nội dung nhạy cảm. Payload đọc bằng permission riêng. Rotate/disable và receive dùng chung connection row lock; record mutation có lock_version. Review là acknowledgment/rejection vận hành, không tự apply HR/payroll hoặc cấp account.
- HMAC bind timestamp.event_id.raw_body, freshness ±300 giây; schema/UTF-8/depth validate sau chữ ký. Raw bytes bảo toàn cả payload tiếng Việt từ HTTP binary. Body middleware đọc tối đa 65537 byte và chặn 413/415 trước controller; đổi content type nội bộ để Rails không parse/log raw JSON trước action. Timestamp/ID/type formats bounded, 120 POST/IP/60s với shared RackAttack; CSRF giữ nguyên trên quản trị.
- Durable duplicate cùng connection/Event ID/raw bytes trả lại ID; thay nội dung nhận 409. Hai kết nối MySQL cùng nhận chỉ tạo một receipt/outbox. Receipt/audit/outbox cùng transaction; kiểm outbox lỗi rollback cả receipt/audit. Company/permission/IDOR, key revocation, stale version, malformed input, XSS, payload privacy và database FK được kiểm.
- Rà lại realtime: Integration provider đăng ký prefix -> integration.read bằng string; HrUpdatesChannel gọi Hrm::RealtimeAuthorization trước mỗi transmit. HR có realtime.read vẫn không nhận metadata Integration nếu thiếu quyền module; revoked integration.read tác động subscription đang mở. Không broadcast raw payload/secret. Sau cùng hot restart Puma bằng SIGUSR2 để subscription cũ nạp gate mới, không restart/recreate container web.
- Toàn bộ hrm_test: **226 runs, 1122 assertions, 0 failures/errors/skips**. Native Docker image chạy riêng: **26 runs, 140 assertions**, đạt. CLI ENV sau sửa hướng dẫn: **4 runs, 33 assertions**, đạt. Không chạy suites ghi cùng test DB đồng thời.
- Routes/architecture/zeitwerk đạt. Brakeman 32 controllers/28 models/55 templates, 0 errors/warnings. Dependency advisory update: không có advisory đã biết, DB commit `4d71b123428e33f694e805ce15351ee3d8d62ef7`.
- Docker web/worker build cuối đạt, image eager load được 28 bindings/67 definitions, body middleware/encrypted schema/mediumtext/realtime gate, không có master.key. Worker restart; web health 200. Giữ container phpMyAdmin cũ. Browser account admin local đã được người dùng cho phép: KPI -> Hub, form và filter links/empty states hoạt động, 1280/pageWidth1280, 0 console errors, không tạo credential hay business data mẫu. Mobile chưa kiểm.
- Nâng contract mạnh hơn DJI payload-only HMAC; không tương thích trực tiếp signature cũ. Inbound Hub khác protocol của internal event_sink. Tại checkpoint inbound còn thiếu outbound; queue/attempt/retry/DLQ/replay đã bổ sung trong đợt outbound ở trên, còn adapter nghiệp vụ/export/domain dispatch/retention; không claim full Integration hoặc toàn bộ 47 module.
- Hướng dẫn 3 bảng: `../HUONG_DAN_INTEGRATION_WEBHOOK_LARAVEL_RUBY.txt`. Inventory/roadmap và TXT cũ đã cập nhật phần hiện có; ENV audit vẫn chỉ tên/tham chiếu, không thêm/copy secret DJI. Evidence: `evidence/2026-11-12-integration-hub.json`. Không push GitHub hoặc chạy remote CI trong đợt này. Các mục dưới là lịch sử.

---

# ENV feature parity — kiểm chứng 12/11/2026

- Đọc tên biến từ Laravel .env/các file mẫu và literal env references trong config/source. 140 tên được khai báo, 293 tên được tham chiếu, hợp nhất 301 tên; Ruby có 18 tên khai báo và 26 tên tham chiếu trực tiếp. Tất cả 301 tên có nhóm đối chiếu trong 23 nhóm, không có nghĩa tất cả đã port hoặc đang active.
- TXT mới `../DOI_CHIEU_ENV_LARAVEL_DJI_RUBY.txt`: ba bảng ngang theo nhóm/từng biến Laravel/từng biến Ruby, file:dòng, tương đương/khác/chưa có và giải thích cho người mới. JSON: `env-feature-audit.json`; mapping review: `env-feature-map.json`. Backlog ERP nối cả khoảng trống ENV ngoài 47 module.
- CLI `ruby bin/audit-env-features` chỉ thống kê; `--write` cập nhật TXT/JSON. Không load/eval ENV, không xuất giá trị/hashes, không sửa source DJI hay .env Ruby, không gọi provider ngoài. Bỏ qua quoted multiline values để private-key fragments không bị hiểu nhầm thành key mới; Ruby comments/vendor/tests được loại khỏi static consumer scan.
- Phát hiện 6 tên khai báo lặp trong cùng .env.example DJI: SESSION_SECURE_COOKIE, SESSION_HTTP_ONLY, SESSION_SAME_SITE, VITE_SOURCEMAP, DOCUMENT_STORAGE_DISK, EMPLOYEE_DOCUMENT_STORAGE_DISK. Chỉ báo cáo vị trí; không sửa Laravel và không suy đoán precedence/config cache runtime.
- Đã đối chiếu thêm GCS/keyless, Supabase/S3/private documents, ClamAV/quarantine/reconciliation, Cloudflare Images/DDoS, OAuth/phone/Passport, Swagger, feature flags, lifecycle/disposal, monitoring/SLO/retention. Các capability chưa port ghi rõ missing/partial; không thêm biến giả để đánh dấu xong.
- Sender mail: LeaveMailer đọc MAIL_FROM, base ApplicationMailer còn sender mẫu; SMTP_USERNAME/PASSWORD có code nhưng chưa có trong env template. MySQL chưa có ENV TLS CA/port; HTTPS web không đồng nghĩa MySQL TLS. Reverb/Action Cable, APP_KEY/bộ khóa Rails và session driver có khác biệt cơ chế, không copy secret.
- Kiểm thử CLI: **4 runs, 33 assertions, 0 failures/errors** trên fixture tạm; kiểm thêm artifact không chứa các secret dài hiện có, không in giá trị/hashes ra tool output. Native CLI và Ruby syntax đạt. Routes 12/architecture 30/zeitwerk đạt; Brakeman engines 0 errors/warnings; dependency audit update không có advisory đã biết (`4d71b123428e33f694e805ce15351ee3d8d62ef7`). Brakeman không chứng nhận CLI an toàn; tests và review riêng bảo vệ luồng đọc ENV.
- Không đổi runtime ứng dụng/DB/schema hoặc cấu hình dịch vụ; không chạy lại full app suite và không build/push mới cho thay đổi CLI/tài liệu này. Evidence: `evidence/2026-11-12-env-feature-audit.json`. Các kết quả app ở dưới là lịch sử các đợt trước.

---

# ERP workspace / Onboarding / webhook — kiểm chứng 12/11/2026

- Dashboard ERP màu vàng: 5 KPI dẫn tới danh sách nguồn đúng phạm vi quyền; lấy count qua contract từng module. Menu 4 nhóm và Board dùng chung catalog; đủ các màn hình hiện có, gồm báo cáo công và định biên. Cache theo company/user/digest quyền tối đa 30 giây. Thu hồi quyền nghỉ phép không làm widget chặn cả Dashboard.
- Engine Onboarding có MVC + CQRS, 2 contracts mới (tổng 25), 11 route web/API khai báo tường minh; tổng gate 12 routing files. MySQL onboarding_cases có composite company/employee FK, unique company/employee/start_date và CHECK status; thêm 4 quyền DB, tổng 62. Đã backup private trước migration; development giữ 7 user, 0 hồ sơ tiếp nhận/ca/phân ca mẫu.
- Chuyển state machine DJI, checklist snapshot ở server, điều kiện hoàn tất các mục bắt buộc; row lock + lock_version; immutable employee/start date; own/company scope; audit/outbox atomic. Nhân viên có lịch sử tiếp nhận bị chặn xóa bằng lỗi nghiệp vụ.
- Webhook nội bộ ký timestamp.raw_body, freshness 300 giây, body <=64 KiB, content-type/schema/ID bounds, timeout gửi/nhận; duplicate ID cùng nội dung idempotent, khác nội dung/company nhận 409. Receiver có backup trước schema digest. Chữ ký cũ không được chấp nhận; ID lịch sử thiếu digest phải được operator đối chiếu nếu cần gửi lại, không tự coi là cùng nội dung.
- Toàn bộ hrm_test: **196 runs, 935 assertions, 0 failures/errors/skips**. Bộ cuối Onboarding/Dashboard: **13 runs, 81 assertions**, đạt. Receiver: **8 tests** đạt trên host và Docker Python; gồm tamper, replay, duplicate conflict, size/type/schema và integer bounds. Không chạy hai bộ tests chung MySQL đồng thời.
- Zeitwerk/routes/architecture đạt. Brakeman 29 controllers/26 models/49 templates, 0 errors/warnings. Dependency audit update: không có advisory đã biết, DB commit `4d71b123428e33f694e805ce15351ee3d8d62ef7`.
- Docker web/worker/event_sink build đạt; standalone image eager-load được 25 bindings, contract count, helper/schema và employee history guard, không chứa master.key. Receiver/worker đã nạp protocol mới; web/receiver health 200. Không recreate container web đang dùng VS Code; đã restart tiến trình để nạp Engine/helper mới. Container phpMyAdmin cũ được giữ.
- Browser: session admin local đã được người dùng cho phép; KPI nhân sự mở đúng 6 hồ sơ, Board/form Onboarding và nhãn Việt hoạt động, 5 KPI href đúng nguồn; viewport/pageWidth 1280, 0 console errors. Không submit dữ liệu nghiệp vụ mẫu; mobile chưa kiểm. Screenshot ở private temp, không đưa ảnh tài khoản vào Git.
- Chưa hoàn tất 47 module DJI; Onboarding chưa có tuyển dụng liên kết/buddy/owner/provisioning/due-date dependency/approval thử việc. Webhook là receiver nội bộ, chưa phải module Integration đầy đủ. Encryption hiện có bảo vệ national_id/bank_account, không phải toàn DB. Không push GitHub hoặc xác nhận remote CI trong đợt này.
- Hướng dẫn mới: `../HUONG_DAN_ERP_DASHBOARD_ONBOARDING_LARAVEL_RUBY.txt` (3 bảng ngang). Backlog 47 module: `erp-porting-roadmap.json`; evidence: `evidence/2026-11-12-erp-workspace-onboarding.json`. Các mục dưới là lịch sử những đợt trước.

---

# EmployeeShiftAssignment — kiểm chứng 12/11/2026

- Chuyển phần fixed assignment trong WorkforceManagementService DJI sang Attendance Rails: khoảng hiệu lực, lưu snapshot ca server, chỉ đổi effective_to, xóa chỉ lịch tương lai. Hai hợp đồng ScheduleRead/Write mới; tổng 23 bindings.
- MySQL employee_shift_assignments có company FK, composite company/employee và company/shift, unique employee/from, CHECK dates. Thêm 5 quyền MySQL; runtime giữ 58 permission và 7 tài khoản, 0 phân ca mẫu. Có backup private trước migration, không đổi mật khẩu.
- Employee row lock bao cả kiểm overlap và save; kiểm thật hai kết nối MySQL cùng ghi một nhân viên: đúng một create/one rejection. Update/delete đọc lại sau khóa, kiểm optimistic version. SQL đặc quyền ngoài command có thể bypass overlap; báo conflict và không tự tính nếu đọc gặp nhiều lịch.
- Snapshot giữ nguyên khi sửa ca nguồn; identity/start/snapshot không sửa sau tạo. WorkShift/Employee có phân ca không được xóa. Lịch đối chiếu 1..31 ngày, scope lịch và attendance riêng; restricted không lộ lượt công, not_recorded không suy diễn vắng mặt. Thêm canonical /attendances/:id với ownership scope.
- hrm_test: **184 runs, 846 assertions, 0 failures/errors/skips**. Tests gồm snapshot/audit atomicity, inclusive interval/closing/reopen, stale version, historical delete, DB bypass FK/CHECK, permission revoke, IDOR, malformed nested IDs, no-write report và concurrency thật.
- Routes gate 11 file; architecture 28 controller/concern files + views; Zeitwerk đạt. Brakeman 27 controllers/25 models/46 templates: 0 errors/warnings. Dependency audit update không có advisory đã biết.
- Browser: sau khi người dùng xác nhận rõ việc dùng admin local, login/danh sách/form phân ca và submit bộ lọc lịch công đạt. Có 7 dòng Chưa phân ca đúng trạng thái dữ liệu, không tạo dữ liệu nghiệp vụ; viewport/pageWidth 1280, 0 console errors. Form hướng dẫn mở cấu hình ca khi chưa có ca chọn; 4 HTTP tests sau chỉnh hint đạt. Mobile chưa kiểm lượt này.
- Docker web/worker build cuối đạt; image eager load không mount source, đủ 23 bindings/58 definitions, có bảng phân ca và strict date validation, không chứa master.key; worker restart không recreate và /up HTTP 200. Dependency advisory DB cuối: `4d71b123428e33f694e805ce15351ee3d8d62ef7`, 0 advisory đã biết.
- Chưa port WorkCalendar/weekday/holiday/ca xoay, break events, overtime approval/chốt công/payroll. Option dropdown giới hạn 200; report readonly, không thay check-in hiện tại.
- Hướng dẫn: `../HUONG_DAN_PHAN_CA_LARAVEL_RUBY.txt`; inventory và hướng dẫn WorkShift cũ đã cập nhật phần phân ca. Evidence: `evidence/2026-11-11-shift-assignments.json`. Các mục dưới là lịch sử.

---

# WorkShift + attendance preview — kiểm chứng 11/11/2026

- Attendance sở hữu WorkShift MVC/CQRS, hai repository contracts mới (tổng 21), 16 route web/API khai báo riêng; calculator thuần và preview chỉ đọc dữ liệu attendance đã scope.
- MySQL tạo work_shifts có company FK, company/code unique, clock/rule CHECK và lock_version. Bốn quyền mới provision qua catalog module và migration; runtime vẫn User#allowed?/Policy trong DB. Development: 53 permissions, giữ 7 tài khoản/mật khẩu, 0 ca mẫu. Đã sao lưu private trước migration.
- Ca ngày/qua đêm; giờ nghỉ không công, grace đi trễ/về sớm, ngưỡng ngoài ca. Preview dựa cấu hình hiện tại; không ghi Attendance/Payroll/audit/outbox. CRUD audit/outbox trong transaction, actor đúng cả khi gọi Command ngoài HTTP. Update/delete bắt buộc version, stale -> 409.
- Toàn bộ hrm_test: **163 runs, 742 assertions, 0 failures/errors/skips**. Gồm MySQL bypass constraints, tenant/ownership/permission deny, request spoof, optimistic locking, preview malformed ID/IDOR/no writes, ngày/đêm và net không âm.
- Explicit route gate 11 file; architecture 26 controller/concern files + views; Zeitwerk đạt. Brakeman: 25 controllers/24 models/41 templates, 0 errors/warnings. Dependency advisory update: không có advisory đã biết.
- Browser thật: login account cũ, danh sách rỗng và form tạo ca có giờ mặc định hoạt động; viewport/pageWidth 1280; 0 console errors; không tạo ca trong development. Mobile chưa kiểm lượt này.
- Docker web/worker build đạt; image eager load độc lập không mount source, đủ 21 bindings/53 definitions và đọc bảng WorkShift, không chứa master.key. Worker restart không recreate, web /up HTTP 200.
- Chưa có phân lịch ca cho từng nhân viên, calendar/ngày nghỉ, break events, snapshot lịch sử, event pairing hoặc overtime approval. Không coi preview là giờ tính lương hoặc parity toàn bộ Attendance DJI.
- Hướng dẫn so sánh: `../HUONG_DAN_CA_LAM_VIEC_LARAVEL_RUBY.txt`; TXT báo cáo theo kỳ/inventory cũ đã cập nhật phần WorkShift. Evidence: `evidence/2026-11-11-work-shifts.json`. Các mục sau là lịch sử.

---

# Security hardening — kiểm chứng 11/11/2026

- Session web có thể thu hồi trong MySQL `login_sessions`: token ngẫu nhiên ở cookie mã hóa, DB chỉ lưu digest, hạn tuyệt đối 8 giờ. Logout chặn replay cookie; đổi mật khẩu/disable User thu hồi web/API trong transaction. Cấp credential khóa row User để tránh race với password change; Cable kiểm phiên trước transmit.
- Rate limit IP hiện có mở rộng match format suffix/path escapes/repeated slashes; thêm account counter HMAC normalize email, gộp JSON/form qua nhiều IP, 429/Retry-After. Có trade-off account lockout tạm thời. Dummy bcrypt giảm shortcut unknown account; không tuyên bố constant-time toàn luồng.
- Response nhạy cảm no-store, CSP form-action self, Permissions-Policy/COOP, lọc thêm HR params khỏi request logs. Kiểm CSRF thật thay vì chỉ dựa config test mặc định.
- Dependency audit phát hiện advisory trên bộ cũ; nâng Rails **8.1.4.1**, Rack **3.2.8**, Nokogiri **1.19.7**, Loofah **2.25.3**, rails-html-sanitizer **1.7.2**. `bundler-audit check --update` không còn advisory đã biết, DB commit `38f94284b05c2052b13a4922a86cc7cffb2266e2`. Giữ lock ARM/x86, không khẳng định đã build x86.
- MySQL development đã sao lưu trước migration thêm login_sessions; giữ 7 account và mật khẩu hiện có, không thêm bản ghi nghiệp vụ. Cookie web kiểu cũ cần login lại. Lịch PurgeCredentialsJob đã đăng ký trong Redis; chỉ dọn credential hết hạn.
- Toàn bộ hrm_test: **141 runs, 630 assertions, 0 failures/errors/skips**, trên image dùng dependency đã vá. Có tests cookie replay, expiry, password revoke/rollback/stale actor, CSRF, JSON/form throttle, account scope và Cable revocation. Log `{bad` trong test là payload malformed JSON cố ý.
- Explicit routes 11 file; architecture 24 controller/concern files + views; Zeitwerk đạt; Brakeman 23 controllers/23 models/37 templates, 0 errors/warnings. Known secret filenames .env/master.key/private key không được Git track; không thay thế secret scanning toàn bộ lịch sử.
- Browser thật: tài khoản cũ login, Cable connected, logout rồi mở /manage/company bị đưa về login; 0 console errors. Đọc HTTP response local xác nhận security headers có hiệu lực.
- Docker web/worker build cuối đạt; image eager load không mount source, xác nhận Rails/Rack đã vá và đọc bảng session, không chứa master.key; /up HTTP 200 sau restart.
- Dependabot YAML chuẩn bị cho Bundler/Actions hàng tuần; chưa push/chạy remote CI trong lượt này. Chưa có MFA/passkey, idle timeout, WAF/DDoS/pentest; production proxy/TLS/DB least privilege và restore backup chưa kiểm chứng. Không tuyên bố hệ thống chống hack tuyệt đối.
- Hướng dẫn: `../HUONG_DAN_SECURITY_LARAVEL_RUBY.txt`; evidence: `evidence/2026-11-11-security.json`. Các mục dưới là lịch sử.

---

# Báo cáo chấm công theo kỳ — kiểm chứng 11/11/2026

- Thêm web `/attendances/report` và REST GET `/api/v1/attendances/report`, cùng Query/Repository/Policy. Giữ route khai báo riêng và company/ownership scope từ MySQL.
- Khoảng ngày hợp lệ tối đa 93 ngày; summary toàn kỳ độc lập pagination 25 dòng. Ca đêm theo ngày vào; ca chưa đóng không tự cộng thời gian; cảnh báo ca đã đóng >16 giờ. Đây là thời gian ghi nhận thô, chưa phải giờ tính lương.
- Check-in chặn ca mới khi còn ca cũ mở, kiểm tra dưới employee row lock hiện có. Retry checkout giữ giờ ra đầu tiên. Chưa có DB unique constraint cho mọi ca mở; write ngoài command có thể bypass quy tắc này.
- hrm_test: **118 runs, 520 assertions, 0 failures/errors/skips**; thêm 15 test so với increment Organization, gồm kỳ/ngày, scope, thu quyền token, source links, pagination, overnight và ca cũ.
- Route gate 11 file; architecture gate 23 controllers + views; Zeitwerk đạt. Brakeman: 23 controllers/22 models/37 templates, 0 errors/warnings.
- Browser local đã đăng nhập: trang report và submit date filter hoạt động; viewport 1280, pageWidth 1280; không console errors. Mobile chưa kiểm lượt này. Không tạo ca hay dữ liệu mẫu trong development; không migration/schema/quyền mới.
- Docker web/worker build đạt; image mới eager load độc lập không mount source, có report Query và open-session guard.
- Hướng dẫn: `../HUONG_DAN_CHAM_CONG_THEO_KY_LARAVEL_RUBY.txt`. Evidence: `evidence/2026-11-11-attendance-report.json`. Các báo cáo dưới đây là lịch sử của các increment trước.

---

# Organization + CQRS — kiểm chứng 11/11/2026

- Thêm module local gem `organization`: cost center, đơn vị/cây tổ chức, vị trí, phân công hiệu lực, định biên; web CRUD, REST, CSV. Đây là một phần chuyển đổi, chưa phải parity toàn bộ Laravel DJI.
- Hai repository contracts mới; tổng 19 bindings. Engine/provider đăng ký permission catalog qua tên lớp, Identity không phụ thuộc cứng vào Organization.
- MySQL thêm 4 bảng; composite FK company và FK ba cột giữ đúng position/unit; CHECK/unique thật. 20 permission mới, giữ custom roles/deny overrides. Development: 49 permissions, 7 tài khoản cũ, không thêm dữ liệu vận hành mẫu.
- Sao lưu trước migration tại đường dẫn private local; số dòng và hash dữ liệu 14 bảng nghiệp vụ cũ trước/sau không đổi. Không copy DB hoặc sửa source Laravel.
- Rails/Minitest hrm_test: **103 runs, 467 assertions, 0 failures/errors/skips**. Có test hai kết nối MySQL cùng tạo assignment cho một chỗ trống, kiểm future intervals/allocation/headcount và bypass validation bằng SQL bị FK chặn.
- Sau chỉnh format view: 5 HTTP tests/41 assertions đạt. Route gate 11 file; architecture gate 21 controller + views; Zeitwerk đạt. Brakeman 21 controllers/22 models/36 templates: 0 errors, 0 warnings.
- Runtime Rails: 150 route tổng, 64 route Organization. Khác bộ đếm tĩnh 505 khai báo trong source Modules Laravel; số 753 trong CV là snapshot runtime Laravel ngày 29/10, chưa kiểm lại runtime Laravel hôm nay.
- Browser thật: đăng nhập local, cây/4 danh sách/4 form. Viewport 320px: không tràn ngang trang, không console errors. Empty state trung thực, không seed để làm đầy màn hình. Desktop viewports: NOT_VERIFIED.
- Docker web/worker build native cuối cùng thành công; image khởi động/eager load độc lập không mount source, có đủ 49 permission definitions và CSV, không chứa config/master.key. Lockfile giữ cả ARM và x86 đã có; CI username provision sửa thành ruby. Không khẳng định CI remote hoặc build x86 đã chạy trong lượt này.
- Các file ghi chú Ruby đang được user sửa từ trước được giữ nguyên; whitespace cũ ở các file đó không bị tự format. Kiểm diff whitespace các file thuộc increment mới đạt.
- Chưa hoàn tất: Organization competency schema, báo cáo ngân sách và workflow/branch ABAC đầy đủ; các context khác của DJI còn trong inventory. Xem `dji-parity-inventory.json` và `../DOI_CHIEU_TOAN_BO_LARAVEL_DJI_SANG_RUBY.txt`.
- Evidence máy đọc: `evidence/2026-11-11-organization.json`. Các mục phía dưới là báo cáo lịch sử, không phải trạng thái kiểm thử mới nhất.

---

# Company + RBAC MySQL — kiểm chứng 28/10/2026

- Thực hiện trực tiếp trên project Ruby hiện tại và database hrm_development, không tạo checkout/database clone.
- Migration MySQL thêm companies, permissions, company_roles, role_permissions, user_permissions; backfill company cho dữ liệu cũ và FK tổng hợp chống liên kết chéo company, gồm users(company_id,role) -> company_roles(company_id,key).
- Đã sao lưu development trước migration. Fingerprints các cột gốc và số dòng của 11 bảng được đối chiếu trước/sau migration: không đổi. 7 tài khoản hiện có được gắn company XINVIEC/vai trò, không đổi mật khẩu.
- MySQL development: 1 company, 29 permission, 4 role defaults, 67 role grants; vai trò tùy chỉnh và account grant/deny tạo/sửa được qua web/API.
- Rails/Minitest trên hrm_test: **75 tests, 335 assertions, 0 failures/errors/skips**. Gồm quyền động/deny, custom roles, company scopes, chống IDOR, composite FK thực tế, payroll snapshots, cache permission digest, mail summary scope, API token cũ sau thu quyền, actor stale, protected admin và role case/whitespace.
- Action Cable tenant tests đạt; stream riêng từng company, permission recheck và JSON coder.
- Zeitwerk đạt; explicit route gate đạt 10 routing files; architecture gate đạt 17 controllers và views.
- Brakeman quét 17 controllers, 18 models, 31 templates: **0 errors, 0 security warnings**; không thêm ignore để bỏ qua privileged role input.
- Docker web/worker build thành công; đối chiếu 225 Ruby files trong image khớp checkout, eager load và 17 bindings đạt; đọc được MySQL/grants thật, không chứa config/master.key. App/worker restart, /up HTTP 200.
- Đăng nhập thật trên development: dashboard, /manage/company, /manage/roles, /manage/accounts đều HTTP 200, khoảng 41–192 ms trong lượt smoke đã đo. Không tạo thêm dữ liệu nghiệp vụ cho smoke này.
- Hướng dẫn mới: HUONG_DAN_COMPANY_PERMISSION_MYSQL.txt. Bốn TXT cũ đã sửa ngay các ô Ruby từng ghi thiếu company/single-org; phần Node vẫn mô tả đúng project Node chưa được thay đổi.
- Phạm vi: một account thuộc một company; admin chỉ trong company. Chưa có switch nhiều membership/branch scope cho một account và không tuyên bố ngang toàn bộ nghiệp vụ DJI.

Các mục bên dưới là lịch sử kiểm tra các lần trước, không phải số lượng test/bindings hiện tại (hiện 17 bindings).

---

# Kết quả kiểm tra local — 25/10/2026 (giờ Việt Nam)

- Rails/Minitest trên MySQL: 24 tests, 82 assertions, 0 failures, 0 errors.
- Event sink: 3 tests đạt — HMAC, schema validation, delivery idempotency.
- Zeitwerk: eager loading đạt.
- Brakeman: 0 errors, 0 security warnings.
- Bundler Audit: không phát hiện lỗ hổng trong lockfile theo ruby-advisory-db cập nhật ngày 23/10/2026.
- Browser thật: đăng nhập admin, dashboard tiếng Việt, bố cục màn hình hẹp, Action Cable xác nhận subscription.
- Worker thật: Sidekiq xử lý outbox, email duyệt đơn và tổng hợp; Mailpit nhận 3 email demo.
- Event receiver thật: 14 events nhận, 14 events delivered, 0 pending tại thời điểm kiểm tra.
- Scheduler: đăng ký outbox + daily_hr_summary; xác nhận tác vụ outbox được scheduler tự enqueue và xử lý.

Ảnh: [dashboard](dashboard.jpg). Script chạy luồng demo: `script/smoke.rb` (chỉ development). Các số liệu demo có thể tăng khi chỉnh sửa dữ liệu hoặc chạy lại script.

Các kiểm thử không thay thế kiểm tra tải, pentest, quy trình nghiệm thu nghiệp vụ và kiểm thử triển khai production. Giao diện kiểm tra tự động qua request tests; thao tác trình duyệt kiểm tra trực tiếp ở local. CI đã được cấu hình, chưa có lượt chạy CI trên GitHub trong phiên này.

## Sau tái cấu trúc Module + MVC

- Toàn bộ nghiệp vụ và lớp nền đã chuyển vào 9 local gem Rails Engines.
- Bộ kiểm thử Rails sau chuyển: 26 tests, 87 assertions, 0 failures, 0 errors; gồm test của các module và hành trình xuyên module.
- Zeitwerk eager loading, web/API route helpers và CLI tasks được kiểm tra lại.
- Database baseline được giữ nguyên, không tạo lại schema hoặc xóa dữ liệu.
- Brakeman sau chuyển: quét đủ 15 controllers, 13 models, 27 templates; 0 warnings/errors.
- HTTP kiểm tra login và CSS từ engine platform: đạt, giữ tông vàng.
- Worker khởi động và xử lý outbox từ lịch khai báo của module.

## Sau nâng cấp kiến trúc tham chiếu Laravel DJI — 26/10/2026

- 9 module có ServiceProvider; container đăng ký 16 repository contracts bằng tên lớp, hỗ trợ Rails reload và constructor injection.
- Rails/Minitest: 45 tests, 202 assertions, 0 failures, 0 errors, 0 skips.
- Kiểm thử gồm phân quyền trực tiếp tại use case, chống truy cập bản ghi người khác, chặn chấm công nhân viên không hoạt động, rollback duyệt đơn khi outbox lỗi, và dữ liệu danh sách được nạp trước View.
- Kiểm tra route tường minh: đạt 10 files; kiểm tra kiến trúc: đạt 15 controllers và các views.
- Zeitwerk eager loading đạt; reload giữ đủ 16 bindings hợp lệ.
- Brakeman: 15 controllers, 13 models, 27 templates; 0 errors, 0 security warnings.
- Build Docker web/worker thành công. Image chạy độc lập nạp đủ lớp và 16 bindings; không chứa config/master.key.
- Web health HTTP 200, worker khởi động thành công sau cập nhật mã.
- Không thay đổi migration/schema, không reset dữ liệu development, không chỉnh sửa hoặc sao chép dữ liệu/secrets Laravel DJI.
- Đây là nâng cấp kiến trúc nghiệp vụ Rails hiện có; không phải chuyển toàn bộ tính năng đa công ty, ca làm, tăng ca hoặc thuế từ DJI.
- Hướng dẫn người mới: HUONG_DAN_LARAVEL_SANG_RAILS.txt; đối chiếu nguồn tham khảo: docs/DJI_ARCHITECTURE_MAPPING.md.

Các kết quả trên là kiểm tra local của lần nâng cấp này; không thay thế nghiệm thu nghiệp vụ, kiểm tra tải hoặc pentest production.
