require 'rails_helper'

RSpec.describe ShawkyAdminIpAllowlist, :shawky, type: :request do
  around { |example| ClimateControl.modify(SHAWKY_SUPER_ADMIN_ALLOWED_IPS: '10.9.9.9') { example.run } }

  it 'hides super admin and sidekiq from other IPs' do
    get '/super_admin/sign_in'
    expect(response).to have_http_status(:not_found)

    get '/monitoring/sidekiq'
    expect(response).to have_http_status(:not_found)
  end

  it 'lets the CWS IP through to the app' do
    get '/super_admin/sign_in', env: { 'REMOTE_ADDR' => '10.9.9.9' }
    expect(response).not_to have_http_status(:not_found)
  end

  it 'can switch the Sidekiq dashboard off completely' do
    ClimateControl.modify(SHAWKY_DISABLE_SIDEKIQ_WEB: 'true') do
      get '/monitoring/sidekiq', env: { 'REMOTE_ADDR' => '10.9.9.9' }
    end
    expect(response).to have_http_status(:not_found)
  end
end
