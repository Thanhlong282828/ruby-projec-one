# Attendance: list, clock in, clock out
get   "/attendances",              to: "attendances#index",    as: :attendances
post  "/attendances",              to: "attendances#create"
patch "/attendances/:id/checkout", to: "attendances#checkout", as: :checkout_attendance

get "/attendances/report", to: "attendance_reports#show", as: :attendance_report
get "/api/v1/attendances/report", to: "api/v1/attendance_reports#show"

# Work shift configuration and read-only attendance preview — explicit routes.
get "/work_shifts", to: "work_shifts#index", as: :work_shifts
get "/work_shifts/new", to: "work_shifts#new", as: :new_work_shift
post "/work_shifts", to: "work_shifts#create"
get "/work_shifts/:id/edit", to: "work_shifts#edit", as: :edit_work_shift
get "/work_shifts/:id/preview", to: "work_shifts#preview", as: :preview_work_shift
get "/work_shifts/:id", to: "work_shifts#show", as: :work_shift
patch "/work_shifts/:id", to: "work_shifts#update"
put "/work_shifts/:id", to: "work_shifts#update"
delete "/work_shifts/:id", to: "work_shifts#destroy"
get "/api/v1/work_shifts", to: "api/v1/work_shifts#index"
post "/api/v1/work_shifts", to: "api/v1/work_shifts#create"
get "/api/v1/work_shifts/:id/preview", to: "api/v1/work_shifts#preview"
get "/api/v1/work_shifts/:id", to: "api/v1/work_shifts#show"
patch "/api/v1/work_shifts/:id", to: "api/v1/work_shifts#update"
put "/api/v1/work_shifts/:id", to: "api/v1/work_shifts#update"
delete "/api/v1/work_shifts/:id", to: "api/v1/work_shifts#destroy"

# Fixed shift assignment interval and read-only schedule.
get "/shift_assignments", to: "shift_assignments#index", as: :shift_assignments
get "/shift_assignments/new", to: "shift_assignments#new", as: :new_shift_assignment
get "/shift_assignments/schedule", to: "shift_assignments#schedule", as: :employee_shift_schedule
post "/shift_assignments", to: "shift_assignments#create"
get "/shift_assignments/:id/edit", to: "shift_assignments#edit", as: :edit_shift_assignment
get "/shift_assignments/:id", to: "shift_assignments#show", as: :shift_assignment
patch "/shift_assignments/:id", to: "shift_assignments#update"
put "/shift_assignments/:id", to: "shift_assignments#update"
delete "/shift_assignments/:id", to: "shift_assignments#destroy"
get "/api/v1/shift_assignments", to: "api/v1/shift_assignments#index"
get "/api/v1/shift_assignments/schedule", to: "api/v1/shift_assignments#schedule"
post "/api/v1/shift_assignments", to: "api/v1/shift_assignments#create"
get "/api/v1/shift_assignments/:id", to: "api/v1/shift_assignments#show"
patch "/api/v1/shift_assignments/:id", to: "api/v1/shift_assignments#update"
put "/api/v1/shift_assignments/:id", to: "api/v1/shift_assignments#update"
delete "/api/v1/shift_assignments/:id", to: "api/v1/shift_assignments#destroy"
get "/attendances/:id", to: "attendances#show", as: :attendance
