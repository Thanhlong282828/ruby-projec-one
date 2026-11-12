source "https://rubygems.org"
ruby "~> 3.4.0"
gem "rails", "~> 8.1.0", ">= 8.1.4.1"
gem "rack", "~> 3.2", ">= 3.2.8"
gem "mysql2", "~> 0.5"
gem "puma", ">= 6.0"
gem "bcrypt", "~> 3.1"
gem "redis", "~> 5.0"
gem "sidekiq", "~> 7.3"
gem "connection_pool", "~> 2.5"
gem "sidekiq-cron", "~> 2.3"
gem "pundit", "~> 2.5"
gem "rack-attack", "~> 6.8"
gem "propshaft"
gem "sorbet-runtime", "~> 0.6"
group :development, :test do
  gem "sorbet", "~> 0.6", require: false
  gem "tapioca", "~> 0.20.0", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-performance", require: false
  gem "minitest", "~> 5.25"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
end

# Local module libraries; the host composes them into one application.
gem "hrm_platform", path: "modules/platform"
gem "hrm_identity", path: "modules/identity"
gem "hrm_workforce", path: "modules/workforce"
gem "hrm_attendance", path: "modules/attendance"
gem "hrm_time_off", path: "modules/time_off"
gem "hrm_payroll", path: "modules/payroll"
gem "hrm_recruitment", path: "modules/recruitment"
gem "hrm_audit", path: "modules/audit"
gem "hrm_dashboard", path: "modules/dashboard"

gem "hrm_organization", path: "modules/organization"

gem "hrm_onboarding", path: "modules/onboarding"

gem "hrm_integration", path: "modules/integration"
