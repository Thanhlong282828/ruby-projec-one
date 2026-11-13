get "/procurement/requests", to: "procurement/requests#index", as: :purchase_requests
get "/procurement/requests/new", to: "procurement/requests#new", as: :new_purchase_request
post "/procurement/requests", to: "procurement/requests#create"
get "/procurement/requests/:id/edit", to: "procurement/requests#edit", as: :edit_purchase_request
get "/procurement/requests/:id", to: "procurement/requests#show", as: :purchase_request
patch "/procurement/requests/:id", to: "procurement/requests#update"
put "/procurement/requests/:id", to: "procurement/requests#update"
post "/procurement/requests/:id/submit", to: "procurement/requests#submit", as: :submit_purchase_request
post "/procurement/requests/:id/decision", to: "procurement/requests#decision", as: :decide_purchase_request
