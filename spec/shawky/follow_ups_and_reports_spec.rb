require 'rails_helper'

RSpec.describe 'Shawky follow-ups, exports and cost report', :shawky, type: :request do
  include_context 'with shawky world'

  let(:base) { "/api/v1/accounts/#{account.id}/shawky" }

  before { configure_routing }

  describe 'follow-ups' do
    let!(:stale) do
      create(:conversation, account: account, inbox: inbox, assignee: agent, created_at: 5.days.ago,
                            contact: create(:contact, account: account, name: 'قديم'))
    end

    before do
      conversation
      create(:message, account: account, inbox: inbox, conversation: stale, message_type: :outgoing, sender: agent, created_at: 4.days.ago)
      create(:conversation, account: account, inbox: inbox, assignee: outsider, created_at: 5.days.ago)
    end

    it 'lists the agent conversations with no agent message for 3 days' do
      get "#{base}/follow_ups", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([stale.display_id]), response.body
      expect(response.parsed_body['payload'].first['last_agent_message_at']).to be_within(5).of(4.days.ago.to_i)
    end

    it 'shows supervisors their team follow-ups only' do
      get "#{base}/follow_ups", headers: supervisor.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([stale.display_id])
    end

    it 'drops a conversation once the agent writes' do
      create(:message, account: account, inbox: inbox, conversation: stale, message_type: :outgoing, sender: agent)
      get "#{base}/follow_ups", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['payload']).to be_empty
    end
  end

  describe 'data export' do
    def export(params)
      post "#{base}/data_exports", headers: admin.create_new_auth_token, as: :json,
                                   params: { from_date: 1.day.ago.to_date, to_date: Date.current, file_format: 'json' }.merge(params)
    end

    it 'exports conversations with messages, masked by default, and audits it' do
      perform_enqueued_jobs(only: Shawky::DataExportJob) { export({}) }

      data = JSON.parse(Shawky::DataExport.last.file.download)
      expect(data.first['messages'].pluck('content')).to include('السلام عليكم')
      expect(data.to_json).not_to leak_phone(customer_phone)
      expect(Shawky::AuditLog.find_by!(action: 'export').metadata).to include('type' => 'conversations', 'include_phone_numbers' => false)
    end

    it 'includes full numbers only when the administrator asks for them' do
      perform_enqueued_jobs(only: Shawky::DataExportJob) { export(include_phone_numbers: true, file_format: 'csv') }

      csv = CSV.parse(Shawky::DataExport.last.file.download.force_encoding('UTF-8'), headers: true)
      expect(csv.first['contact_phone']).to eq("'#{customer_phone}")
      expect(csv.first['content']).to eq('السلام عليكم')
    end

    it 'is for administrators only and checks the range' do
      post "#{base}/data_exports", headers: supervisor.create_new_auth_token, as: :json,
                                   params: { from_date: Date.current, to_date: Date.current, file_format: 'json' }
      expect(response).to have_http_status(:unauthorized)

      export(from_date: Date.current, to_date: 2.days.ago.to_date)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'cost report' do
    let(:outgoing) { create_list(:message, 3, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent) }

    before do
      stub_const('Shawky::CostReport::FREE_SERVICE_MESSAGES_PER_MONTH', 1)
      Shawky::Routing.new(account).update_settings('shawky_message_rates' => { 'SA' => { 'service' => 0.01, 'marketing' => 0.05 } })
      Shawky::MessageCost.capture(outgoing[0], { billable: true, category: 'service', type: 'regular' })
      Shawky::MessageCost.capture(outgoing[1], { billable: true, category: 'service', type: 'regular' })
      Shawky::MessageCost.capture(outgoing[2], { billable: true, category: 'marketing', type: 'regular' })
    end

    it 'estimates spend per number and per agent, after the free service tier' do
      get "#{base}/reports/costs", headers: admin.create_new_auth_token, params: { from: Date.current.beginning_of_month, to: Date.current }

      number = response.parsed_body['numbers'].first
      expect(number['categories']['service']).to include('count' => 2, 'estimated_cost' => 0.01)
      expect(number['categories']['marketing']).to include('count' => 1, 'estimated_cost' => 0.05)
      expect(response.parsed_body['agents'].first).to include('name' => agent.name, 'estimated_cost' => 0.06)
    end

    it 'records the recipient country from the contact number' do
      expect(Shawky::MessageCost.distinct.pluck(:country_code)).to eq(['SA'])
    end
  end
end
