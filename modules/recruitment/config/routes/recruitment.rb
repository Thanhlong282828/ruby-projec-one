# Recruitment: candidate pipeline
get   "/candidates",          to: "recruitment/candidates#index",  as: :candidates
get   "/candidates/new",      to: "recruitment/candidates#new",    as: :new_candidate
post  "/candidates",          to: "recruitment/candidates#create"
get   "/candidates/:id/edit", to: "recruitment/candidates#edit",   as: :edit_candidate
patch "/candidates/:id",      to: "recruitment/candidates#update", as: :candidate
put   "/candidates/:id",      to: "recruitment/candidates#update"
