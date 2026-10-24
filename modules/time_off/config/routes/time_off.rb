resources :leave_requests, module: :time_off, only: [:index, :new, :create] do
  patch :approve, on: :member
  patch :reject, on: :member
end
namespace :api do
  namespace :v1 do
    resources :leave_requests, only: [:index, :show, :create] do
      patch :approve, on: :member
      patch :reject, on: :member
    end
  end
end
