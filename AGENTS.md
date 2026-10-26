# Ruby HRM development conventions

- All features belong to a local Rails Engine under modules/. Keep MVC in app/ and layered Ruby code under lib/hrm_<module>/{application,domain,infrastructure,providers}/.
- Application Queries read data; Application Commands perform mutations and orchestration. Domain Services contain business rules. Infrastructure Persistence implements Domain repository interfaces with Active Record.
- Providers own bindings. Resolve repository contracts through Hrm::Container in constructor defaults; permit explicit constructor injection for tests. Store constant names in the registry so Rails reloads do not retain old class instances. Never bypass a missing binding with an implicit fallback.
- Controllers coordinate requests, authorization, use cases and responses. They may instantiate unsaved form models, but must not issue database queries or persist records. Views render prepared data; model associations/validation remain ordinary Active Record responsibilities.
- User-driven reads preserve Pundit scope. Commands enforce actor authorization even when invoked outside HTTP. Trusted scheduler/CLI entrypoints must remain separate from public HTTP actions.
- Preserve encryption, optimistic locking, audit/outbox atomicity, ownership rules, existing route helpers and business behavior unless the task explicitly changes them.
- Declare HTTP routes individually with get/post/patch/put/delete; no resource/resources/namespace shorthand in route files.
- Run ruby bin/check-routes, ruby bin/check-architecture, bin/test-docker and Rails zeitwerk:check for relevant architecture changes. Scan all engines using bundle exec ruby bin/brakeman --no-pager.
- Database-changing tests must use RAILS_ENV=test and hrm_test. Do not reset development data or copy database/secrets from the Laravel reference.
- Desktop/laraveldji/admin is a read-only architecture reference for this Rails project. Do not modify it or claim feature parity with its multi-company HRM.
- Keep HUONG_DAN_LARAVEL_SANG_RAILS.txt aligned with actual paths and explain new terms for someone moving from Laravel. Distinguish Application Commands from terminal/Artisan-style commands.
