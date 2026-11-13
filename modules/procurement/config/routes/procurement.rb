get "/procurement/requests", to: "procurement/requests#index", as: :purchase_requests
get "/procurement/requests/new", to: "procurement/requests#new", as: :new_purchase_request
post "/procurement/requests", to: "procurement/requests#create"
get "/procurement/requests/:id/edit", to: "procurement/requests#edit", as: :edit_purchase_request
get "/procurement/requests/:id", to: "procurement/requests#show", as: :purchase_request
patch "/procurement/requests/:id", to: "procurement/requests#update"
put "/procurement/requests/:id", to: "procurement/requests#update"
post "/procurement/requests/:id/submit", to: "procurement/requests#submit", as: :submit_purchase_request
post "/procurement/requests/:id/decision", to: "procurement/requests#decision", as: :decide_purchase_request
get "/procurement/suppliers", to: "procurement/suppliers#index", as: :procurement_suppliers
get "/procurement/suppliers/new", to: "procurement/suppliers#new", as: :new_procurement_supplier
post "/procurement/suppliers", to: "procurement/suppliers#create"
get "/procurement/suppliers/:id/edit", to: "procurement/suppliers#edit", as: :edit_procurement_supplier
patch "/procurement/suppliers/:id", to: "procurement/suppliers#update", as: :procurement_supplier
put "/procurement/suppliers/:id", to: "procurement/suppliers#update"
get "/procurement/orders", to: "procurement/orders#index", as: :purchase_orders
get "/procurement/orders/new", to: "procurement/orders#new", as: :new_purchase_order
post "/procurement/orders", to: "procurement/orders#create"
get "/procurement/orders/:id/edit", to: "procurement/orders#edit", as: :edit_purchase_order
patch "/procurement/orders/:id", to: "procurement/orders#update"
put "/procurement/orders/:id", to: "procurement/orders#update"
get "/procurement/orders/:id", to: "procurement/orders#show", as: :purchase_order
post "/procurement/orders/:id/issue", to: "procurement/orders#issue", as: :issue_purchase_order
get "/procurement/receipts", to: "procurement/receipts#index", as: :goods_receipts
get "/procurement/receipts/new", to: "procurement/receipts#new", as: :new_goods_receipt
post "/procurement/receipts", to: "procurement/receipts#create"
get "/procurement/receipts/:id", to: "procurement/receipts#show", as: :goods_receipt
