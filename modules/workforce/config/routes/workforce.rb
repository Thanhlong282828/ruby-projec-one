resources :employees, module: :workforce
resources :departments, module: :workforce, except: [:show]
namespace :api do
  namespace :v1 do
    resources :employees
    resources :departments, except: [:new, :edit]
  end
end
