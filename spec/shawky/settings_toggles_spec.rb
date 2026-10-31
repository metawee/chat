require 'rails_helper'

RSpec.describe 'Shawky settings switches', :shawky, type: :request do
  include_context 'with shawky world'

  let(:base) { "/api/v1/accounts/#{account.id}" }
  let(:settings_path) { "#{base}/shawky/settings" }

  before { conversation }

  def toggle(params)
    patch settings_path, headers: admin.create_new_auth_token, as: :json, params: params
  end

  def agent_contact_phone
    get "#{base}/contacts/#{contact.id}", headers: agent.create_new_auth_token, as: :json
    response.parsed_body.dig('payload', 'phone_number')
  end

  it 'is off by default for a new account' do
    fresh = create(:account)

    expect(Shawky::PhoneMask.enabled?(fresh)).to be(false)
    expect(Shawky::Settings.enabled?(fresh, :restricted_visibility)).to be(true)
    expect(Shawky::Settings.enabled?(fresh, :gateway_launch)).to be(true)
  end

  describe 'phone masking off' do
    before { toggle(phone_masking_enabled: false) }

    it 'shows numbers like stock Chatwoot and lets agents search by phone' do
      expect(agent_contact_phone).to eq(customer_phone)

      get "#{base}/contacts/search", headers: agent.create_new_auth_token, params: { q: '542921' }, as: :json
      expect(response.parsed_body['payload'].pluck('id')).to eq([contact.id])
    end

    it 'sends realtime payloads unmasked' do
      allow(ActionCable.server).to receive(:broadcast)
      ActionCableBroadcastJob.perform_now([agent.pubsub_token], 'contact.updated', contact.push_event_data.merge(account_id: account.id))

      expect(ActionCable.server).to have_received(:broadcast).with(anything, satisfy { |payload| payload.to_json.include?('542921') })
    end

    it 'keeps role visibility on' do
      other = create(:conversation, account: account, inbox: inbox, assignee: outsider)
      get "#{base}/conversations/#{other.display_id}", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'applies a masking change on the next request and broadcast, without a restart' do
    expect(agent_contact_phone).not_to eq(customer_phone)

    toggle(phone_masking_enabled: false)
    expect(agent_contact_phone).to eq(customer_phone)

    toggle(phone_masking_enabled: true)
    expect(agent_contact_phone).to end_with('507').and include('•')

    allow(ActionCable.server).to receive(:broadcast)
    ActionCableBroadcastJob.perform_now([agent.pubsub_token], 'contact.updated', contact.push_event_data.merge(account_id: account.id))
    expect(ActionCable.server).not_to have_received(:broadcast).with(anything, satisfy { |payload| payload.to_json.include?('542921') })
  end

  it 'audits every change with the old and new value' do
    toggle(phone_masking_enabled: false, restricted_visibility_enabled: false)

    logs = Shawky::AuditLog.where(action: 'settings_changed', user: admin)
    expect(logs.map(&:metadata)).to contain_exactly(
      { 'key' => 'shawky_phone_masking_enabled', 'old' => true, 'new' => false },
      { 'key' => 'shawky_restricted_visibility_enabled', 'old' => nil, 'new' => false }
    )
  end

  it 'falls back to inbox visibility when restricted visibility is off' do
    other = create(:conversation, account: account, inbox: inbox, assignee: outsider)
    toggle(restricted_visibility_enabled: false)

    get "#{base}/conversations/#{other.display_id}", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
  end

  it 'turns the gateway launch off' do
    toggle(gateway_launch_enabled: false)
    Shawky::CrmUserMapping.create!(account: account, crm_username: 'rawda', user: agent)
    stub_request(:get, %r{gateway\.example\.com/api/sessions/})
      .to_return(status: 200, body: { lead: { phone: '+201289758825',
                                              salesman: 'rawda' } }.to_json, headers: { 'Content-Type' => 'application/json' })

    ClimateControl.modify(SHAWKY_GATEWAY_URL: 'https://gateway.example.com', SHAWKY_GATEWAY_API_KEY: 'k') do
      get '/shawky/launch', params: { session: 's_abcdefgh1234' }
    end
    expect(response).to have_http_status(:not_found)
  end

  it 'reports the gateway health and is admin-only' do
    stub_request(:get, 'https://gateway.example.com/health').to_return(status: 200, body: '{"status":"ok"}')
    ClimateControl.modify(SHAWKY_GATEWAY_URL: 'https://gateway.example.com', SHAWKY_GATEWAY_API_KEY: 'k') do
      get "#{settings_path}/gateway_health", headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body).to eq('ok' => true)

      get "#{settings_path}/gateway_health", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'refuses non-admins' do
    patch settings_path, headers: supervisor.create_new_auth_token, as: :json, params: { phone_masking_enabled: false }

    expect(response).to have_http_status(:unauthorized)
    expect(Shawky::PhoneMask.enabled?(account.reload)).to be(true)
  end
end
