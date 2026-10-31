require 'rails_helper'

RSpec.describe 'Shawky conversation and contact access', :shawky, type: :request do
  include_context 'with shawky world'

  let(:base) { "/api/v1/accounts/#{account.id}" }
  let(:others_conversation) do
    create(:conversation, account: account, inbox: inbox, assignee: outsider,
                          contact: create(:contact, account: account, phone_number: '+966500000001'))
  end
  let(:unassigned_conversation) { create(:conversation, account: account, inbox: inbox, assignee: nil) }

  def conversation_ids(user, path = "#{base}/conversations?assignee_type=all")
    get path, headers: user.create_new_auth_token, as: :json
    response.parsed_body.dig('data', 'payload').pluck('id')
  end

  describe 'conversation lists' do
    before { [conversation, others_conversation, unassigned_conversation] }

    it 'shows an agent only the conversations assigned to them' do
      expect(conversation_ids(agent)).to contain_exactly(conversation.display_id)
    end

    it 'shows a supervisor team conversations and unassigned ones in team inboxes' do
      expect(conversation_ids(supervisor)).to contain_exactly(conversation.display_id, unassigned_conversation.display_id)
    end

    it 'shows an administrator everything' do
      expect(conversation_ids(admin)).to contain_exactly(conversation.display_id, others_conversation.display_id,
                                                         unassigned_conversation.display_id)
    end

    it 'does not leak through filters or meta counts' do
      post "#{base}/conversations/filter", headers: agent.create_new_auth_token, as: :json,
                                           params: { payload: [{ attribute_key: 'status', filter_operator: 'equal_to', values: ['open'] }] }
      expect(response.parsed_body['payload'].pluck('id')).to contain_exactly(conversation.display_id)

      get "#{base}/conversations/meta", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body.dig('meta', 'all_count')).to eq(1)
    end
  end

  describe 'ID guessing' do
    it 'refuses to show another agent conversation or its messages' do
      get "#{base}/conversations/#{others_conversation.display_id}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)

      get "#{base}/conversations/#{others_conversation.display_id}/messages", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses to reply to another agent conversation' do
      post "#{base}/conversations/#{others_conversation.display_id}/messages",
           headers: agent.create_new_auth_token, params: { content: 'hi' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(others_conversation.messages.where(content: 'hi')).to be_empty
    end

    it 'refuses unassigned conversations to plain agents' do
      get "#{base}/conversations/#{unassigned_conversation.display_id}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses another agent contact' do
      get "#{base}/contacts/#{others_conversation.contact_id}", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)

      get "#{base}/contacts/#{others_conversation.contact_id}/conversations", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'contact history' do
    let!(:old_conversation) do
      create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, assignee: outsider, status: :resolved)
    end

    it 'lets the assigned agent read the contact older conversations' do
      get "#{base}/contacts/#{contact.id}/conversations", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['payload'].pluck('id')).to include(old_conversation.display_id)

      get "#{base}/conversations/#{old_conversation.display_id}/messages", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
    end

    it 'keeps the history read-only' do
      post "#{base}/conversations/#{old_conversation.display_id}/messages",
           headers: agent.create_new_auth_token, params: { content: 'hi' }, as: :json
      expect(response).to have_http_status(:unauthorized)

      post "#{base}/conversations/#{old_conversation.display_id}/toggle_status",
           headers: agent.create_new_auth_token, params: { status: 'open' }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not list history conversations among the agent own conversations' do
      expect(conversation_ids(agent)).to contain_exactly(conversation.display_id)
    end
  end

  describe 'contacts' do
    before { [conversation, others_conversation] }

    it 'lists only the agent own contacts' do
      get "#{base}/contacts", headers: agent.create_new_auth_token, as: :json
      expect(response.parsed_body['payload'].pluck('id')).to contain_exactly(contact.id)
    end

    it 'does not search by phone number for agents' do
      get "#{base}/contacts/search", headers: agent.create_new_auth_token, params: { q: '542921' }, as: :json
      expect(response.parsed_body['payload']).to be_empty

      get "#{base}/search", headers: agent.create_new_auth_token, params: { q: '542921' }, as: :json
      expect(response.parsed_body.dig('payload', 'contacts')).to be_empty
      expect(response.parsed_body.dig('payload', 'conversations')).to be_empty
    end

    it 'searches by contact id and CRM lead id for agents' do
      contact.update!(custom_attributes: { 'crm_lead_id' => 'L-104582' })

      get "#{base}/contacts/search", headers: agent.create_new_auth_token, params: { q: 'L-104582' }, as: :json
      expect(response.parsed_body['payload'].pluck('id')).to eq([contact.id])

      get "#{base}/contacts/search", headers: agent.create_new_auth_token, params: { q: contact.id.to_s }, as: :json
      expect(response.parsed_body['payload'].pluck('id')).to eq([contact.id])
    end

    it 'lets administrators search by phone number' do
      get "#{base}/contacts/search", headers: admin.create_new_auth_token, params: { q: '542921' }, as: :json
      expect(response.parsed_body['payload'].pluck('id')).to eq([contact.id])
    end

    it 'refuses phone number filters for agents' do
      post "#{base}/contacts/filter", headers: agent.create_new_auth_token, as: :json,
                                      params: { payload: [{ attribute_key: 'phone_number', filter_operator: 'contains', values: ['542921'] }] }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets agents rename a contact but not change its number' do
      patch "#{base}/contacts/#{contact.id}", headers: agent.create_new_auth_token, as: :json,
                                              params: { name: 'عبدالرحمن', phone_number: '+966500000009', email: 'x@example.com' }

      expect(contact.reload.name).to eq('عبدالرحمن')
      expect(contact.phone_number).to eq(customer_phone)
      expect(contact.email).to be_nil
    end

    it 'never overwrites data with a masked value sent back by the client' do
      patch "#{base}/contacts/#{contact.id}", headers: admin.create_new_auth_token, as: :json,
                                              params: { name: 'X', phone_number: '•••••••••507' }

      expect(contact.reload.phone_number).to eq(customer_phone)
    end

    it 'does not let plain agents create contacts or start conversations by number' do
      post "#{base}/contacts", headers: agent.create_new_auth_token, as: :json,
                               params: { name: 'new', phone_number: '+966500000002' }
      expect(response).to have_http_status(:unauthorized)

      post "#{base}/conversations", headers: agent.create_new_auth_token, as: :json,
                                    params: { inbox_id: inbox.id, contact_id: contact.id, source_id: '966500000002' }
      expect(response).to have_http_status(:unauthorized)

      post "#{base}/contacts/#{contact.id}/contact_inboxes", headers: agent.create_new_auth_token, as: :json,
                                                             params: { inbox_id: inbox.id }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'only lets administrators merge contacts' do
      other = others_conversation.contact
      post "#{base}/actions/contact_merge", headers: agent.create_new_auth_token, as: :json,
                                            params: { base_contact_id: contact.id, mergee_contact_id: other.id }

      expect(response).to have_http_status(:unauthorized)
      expect(Contact.exists?(other.id)).to be(true)
    end

    it 'lets supervisors create contacts' do
      post "#{base}/contacts", headers: supervisor.create_new_auth_token, as: :json,
                               params: { name: 'new', phone_number: '+966500000002' }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'transfers' do
    it 'lets an agent hand over to a teammate and audits it' do
      post "#{base}/conversations/#{conversation.display_id}/assignments",
           headers: agent.create_new_auth_token, params: { assignee_id: teammate.id }, as: :json

      expect(conversation.reload.assignee).to eq(teammate)
      log = Shawky::AuditLog.find_by!(action: 'conversation_reassigned', auditable: conversation)
      expect(log.metadata).to include('from_user_id' => agent.id, 'to_user_id' => teammate.id)
      expect(log.user).to eq(agent)
    end

    it 'refuses a transfer outside the agent teams' do
      post "#{base}/conversations/#{conversation.display_id}/assignments",
           headers: agent.create_new_auth_token, params: { assignee_id: outsider.id }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(conversation.reload.assignee).to eq(agent)
    end

    it 'lets a supervisor transfer to anyone' do
      post "#{base}/conversations/#{conversation.display_id}/assignments",
           headers: supervisor.create_new_auth_token, params: { assignee_id: outsider.id }, as: :json

      expect(conversation.reload.assignee).to eq(outsider)
    end

    it 'refuses bulk assignment to plain agents' do
      post "#{base}/bulk_actions", headers: agent.create_new_auth_token, as: :json,
                                   params: { type: 'Conversation', ids: [conversation.display_id], fields: { assignee_id: outsider.id } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'notifications' do
    it 'does not notify agents about conversations they cannot see' do
      expect(NotificationBuilder.new(notification_type: 'conversation_creation', user: outsider, account: account,
                                     primary_actor: conversation).perform).to be_nil
    end
  end

  context 'when access control is switched off' do
    around { |example| ClimateControl.modify(SHAWKY_ACCESS_CONTROL: 'false') { example.run } }

    it 'falls back to upstream inbox-based access' do
      [conversation, others_conversation]
      expect(conversation_ids(agent)).to contain_exactly(conversation.display_id, others_conversation.display_id)
    end
  end
end
