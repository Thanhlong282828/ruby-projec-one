# Web: authentication
get    "/session/new", to: "sessions#new",     as: :new_session
delete "/session",     to: "sessions#destroy", as: :session
post   "/session",     to: "sessions#create"

# REST API v1: authentication
delete "/api/v1/session", to: "api/v1/sessions#destroy", as: :api_v1_session
post   "/api/v1/session", to: "api/v1/sessions#create"
