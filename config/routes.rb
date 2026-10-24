Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "dashboard#index"
  resource :session, only: [:new, :create, :destroy]
  resources :employees, module: :workforce
  resources :departments, module: :workforce, except: [:show]
  resources :leave_requests, module: :time_off, only: [:index, :new, :create] do
    patch :approve, on: :member
    patch :reject, on: :member
  end
  resources :attendances, only: [:index, :create] do
    patch :checkout, on: :member
  end
  resources :pay_runs, module: :payroll, only: [:index, :new, :create, :show] do
    patch :finalize, on: :member
  end
  resources :candidates, module: :recruitment, except: [:show, :destroy]
  resources :audit_logs, only: :index
  namespace :api do
    namespace :v1 do
      resource :session, only: [:create, :destroy]
      resources :employees
      resources :departments, except: [:new, :edit]
      resources :leave_requests, only: [:index, :show, :create] do
        patch :approve, on: :member
        patch :reject, on: :member
      end
    end
  end
  mount ActionCable.server => "/cable"
end
