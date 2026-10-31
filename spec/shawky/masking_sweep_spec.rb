require 'rails_helper'

# Walks every GET endpoint of the account APIs (v1 and v2) as each role and with both
# auth styles the web and mobile apps use, and checks no full customer number comes back.
RSpec.describe 'Shawky phone masking sweep', :shawky, type: :request do
  include_context 'with shawky world'

  let(:message) { conversation.messages.first }
  let(:segment_ids) do
    {
      'conversations' => conversation.display_id, 'contacts' => contact.id, 'inboxes' => inbox.id,
      'teams' => team.id, 'messages' => message.id, 'agents' => agent.id
    }
  end
  let(:param_values) do
    {
      'account_id' => account.id, 'conversation_id' => conversation.display_id, 'contact_id' => contact.id,
      'inbox_id' => inbox.id, 'team_id' => team.id, 'message_id' => message.id
    }
  end

  # The audited reveal endpoint is the one deliberate exception (covered below).
  let(:reveal_route) { '/api/v1/accounts/:account_id/shawky/contacts/:contact_id/phone' }

  def account_get_routes
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.sub('(.:format)', '')
      next unless route.verb == 'GET' && path.match?(%r{\A/api/v[12]/accounts/:account_id/}) && path != reveal_route

      path
    end.uniq
  end

  def fill(path)
    segments = path.split('/')
    filled = segments.each_with_index.map do |segment, index|
      next segment unless segment.start_with?(':')

      name = segment.delete_prefix(':')
      value = name == 'id' ? segment_ids[segments[index - 1]] : param_values[name]
      return nil if value.nil?

      value
    end
    filled.join('/')
  end

  def sweep(headers)
    checked = []
    account_get_routes.each do |route_path|
      path = fill(route_path)
      next if path.nil?

      begin
        get path, headers: headers, params: { q: '5', since: 1.day.ago.to_i, until: 1.day.from_now.to_i }
      rescue StandardError
        next
      end
      next unless response.successful?

      checked << path
      expect(response.body).not_to leak_phone(customer_phone), "#{path} leaked the customer phone number"
    end
    checked
  end

  before do
    conversation
    contact.update!(custom_attributes: { 'crm_lead_id' => 'L-104582' })
  end

  it 'masks every endpoint for an agent (dashboard auth)' do
    checked = sweep(agent.create_new_auth_token)

    expect(checked).to include(
      "/api/v1/accounts/#{account.id}/conversations", "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
      "/api/v1/accounts/#{account.id}/contacts/#{contact.id}", "/api/v1/accounts/#{account.id}/search"
    )
  end

  it 'masks every endpoint for an agent using an API access token (mobile and integrations)' do
    expect(sweep({ 'api_access_token' => agent.access_token.token }).size).to be > 20
  end

  it 'masks every endpoint for a supervisor' do
    expect(sweep(supervisor.create_new_auth_token).size).to be > 20
  end

  it 'masks every endpoint for an administrator too' do
    checked = sweep(admin.create_new_auth_token)

    expect(checked).to include("/api/v1/accounts/#{account.id}/contacts", "/api/v1/accounts/#{account.id}/inboxes")
  end

  it 'still shows the company own number to administrators' do
    get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['phone_number']).to eq('+201212239999')
  end

  it 'masks the customer phone in the CSAT CSV download' do
    create(:csat_survey_response, account: account, conversation: conversation, contact: contact,
                                  message: message, assigned_agent: agent)

    get "/api/v1/accounts/#{account.id}/csat_survey_responses/download", headers: admin.create_new_auth_token,
                                                                         params: { since: 1.day.ago.to_i.to_s, until: 1.day.from_now.to_i.to_s }

    expect(response.media_type).to eq('text/csv'), "status #{response.status}: #{response.body.first(300)}"
    expect(response.body).to include('507')
    expect(response.body).not_to leak_phone(customer_phone)
  end

  describe 'revealing a number' do
    let(:reveal_path) { "/api/v1/accounts/#{account.id}/shawky/contacts/#{contact.id}/phone" }

    it 'gives the full number to an administrator and audits it' do
      get reveal_path, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['phone_number']).to eq(customer_phone)
      expect(Shawky::AuditLog.where(action: 'phone_revealed', auditable: contact, user: admin)).to exist
    end

    it 'refuses agents and supervisors' do
      [agent, supervisor].each do |user|
        get reveal_path, headers: user.create_new_auth_token, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
      expect(Shawky::AuditLog.where(action: 'phone_revealed')).to be_empty
    end
  end

  describe 'mask mode' do
    it 'hides the number completely when the administrator chooses it' do
      patch "/api/v1/accounts/#{account.id}/shawky/settings", headers: admin.create_new_auth_token,
                                                              params: { phone_mask_mode: 'hidden' }, as: :json

      get "/api/v1/accounts/#{account.id}/contacts/#{contact.id}", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body.dig('payload', 'phone_number')).to eq('••••••••')
    end

    it 'does not let agents change it' do
      patch "/api/v1/accounts/#{account.id}/shawky/settings", headers: agent.create_new_auth_token,
                                                              params: { phone_mask_mode: 'hidden' }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
