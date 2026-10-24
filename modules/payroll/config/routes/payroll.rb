resources :pay_runs, module: :payroll, only: [:index, :new, :create, :show] do
  patch :finalize, on: :member
end
