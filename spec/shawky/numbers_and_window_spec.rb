require 'rails_helper'

RSpec.describe 'Shawky numbers, settings and the 24-hour window', :shawky, type: :request do
  include_context 'with shawky world'

  let(:base) { "/api/v1/accounts/#{account.id}" }

  before { configure_routing }

  describe 'settings' do
    it 'lets administrators configure the numbers, welcome text and CRM wait' do
      account.enable_features!('assignment_v2')
      patch "#{base}/shawky/settings", headers: admin.create_new_auth_token, as: :json,
                                       params: { primary_inbox_id: inbox.id, backup_inbox_id: backup_inbox.id,
                                                 welcome_message: 'أهلاً', crm_owner_wait_seconds: 90 }

      expect(response.parsed_body).to include('primary_inbox_id' => inbox.id, 'backup_inbox_id' => backup_inbox.id,
                                              'active_inbox_id' => inbox.id, 'welcome_message' => 'أهلاً', 'crm_owner_wait_seconds' => 90)
      expect(account.reload.feature_enabled?('assignment_v2')).to be(false)
    end

    it 'rejects inboxes that are not WhatsApp inboxes of the account' do
      patch "#{base}/shawky/settings", headers: admin.create_new_auth_token, as: :json,
                                       params: { primary_inbox_id: create(:inbox).id }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'keeps settings, failback and CRM user mappings admin-only' do
      patch "#{base}/shawky/settings", headers: supervisor.create_new_auth_token, as: :json, params: { welcome_message: 'x' }
      expect(response).to have_http_status(:unauthorized)

      post "#{base}/shawky/settings/failback", headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)

      post "#{base}/shawky/crm_user_mappings", headers: agent.create_new_auth_token, as: :json, params: { crm_username: 'rawda', user_id: agent.id }
      expect(response).to have_http_status(:unauthorized)

      post "#{base}/shawky/crm_user_mappings", headers: admin.create_new_auth_token, as: :json, params: { crm_username: 'rawda', user_id: agent.id }
      expect(Shawky::CrmUserMapping.user_for(account, 'rawda')).to eq(agent)
    end

    it 'tells every user which number is active' do
      get "#{base}/shawky/routing", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body).to include('primary_inbox_id' => inbox.id, 'backup_inbox_id' => backup_inbox.id, 'active_inbox_id' => inbox.id)
    end
  end

  describe 'continue on the active number' do
    before { Shawky::Routing.new(account.reload).failover!(reason: 'test') }

    it 'opens a conversation with the same customer on the backup number for the same agent' do
      post "#{base}/shawky/conversations/#{conversation.display_id}/continue_on_active_number", headers: agent.create_new_auth_token, as: :json

      continued = account.conversations.find_by!(display_id: response.parsed_body['id'])
      expect(continued.inbox).to eq(backup_inbox)
      expect(continued.contact).to eq(contact)
      expect(continued.assignee).to eq(agent)
      expect(continued.contact_inbox.source_id).to eq('966542921507')
      expect(response.body).not_to leak_phone(customer_phone)
    end

    it 'reuses the open conversation on the active number' do
      2.times do
        post "#{base}/shawky/conversations/#{conversation.display_id}/continue_on_active_number", headers: agent.create_new_auth_token, as: :json
      end

      expect(contact.conversations.where(inbox: backup_inbox).count).to eq(1)
    end

    it 'is not available for someone else conversation' do
      post "#{base}/shawky/conversations/#{conversation.display_id}/continue_on_active_number", headers: outsider.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe '24-hour window' do
    let(:messages_path) { "#{base}/conversations/#{conversation.display_id}/messages" }

    before { conversation.messages.incoming.update_all(created_at: 25.hours.ago) } # rubocop:disable Rails/SkipsModelValidations

    it 'refuses free-form replies outside the window' do
      post messages_path, headers: agent.create_new_auth_token, as: :json, params: { content: 'hello' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(conversation.messages.where(content: 'hello')).to be_empty
    end

    it 'still allows templates and private notes' do
      post messages_path, headers: agent.create_new_auth_token, as: :json,
                          params: { content: 'tpl', template_params: { name: 'customer_yes_no', language: 'ar', processed_params: {} } }
      expect(response).to have_http_status(:ok)

      post messages_path, headers: agent.create_new_auth_token, as: :json, params: { content: 'note', private: true }
      expect(response).to have_http_status(:ok)
    end

    it 'tells the dashboard when the window closes' do
      conversation.messages.incoming.update_all(created_at: 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations

      get "#{base}/conversations/#{conversation.display_id}", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['shawky_window_closes_at']).to be_within(5).of(23.hours.from_now.to_i)
    end
  end
end
