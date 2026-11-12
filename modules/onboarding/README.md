# Onboarding

Local Rails Engine with MVC + CQRS, MySQL tenant/RBAC, case lifecycle and immutable checklist template snapshots. Read/write contracts are registered by OnboardingServiceProvider. Entry: `/onboarding/cases`; API: `/api/v1/onboarding/cases`.

Ported DJI state transitions; completion requires required checklist items. Row locking plus optimistic lock_version protect mutations. Employee/start date are immutable. Writes generate audit/outbox atomically. Scope ownership is enforced for web/API/use cases; composite FK protects same-company employee references. No delete or automatic access provisioning.

Partial port: recruitment links, buddy/owner, separate provisioning items, configurable dependency templates, due dates and probation approval are not implemented. See root `HUONG_DAN_ERP_DASHBOARD_ONBOARDING_LARAVEL_RUBY.txt`.
