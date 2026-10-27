# Attendance: list, clock in, clock out
get   "/attendances",              to: "attendances#index",    as: :attendances
post  "/attendances",              to: "attendances#create"
patch "/attendances/:id/checkout", to: "attendances#checkout", as: :checkout_attendance
