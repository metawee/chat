require 'rails_helper'

RSpec.describe 'Shawky n8n CRM owner hook', :shawky, type: :request do
  include_context 'with shawky world'

  let(:secret) { 'n8n-secret' }
  let(:new_contact) { create(:contact, account: account, phone_number: '+966500000077') }
  let(:lead_conversation) do
    contact_inbox = create(:contact_inbox, contact: new_contact, inbox: inbox, source_id: '966500000077')
    create(:conversation, account: account, inbox: inbox, contact: new_contact, contact_inbox: contact_inbox, assignee: nil)
  end
  let(:body) do
    { account_id: account.id, conversation_id: lead_conversation.display_id,
      lead: { lead_id: 'L-104582', salesman: 'rawda', project: 'طنطا', area: '120', phone: 'ignored' } }.to_json
  end

  around { |example| ClimateControl.modify(SHAWKY_N8N_SECRET: secret) { example.run } }

  before do
    configure_routing
    inbox.update!(enable_auto_assignment: true)
    Shawky::CrmUserMapping.create!(account: account, crm_username: 'rawda', user: agent)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(teammate.id.to_s => 'online')
  end

  def signed_post(payload, timestamp: Time.now.to_i, key: secret)
    post '/shawky/hooks/n8n/crm_owner', params: payload, headers: {
      'CONTENT_TYPE' => 'application/json', 'X-Shawky-Timestamp' => timestamp.to_s,
      'X-Shawky-Signature' => Shawky::Hmac.sign(key, timestamp, payload)
    }
  end

  it 'assigns the CRM owner and stores the lead fields' do
    signed_post(body)

    expect(response).to have_http_status(:ok)
    expect(lead_conversation.reload.assignee).to eq(agent)
    expect(new_contact.reload.custom_attributes).to include('crm_lead_id' => 'L-104582', 'salesman' => 'rawda', 'project' => 'طنطا', 'area' => '120')
    expect(new_contact.custom_attributes).not_to have_key('phone')
  end

  it 'takes the lead back from round robin while no agent has replied, and audits it' do
    Shawky::CrmOwnerTimeoutJob.perform_now(lead_conversation)
    expect(lead_conversation.reload.assignee).to eq(teammate)

    signed_post(body)

    expect(lead_conversation.reload.assignee).to eq(agent)
    expect(Shawky::AuditLog.find_by!(action: 'conversation_reassigned').metadata).to include('source' => 'crm_owner')
  end

  it 'does not take the lead away once an agent has replied' do
    Shawky::CrmOwnerTimeoutJob.perform_now(lead_conversation)
    create(:message, account: account, inbox: inbox, conversation: lead_conversation, message_type: :outgoing, sender: teammate)

    signed_post(body)

    expect(lead_conversation.reload.assignee).to eq(teammate)
  end

  it 'uses round robin when the CRM owner is not mapped' do
    signed_post(JSON.parse(body).tap { |payload| payload['lead']['salesman'] = 'unknown' }.to_json)

    expect(lead_conversation.reload.assignee).to eq(teammate)
  end

  it 'rejects bad signatures and stale timestamps' do
    signed_post(body, key: 'wrong')
    expect(response).to have_http_status(:unauthorized)

    signed_post(body, timestamp: 10.minutes.ago.to_i)
    expect(response).to have_http_status(:unauthorized)
    expect(lead_conversation.reload.assignee).to be_nil
  end

  it 'requires a lead id' do
    signed_post(JSON.parse(body).merge('lead' => {}).to_json)

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
