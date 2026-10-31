require 'rails_helper'

RSpec.describe 'Shawky gateway WhatsApp launch', :shawky, type: :request do
  include_context 'with shawky world'
  include_context 'with mock gateway'

  let(:lead) do
    { 'name' => 'زياد', 'phone' => '+201289758825', 'salesman' => 'rawda', 'project' => 'الإسكندرية', 'status' => 'Fresh',
      'channel' => 'شيفت نهار', 'created_at' => '10/31/26, 5:21 PM', 'site_state' => 'طوب احمر', 'area' => '60',
      'cs_agent' => '', 'lead_id' => '', 'extra' => { 'budget' => '2M' } }
  end
  let(:launch_api) { "/api/v1/accounts/#{account.id}/shawky/crm_launch" }

  before do
    configure_routing
    Shawky::CrmUserMapping.create!(account: account, crm_username: 'rawda', user: agent)
  end

  def open_launch(launch_lead = lead)
    get '/shawky/launch', params: { session: Shawky::MockGateway.create_session(launch_lead) }
  end

  def finish_as(user)
    post launch_api, headers: user.create_new_auth_token, as: :json
  end

  describe 'GET /shawky/launch' do
    it 'claims the session from the gateway and moves on with nothing in the URL' do
      open_launch

      expect(response).to have_http_status(:see_other)
      expect(response.location).to end_with("/app/accounts/#{account.id}/shawky/crm-launch")
      expect(response.headers['Referrer-Policy']).to eq('no-referrer')
      expect(response.body).not_to include('1289758825')
      expect(WebMock).to(have_requested(:get, %r{gateway\.example\.com/api/sessions/s_}).with do |request|
        request.headers['Authorization'] == 'Bearer gw-key'
      end)
    end

    it 'shows the Arabic expired page when the session was used or expired' do
      session_id = Shawky::MockGateway.create_session(lead)
      2.times { get '/shawky/launch', params: { session: session_id } }

      expect(response).to have_http_status(:gone)
      expect(response.body).to include('الرابط انتهى، ارجع للـ CRM ودوس على الزرار تاني')
    end

    it 'shows a generic error when the API key is wrong, without leaking the response' do
      stub_request(:get, %r{gateway\.example\.com/api/sessions/}).to_return(status: 401, body: '{"phone":"+201289758825"}')
      open_launch

      expect(response).to have_http_status(:bad_gateway)
      expect(response.body).not_to include('1289758825')
    end

    it 'refuses malformed sessions without calling the gateway' do
      get '/shawky/launch', params: { session: '../etc' }

      expect(response).to have_http_status(:bad_request)
      expect(WebMock).not_to have_requested(:get, %r{gateway\.example\.com})
    end

    it 'explains when the salesman is not linked' do
      open_launch(lead.merge('salesman' => 'unknown'))

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include('مش مربوط')
    end

    it 'can be switched off' do
      ClimateControl.modify(SHAWKY_GATEWAY_LAUNCH: 'false') { open_launch }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'finishing in the dashboard' do
    it 'opens a conversation on the active number assigned to the salesman, with the CRM fields saved' do
      open_launch
      finish_as(agent)

      conversation = account.conversations.find_by!(display_id: response.parsed_body['conversation_id'])
      expect([conversation.inbox, conversation.assignee]).to eq([inbox, agent])
      expect(response.parsed_body['needs_template']).to be(true)
      expect(conversation.contact.phone_number).to eq('+201289758825')
      expect(conversation.contact.custom_attributes).to include(
        'crm_name' => 'زياد', 'salesman' => 'rawda', 'project' => 'الإسكندرية', 'site_state' => 'طوب احمر', 'area' => '60',
        'crm_created_at' => '10/31/26, 5:21 PM', 'crm_extra' => { 'budget' => '2M' }
      )
      expect(conversation.contact.custom_attributes).not_to have_key('crm_lead_id')
    end

    it 'never overwrites a filled CRM field with an empty one' do
      existing = create(:contact, account: account, phone_number: '+201289758825', custom_attributes: { 'crm_lead_id' => 'L-9', 'project' => 'طنطا' })
      open_launch(lead.merge('project' => ''))
      finish_as(agent)

      expect(existing.reload.custom_attributes).to include('crm_lead_id' => 'L-9', 'project' => 'طنطا', 'crm_name' => 'زياد')
    end

    it 'audits the launch with the session and contact, never the phone' do
      open_launch
      finish_as(agent)

      log = Shawky::AuditLog.find_by!(action: 'crm_launch')
      expect(log.metadata.keys).to contain_exactly('session_id', 'contact_id', 'salesman')
      expect(log.metadata.to_json).not_to include('1289758825')
    end

    it 'lets the supervisor and administrators open it, still assigned to the salesman' do
      [supervisor, admin].each do |user|
        open_launch
        finish_as(user)
        expect(account.conversations.find_by!(display_id: response.parsed_body['conversation_id']).assignee).to eq(agent)
      end
    end

    it 'refuses other agents with an audited attempt' do
      open_launch
      finish_as(outsider)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']).to eq('not_allowed')
      expect(Shawky::AuditLog.where(action: 'crm_launch_denied')).to exist
    end

    it 'can be used once only' do
      open_launch
      finish_as(agent)
      finish_as(agent)

      expect(response).to have_http_status(:gone)
    end

    it 'takes the open conversation back for the salesman' do
      conversation.update!(assignee: teammate)
      open_launch(lead.merge('phone' => customer_phone))
      finish_as(agent)

      expect(response.parsed_body['conversation_id']).to eq(conversation.display_id)
      expect(conversation.reload.assignee).to eq(agent)
    end
  end
end
