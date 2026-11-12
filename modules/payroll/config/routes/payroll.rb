get "/payroll/exports", to: "payroll/exports#index"
post "/payroll/exports", to: "payroll/exports#create"
get "/payroll/exports/:id/download", to: "payroll/exports#download"
get "/payroll/exports/:id", to: "payroll/exports#show"
get "/api/v1/payroll/exports", to: "api/v1/payroll_exports#index"
post "/api/v1/payroll/exports", to: "api/v1/payroll_exports#create"
get "/api/v1/payroll/exports/:id/download", to: "api/v1/payroll_exports#download"
get "/api/v1/payroll/exports/:id", to: "api/v1/payroll_exports#show"
# Payroll: list, create, inspect and finalize
get   "/pay_runs",              to: "payroll/pay_runs#index",    as: :pay_runs
get   "/pay_runs/new",          to: "payroll/pay_runs#new",      as: :new_pay_run
post  "/pay_runs",              to: "payroll/pay_runs#create"
get   "/pay_runs/:id",          to: "payroll/pay_runs#show",     as: :pay_run
patch "/pay_runs/:id/finalize", to: "payroll/pay_runs#finalize", as: :finalize_pay_run
