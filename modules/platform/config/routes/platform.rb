# Health check and WebSocket endpoint
get "/up", to: "rails/health#show", as: :rails_health_check
mount ActionCable.server => "/cable"
