# Organization — Module + MVC + CQRS

Owns `cost_centers`, `organization_units`, `job_positions`, `employee_assignments`. MySQL data is company-scoped with composite foreign keys. No operational data is seeded or copied from Laravel.

Reads: explicit routes → controllers → Application Queries → ReadRepository → Active Record. Writes: controller → Application Commands → company lock → authorization/model/domain interval rules → WriteRepository. Models retain validation and audit/outbox callbacks. `Resources` is a closed allowlist for four organization entities; it never constantizes client-provided class names.

- Cost centers: currency/budget, code unique in company, cannot delete referenced records.
- Units: hierarchy, dates, cost-center linkage, no cycles, children below parent, serialized company-level writes.
- Positions: career level, grade, critical status, planned cost, approved headcount; cannot move historically assigned positions or reduce below peak scheduled occupancy.
- Assignments: source Employee from workforce, position/unit consistency, effective dates, up to 100% overlapping allocation and approved vacancy capacity. They do not overwrite Employee.department/job_title.
- Tree/headcount: canonical source links and scoped counts; counts come from actual effective assignments, not synthetic rows.
- CSV: permission guarded, company scoped, spreadsheet formula cells neutralized.

Web: `/organization/{cost-centers,organization-units,job-positions,employee-assignments}`, `/organization/tree`, `/organization/headcount`. REST uses `/api/v1/organization/...`. Routes declare each verb separately. Forms post a `record` allowlist; company comes from actor. Read/CRUD/export permissions are stored in existing MySQL RBAC tables.

Migration appends schema and provisions new grants for existing admin/hr/manager roles. Custom roles and user deny overrides are preserved. The provider registers a reload-safe permission-catalog extension by class name. PermissionDefinitions supplies defaults only for new companies; Identity can provision without this optional extension. Authorization always reads MySQL.

Tests: `RAILS_ENV=test bundle exec rails test modules/organization/test`. Includes two simultaneous MySQL writers contending for one vacancy. Production/development data must not be reset for tests.

Reference: Laravel DJI Organization. This is not full DJI/ERP parity; competencies JSON, cost-center budget aggregation, broader workflow/branch ABAC and related integrations remain on the migration inventory.

Named company branches: `/organization/branches` and API equivalents list/create existing OrganizationUnit `branch` rows, force actor company/type server-side, link to actual unit detail/edit/tree/positions/assignments. Company registry shows branch counts by company; switch only assigned membership before business actions. No duplicate fake branch table and no claim of per-branch ABAC across HR/payroll yet.
