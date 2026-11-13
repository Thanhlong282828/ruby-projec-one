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
get "/inventory/warehouses", to: "procurement/warehouses#index", as: :inventory_warehouses
get "/inventory/warehouses/new", to: "procurement/warehouses#new", as: :new_inventory_warehouse
post "/inventory/warehouses", to: "procurement/warehouses#create"
get "/inventory/warehouses/:id/edit", to: "procurement/warehouses#edit", as: :edit_inventory_warehouse
patch "/inventory/warehouses/:id", to: "procurement/warehouses#update", as: :inventory_warehouse
put "/inventory/warehouses/:id", to: "procurement/warehouses#update"
get "/inventory/items", to: "procurement/stock_items#index", as: :inventory_items
get "/inventory/items/new", to: "procurement/stock_items#new", as: :new_inventory_item
post "/inventory/items", to: "procurement/stock_items#create"
get "/inventory/items/:id/edit", to: "procurement/stock_items#edit", as: :edit_inventory_item
patch "/inventory/items/:id", to: "procurement/stock_items#update", as: :inventory_item
put "/inventory/items/:id", to: "procurement/stock_items#update"
get "/inventory/receipts/pending", to: "procurement/stock_receipts#pending", as: :pending_stock_receipts
get "/inventory/receipts", to: "procurement/stock_receipts#index", as: :stock_receipts
get "/inventory/receipts/new", to: "procurement/stock_receipts#new", as: :new_stock_receipt
post "/inventory/receipts", to: "procurement/stock_receipts#create"
get "/inventory/receipts/:id", to: "procurement/stock_receipts#show", as: :stock_receipt
get "/inventory/balances", to: "procurement/stock_balances#index", as: :stock_balances

get "/inventory/ledger", to: "procurement/stock_ledger#index", as: :stock_ledger

get "/inventory/returns", to: "procurement/stock_returns#index", as: :stock_returns
get "/inventory/returns/new", to: "procurement/stock_returns#new", as: :new_stock_return
post "/inventory/returns", to: "procurement/stock_returns#create"
get "/inventory/returns/:id", to: "procurement/stock_returns#show", as: :stock_return

get "/inventory/return-reversals", to: "procurement/stock_return_reversals#index", as: :stock_return_reversals
get "/inventory/return-reversals/new", to: "procurement/stock_return_reversals#new", as: :new_stock_return_reversal
post "/inventory/return-reversals", to: "procurement/stock_return_reversals#create"
get "/inventory/return-reversals/:id", to: "procurement/stock_return_reversals#show", as: :stock_return_reversal
