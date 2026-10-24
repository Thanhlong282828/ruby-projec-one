# Web: leave requests and review actions
get   "/leave_requests",             to: "time_off/leave_requests#index",   as: :leave_requests
get   "/leave_requests/new",         to: "time_off/leave_requests#new",     as: :new_leave_request
post  "/leave_requests",             to: "time_off/leave_requests#create"
patch "/leave_requests/:id/approve", to: "time_off/leave_requests#approve", as: :approve_leave_request
patch "/leave_requests/:id/reject",  to: "time_off/leave_requests#reject",  as: :reject_leave_request

# REST API v1: leave requests and review actions
get   "/api/v1/leave_requests",             to: "api/v1/leave_requests#index",   as: :api_v1_leave_requests
post  "/api/v1/leave_requests",             to: "api/v1/leave_requests#create"
get   "/api/v1/leave_requests/:id",         to: "api/v1/leave_requests#show",    as: :api_v1_leave_request
patch "/api/v1/leave_requests/:id/approve", to: "api/v1/leave_requests#approve", as: :approve_api_v1_leave_request
patch "/api/v1/leave_requests/:id/reject",  to: "api/v1/leave_requests#reject",  as: :reject_api_v1_leave_request
