get "/organization/branches", to: "organization/branches#index"
post "/organization/branches", to: "organization/branches#create"
get "/api/v1/organization/branches", to: "api/v1/branches#index"
post "/api/v1/organization/branches", to: "api/v1/branches#create"
get "/organization/tree", to: "organization/structure#tree", as: :organization_tree
get "/organization/headcount", to: "organization/structure#headcount", as: :organization_headcount
get "/api/v1/organization/tree", to: "api/v1/organization_structure#tree"
get "/api/v1/organization/headcount", to: "api/v1/organization_structure#headcount"
get "/organization/cost-centers/export", to: "organization/records#export", defaults: { resource: "cost_centers" }
get "/organization/cost-centers/new", to: "organization/records#new", defaults: { resource: "cost_centers" }
get "/organization/cost-centers", to: "organization/records#index", defaults: { resource: "cost_centers" }
post "/organization/cost-centers", to: "organization/records#create", defaults: { resource: "cost_centers" }
get "/organization/cost-centers/:id/edit", to: "organization/records#edit", defaults: { resource: "cost_centers" }
get "/organization/cost-centers/:id", to: "organization/records#show", defaults: { resource: "cost_centers" }
patch "/organization/cost-centers/:id", to: "organization/records#update", defaults: { resource: "cost_centers" }
put "/organization/cost-centers/:id", to: "organization/records#update", defaults: { resource: "cost_centers" }
delete "/organization/cost-centers/:id", to: "organization/records#destroy", defaults: { resource: "cost_centers" }
get "/api/v1/organization/cost-centers", to: "api/v1/organization_records#index", defaults: { resource: "cost_centers" }
post "/api/v1/organization/cost-centers", to: "api/v1/organization_records#create", defaults: { resource: "cost_centers" }
get "/api/v1/organization/cost-centers/:id", to: "api/v1/organization_records#show", defaults: { resource: "cost_centers" }
patch "/api/v1/organization/cost-centers/:id", to: "api/v1/organization_records#update", defaults: { resource: "cost_centers" }
put "/api/v1/organization/cost-centers/:id", to: "api/v1/organization_records#update", defaults: { resource: "cost_centers" }
delete "/api/v1/organization/cost-centers/:id", to: "api/v1/organization_records#destroy", defaults: { resource: "cost_centers" }
get "/organization/organization-units/export", to: "organization/records#export", defaults: { resource: "organization_units" }
get "/organization/organization-units/new", to: "organization/records#new", defaults: { resource: "organization_units" }
get "/organization/organization-units", to: "organization/records#index", defaults: { resource: "organization_units" }
post "/organization/organization-units", to: "organization/records#create", defaults: { resource: "organization_units" }
get "/organization/organization-units/:id/edit", to: "organization/records#edit", defaults: { resource: "organization_units" }
get "/organization/organization-units/:id", to: "organization/records#show", defaults: { resource: "organization_units" }
patch "/organization/organization-units/:id", to: "organization/records#update", defaults: { resource: "organization_units" }
put "/organization/organization-units/:id", to: "organization/records#update", defaults: { resource: "organization_units" }
delete "/organization/organization-units/:id", to: "organization/records#destroy", defaults: { resource: "organization_units" }
get "/api/v1/organization/organization-units", to: "api/v1/organization_records#index", defaults: { resource: "organization_units" }
post "/api/v1/organization/organization-units", to: "api/v1/organization_records#create", defaults: { resource: "organization_units" }
get "/api/v1/organization/organization-units/:id", to: "api/v1/organization_records#show", defaults: { resource: "organization_units" }
patch "/api/v1/organization/organization-units/:id", to: "api/v1/organization_records#update", defaults: { resource: "organization_units" }
put "/api/v1/organization/organization-units/:id", to: "api/v1/organization_records#update", defaults: { resource: "organization_units" }
delete "/api/v1/organization/organization-units/:id", to: "api/v1/organization_records#destroy", defaults: { resource: "organization_units" }
get "/organization/job-positions/export", to: "organization/records#export", defaults: { resource: "job_positions" }
get "/organization/job-positions/new", to: "organization/records#new", defaults: { resource: "job_positions" }
get "/organization/job-positions", to: "organization/records#index", defaults: { resource: "job_positions" }
post "/organization/job-positions", to: "organization/records#create", defaults: { resource: "job_positions" }
get "/organization/job-positions/:id/edit", to: "organization/records#edit", defaults: { resource: "job_positions" }
get "/organization/job-positions/:id", to: "organization/records#show", defaults: { resource: "job_positions" }
patch "/organization/job-positions/:id", to: "organization/records#update", defaults: { resource: "job_positions" }
put "/organization/job-positions/:id", to: "organization/records#update", defaults: { resource: "job_positions" }
delete "/organization/job-positions/:id", to: "organization/records#destroy", defaults: { resource: "job_positions" }
get "/api/v1/organization/job-positions", to: "api/v1/organization_records#index", defaults: { resource: "job_positions" }
post "/api/v1/organization/job-positions", to: "api/v1/organization_records#create", defaults: { resource: "job_positions" }
get "/api/v1/organization/job-positions/:id", to: "api/v1/organization_records#show", defaults: { resource: "job_positions" }
patch "/api/v1/organization/job-positions/:id", to: "api/v1/organization_records#update", defaults: { resource: "job_positions" }
put "/api/v1/organization/job-positions/:id", to: "api/v1/organization_records#update", defaults: { resource: "job_positions" }
delete "/api/v1/organization/job-positions/:id", to: "api/v1/organization_records#destroy", defaults: { resource: "job_positions" }
get "/organization/employee-assignments/export", to: "organization/records#export", defaults: { resource: "employee_assignments" }
get "/organization/employee-assignments/new", to: "organization/records#new", defaults: { resource: "employee_assignments" }
get "/organization/employee-assignments", to: "organization/records#index", defaults: { resource: "employee_assignments" }
post "/organization/employee-assignments", to: "organization/records#create", defaults: { resource: "employee_assignments" }
get "/organization/employee-assignments/:id/edit", to: "organization/records#edit", defaults: { resource: "employee_assignments" }
get "/organization/employee-assignments/:id", to: "organization/records#show", defaults: { resource: "employee_assignments" }
patch "/organization/employee-assignments/:id", to: "organization/records#update", defaults: { resource: "employee_assignments" }
put "/organization/employee-assignments/:id", to: "organization/records#update", defaults: { resource: "employee_assignments" }
delete "/organization/employee-assignments/:id", to: "organization/records#destroy", defaults: { resource: "employee_assignments" }
get "/api/v1/organization/employee-assignments", to: "api/v1/organization_records#index", defaults: { resource: "employee_assignments" }
post "/api/v1/organization/employee-assignments", to: "api/v1/organization_records#create", defaults: { resource: "employee_assignments" }
get "/api/v1/organization/employee-assignments/:id", to: "api/v1/organization_records#show", defaults: { resource: "employee_assignments" }
patch "/api/v1/organization/employee-assignments/:id", to: "api/v1/organization_records#update", defaults: { resource: "employee_assignments" }
put "/api/v1/organization/employee-assignments/:id", to: "api/v1/organization_records#update", defaults: { resource: "employee_assignments" }
delete "/api/v1/organization/employee-assignments/:id", to: "api/v1/organization_records#destroy", defaults: { resource: "employee_assignments" }
