# Procurement: purchase requests and purchase orders

Rails Engine + MVC + CQRS. See [ERP navigation](../../docs/ERP_NAVIGATION.md) for routes, permissions, lifecycle, money rules and Laravel/Rails comparison; [verification](../../docs/VERIFICATION.md) for evidence.

- `config/routes/procurement.rb`: explicit HTTP routes.
- `app/controllers/procurement/requests_controller.rb`: permitted input, command/query orchestration and response.
- `app/policies/purchase_request_policy.rb`: MySQL grants, owner/maker-checker and company scope.
- `lib/hrm_procurement/application/{commands,queries,requests}`: write/read entrypoints and HTTP parameter allowlist.
- `lib/hrm_procurement/domain/{repositories,services}`: repository contracts, exact VND parsing, filters and conflicts.
- `lib/hrm_procurement/infrastructure/persistence`: scoped reads and transactional writes/current locking authorization.
- `lib/hrm_procurement/providers`: reload-safe repository and permission/realtime registrations.
- `app/models`: parent, immutable submitted lines and versioned encrypted decision history.
- `db/migrate`: composite tenant FKs, CHECKs, indexes and MySQL state/content guards.
- `app/views`: list/search/queues, editable drafts, confirmation and history.
- `test`: request integration, database guards, rollback and concurrency against hrm_test.

Company comes from the authenticated profile. Never call persistence with a client-selected company, calculate money with Float, or use an enum role as a runtime permission bypass. Privileged SQL can bypass callbacks/model history; SQL maintenance is not an application editing API. No deletion route is exposed. Procurement is gradual typing; the existing 21 strict files are unchanged.

## Purchase orders

`CreateOrder` locks an approved scoped source and snapshots its lines; unique company/source makes retries return the original PO. `UpdateOrder` changes only draft prices/date/reason; `IssueOrder` rechecks current grants, version, status and active supplier under locks. `OrderReads`/`OrderWrites` implement the existing contracts. Supplier maintenance is a separate permission-scoped catalog. See ERP_NAVIGATION for field units, all grants, source links and limitations; receiving/invoicing/AP are not implemented here.

DSL generation must use `bundle exec tapioca dsl --environment=test --workers=1`; Tapioca defaults to development even when the shell sets RAILS_ENV. Both config and bin/check-rbi pin the test environment. Do not migrate development merely to make RBI verification pass.
