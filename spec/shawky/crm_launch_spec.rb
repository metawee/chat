require 'rails_helper'

RSpec.describe 'Shawky CRM WhatsApp button', :shawky, type: :request do
  include_context 'with shawky world'
  include_context 'with mock crm'

  let(:lead) do
    Shawky::MockCrm::SAMPLE_LEAD.merge('lead_id' => 'L-555', 'name' => 'منى', 'mobile' => '+966 55 111 2233', 'whatsapp' => '+966 55 111 2233')
  end
  let(:launch_api) { "/api/v1/accounts/#{account.id}/shawky/crm_launch" }

  before do
    configure_routing
    Shawky::CrmUserMapping.create!(account: account, crm_user_id: 'U-77', user: agent)
  end

  def open_chat(chat_lead = lead)
    get '/chat', params: { code: Shawky::MockCrm.issue_code(chat_lead) }
  end

  describe 'GET /chat' do
    it 'resolves the code on the server and sends the browser on without it' do
      open_chat

      expect(response).to have_http_status(:see_other)
      expect(response.location).to end_with("/app/accounts/#{account.id}/shawky/crm-launch")
      expect(response.headers['Referrer-Policy']).to eq('no-referrer')
      expect(response.body).not_to include('111')
      expect(cookies[:shawky_crm_launch]).to be_present
      expect(cookies[:shawky_crm_launch]).not_to include('L-555')
    end

    it 'signs the resolve call to the CRM' do
      request_code = Shawky::MockCrm.issue_code(lead)
      get '/chat', params: { code: request_code }

      expect(WebMock).to(have_requested(:post, 'https://crm.example.com/api/integrations/shawky/resolve').with do |request|
        Shawky::Hmac.valid?(secret: 'crm-secret', timestamp: request.headers['X-Shawky-Timestamp'],
                            signature: request.headers['X-Shawky-Signature'], body: request.body) &&
          request.headers['X-Shawky-Key-Id'] == 'shawky-key' && JSON.parse(request.body) == { 'code' => request_code, 'action' => 'whatsapp' }
      end)
    end

    it 'shows an Arabic error page when the code was already used or expired' do
      code = Shawky::MockCrm.issue_code(lead)
      get '/chat', params: { code: code }
      get '/chat', params: { code: code }

      expect(response).to have_http_status(:gone)
      expect(response.body).to include('انتهت صلاحية هذا الرابط', 'dir="rtl"')
    end

    it 'refuses malformed codes without calling the CRM' do
      get '/chat', params: { code: '<script>' }

      expect(response).to have_http_status(:bad_request)
      expect(WebMock).not_to have_requested(:post, /crm\.example\.com/)
    end

    it 'explains when the CRM user is not linked to anyone here' do
      open_chat(lead.merge('agent' => { 'id' => 'U-unknown' }))

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include('غير مربوط')
    end

    it 'reports a CRM that rejects the call as unavailable' do
      stub_request(:post, 'https://crm.example.com/api/integrations/shawky/resolve').to_return(status: 401)
      open_chat

      expect(response).to have_http_status(:bad_gateway)
    end
  end

  describe 'finishing the launch in the dashboard' do
    it 'opens a conversation for the lead on the active number, assigned to the CRM owner' do
      open_chat
      get launch_api, headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body).to eq('pending' => true)

      post launch_api, headers: agent.create_new_auth_token, as: :json

      conversation = account.conversations.find_by!(display_id: response.parsed_body['conversation_id'])
      expect(response.parsed_body['needs_template']).to be(true)
      expect([conversation.inbox, conversation.assignee]).to eq([inbox, agent])
      expect(response.body).not_to leak_phone('+966551112233')
    end

    it 'stores the lead on the contact and audits the launch without the number' do
      open_chat
      post launch_api, headers: agent.create_new_auth_token, as: :json

      contact = account.conversations.find_by!(display_id: response.parsed_body['conversation_id']).contact
      expect([contact.phone_number, contact.name]).to eq(['+966551112233', 'منى'])
      expect(contact.custom_attributes).to include('lead_id' => 'L-555', 'project' => 'طنطا', 'area_sqm' => 120)

      log = Shawky::AuditLog.find_by!(action: 'crm_launch')
      expect(log.metadata).to eq('lead_id' => 'L-555', 'crm_agent_id' => 'U-77')
      expect(log.user).to eq(agent)
    end

    it 'can be used once only' do
      open_chat
      post launch_api, headers: agent.create_new_auth_token, as: :json
      post launch_api, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:gone)
    end

    it 'reuses the open conversation and takes it back for the CRM owner' do
      conversation.update!(assignee: teammate)
      open_chat(lead.merge('mobile' => customer_phone, 'whatsapp' => customer_phone))

      post launch_api, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['conversation_id']).to eq(conversation.display_id)
      expect(response.parsed_body['needs_template']).to be(false)
      expect(conversation.reload.assignee).to eq(agent)
      expect(Shawky::AuditLog.find_by!(action: 'conversation_reassigned').metadata).to include('source' => 'crm_launch')
    end

    it 'lets the supervisor open it without taking it over' do
      open_chat
      post launch_api, headers: supervisor.create_new_auth_token, as: :json

      expect(account.conversations.find_by!(display_id: response.parsed_body['conversation_id']).assignee).to eq(agent)
    end

    it 'refuses anyone else' do
      open_chat
      post launch_api, headers: outsider.create_new_auth_token, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(account.contacts.find_by(phone_number: '+966551112233')).to be_nil
    end

    it 'uses the backup number after a failover' do
      Shawky::Routing.new(account.reload).failover!(reason: 'test')
      open_chat
      post launch_api, headers: agent.create_new_auth_token, as: :json

      expect(account.conversations.find_by!(display_id: response.parsed_body['conversation_id']).inbox).to eq(backup_inbox)
    end
  end
end
