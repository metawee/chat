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
            get :gateway_health
          end
          resource :routing, only: [:show], controller: 'routing'
          resource :crm_launch, only: [:show, :create]
          resources :follow_ups, only: [:index]
          resources :data_exports, only: [:index, :create]
          get 'reports/costs', to: 'cost_reports#show'
        end
      end
    end
  end
end

get 'shawky/launch', to: 'shawky/launches#show'
mount Shawky::MockGateway, at: '/mock_gateway' if ActiveModel::Type::Boolean.new.cast(ENV.fetch('SHAWKY_MOCK_GATEWAY', false))
mount Shawky::MockCrm, at: '/mock_crm' if ActiveModel::Type::Boolean.new.cast(ENV.fetch('SHAWKY_MOCK_CRM', false))

namespace :shawky do
  namespace :hooks do
    post 'n8n/crm_owner', to: 'n8n#crm_owner'
  end
end
