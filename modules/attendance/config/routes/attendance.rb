resources :attendances, only: [:index, :create] do
  patch :checkout, on: :member
end
