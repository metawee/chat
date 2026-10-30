# Shawky Group customizations (see docs/shawky/PLAN.md).
namespace :api, defaults: { format: 'json' } do
  namespace :v1 do
    resources :accounts, only: [] do
      scope module: :accounts do
        namespace :shawky do
          resources :contacts, only: [] do
            get :phone, to: 'contact_phones#show'
          end
          resources :conversations, only: [] do
            post :continue_on_active_number
          end
          resources :team_supervisors, only: [:index, :create, :destroy]
          resources :crm_user_mappings, only: [:index, :create, :destroy]
          resource :settings, only: [:show, :update] do
            post :failback
          end
          resource :routing, only: [:show], controller: 'routing'
        end
      end
    end
  end
end

namespace :shawky do
  namespace :hooks do
    post 'n8n/crm_owner', to: 'n8n#crm_owner'
  end
end
