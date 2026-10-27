# Payroll: list, create, inspect and finalize
get   "/pay_runs",              to: "payroll/pay_runs#index",    as: :pay_runs
get   "/pay_runs/new",          to: "payroll/pay_runs#new",      as: :new_pay_run
post  "/pay_runs",              to: "payroll/pay_runs#create"
get   "/pay_runs/:id",          to: "payroll/pay_runs#show",     as: :pay_run
patch "/pay_runs/:id/finalize", to: "payroll/pay_runs#finalize", as: :finalize_pay_run
