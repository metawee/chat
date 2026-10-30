# Shawky Group customizations (see docs/shawky/PLAN.md).
namespace :api, defaults: { format: 'json' } do
  namespace :v1 do
    resources :accounts, only: [] do
      scope module: :accounts do
        namespace :shawky do
          resources :contacts, only: [] do
            get :phone, to: 'contact_phones#show'
          end
          resources :team_supervisors, only: [:index, :create, :destroy]
          resource :settings, only: [:show, :update]
        end
      end
    end
  end
end
