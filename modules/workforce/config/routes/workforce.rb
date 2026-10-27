# Web: employee records (specific paths precede /:id)
get    "/employees",          to: "workforce/employees#index",   as: :employees
get    "/employees/new",      to: "workforce/employees#new",     as: :new_employee
post   "/employees",          to: "workforce/employees#create"
get    "/employees/:id/edit", to: "workforce/employees#edit",    as: :edit_employee
get    "/employees/:id",      to: "workforce/employees#show",    as: :employee
patch  "/employees/:id",      to: "workforce/employees#update"
put    "/employees/:id",      to: "workforce/employees#update"
delete "/employees/:id",      to: "workforce/employees#destroy"

# Web: departments
get    "/departments",          to: "workforce/departments#index",   as: :departments
get    "/departments/new",      to: "workforce/departments#new",     as: :new_department
post   "/departments",          to: "workforce/departments#create"
get    "/departments/:id/edit", to: "workforce/departments#edit",    as: :edit_department
patch  "/departments/:id",      to: "workforce/departments#update",  as: :department
put    "/departments/:id",      to: "workforce/departments#update"
delete "/departments/:id",      to: "workforce/departments#destroy"

# REST API v1: employees
get    "/api/v1/employees",          to: "api/v1/employees#index",   as: :api_v1_employees
get    "/api/v1/employees/new",      to: "api/v1/employees#new",     as: :new_api_v1_employee
post   "/api/v1/employees",          to: "api/v1/employees#create"
get    "/api/v1/employees/:id/edit", to: "api/v1/employees#edit",    as: :edit_api_v1_employee
get    "/api/v1/employees/:id",      to: "api/v1/employees#show",    as: :api_v1_employee
patch  "/api/v1/employees/:id",      to: "api/v1/employees#update"
put    "/api/v1/employees/:id",      to: "api/v1/employees#update"
delete "/api/v1/employees/:id",      to: "api/v1/employees#destroy"

# REST API v1: departments
get    "/api/v1/departments",     to: "api/v1/departments#index",   as: :api_v1_departments
post   "/api/v1/departments",     to: "api/v1/departments#create"
get    "/api/v1/departments/:id", to: "api/v1/departments#show",    as: :api_v1_department
patch  "/api/v1/departments/:id", to: "api/v1/departments#update"
put    "/api/v1/departments/:id", to: "api/v1/departments#update"
delete "/api/v1/departments/:id", to: "api/v1/departments#destroy"
