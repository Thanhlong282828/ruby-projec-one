resource :session, only: [:new, :create, :destroy]
namespace :api do
  namespace :v1 do
    resource :session, only: [:create, :destroy]
  end
end
