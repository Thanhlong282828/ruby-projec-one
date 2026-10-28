# Web: authentication
get    "/session/new", to: "sessions#new",     as: :new_session
delete "/session",     to: "sessions#destroy", as: :session
post   "/session",     to: "sessions#create"

# REST API v1: authentication
delete "/api/v1/session", to: "api/v1/sessions#destroy", as: :api_v1_session
post   "/api/v1/session", to: "api/v1/sessions#create"

# Company administration: always scoped to the authenticated account's company.
get   "/manage/company", to: "administration#company", as: :administration_company
patch "/manage/company", to: "administration#save_company"
get   "/manage/accounts", to: "administration#accounts", as: :administration_accounts
get   "/manage/accounts/:id", to: "administration#account", as: :administration_account
patch "/manage/accounts/:id", to: "administration#save_account"
post  "/manage/roles", to: "administration#save_role"
get   "/manage/roles", to: "administration#roles", as: :administration_roles
patch "/manage/roles/:id", to: "administration#save_role", as: :administration_role
get   "/api/v1/company", to: "api/v1/administration#company"
patch "/api/v1/company", to: "api/v1/administration#save_company"
get   "/api/v1/accounts", to: "api/v1/administration#accounts"
patch "/api/v1/accounts/:id", to: "api/v1/administration#save_account"
post  "/api/v1/roles", to: "api/v1/administration#save_role"
get   "/api/v1/roles", to: "api/v1/administration#roles"
patch "/api/v1/roles/:id", to: "api/v1/administration#save_role"
