require 'rails_helper'

# Phone masking for data leaving the server outside the REST API: webhooks, Liquid
# variables in outgoing messages, CSV exports and logs.
RSpec.describe Shawky::PayloadMasker, :shawky do
  include_context 'with shawky world'

  describe 'webhooks' do
    it 'masks phone numbers in webhook payloads' do
      sent_body = nil
      allow(SafeFetch).to receive(:fetch) { |_url, **options| sent_body = options[:body] }

      Webhooks::Trigger.execute('https://n8n.example.com/hook', conversation.webhook_data.merge(event: 'conversation_updated'), :account_webhook)

      expect(sent_body).to include('conversation_updated')
      expect(sent_body).not_to leak_phone(customer_phone)
    end
  end

  describe 'Liquid variables' do
    it 'does not let {{contact.phone_number}} put the real number into a message' do
      message = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                                 sender: agent, content: 'رقمك {{contact.phone_number}} يا {{contact.name}}')

      expect(message.reload.content).not_to leak_phone(customer_phone)
      expect(message.content).to include('507')
    end
  end

  describe 'contact export' do
    it 'masks numbers in the CSV and audits the export' do
      Account::ContactsExportJob.perform_now(account.id, admin.id, %w[id name phone_number identifier], {})

      csv = account.reload.contacts_export.download
      expect(csv).not_to leak_phone(customer_phone)
      expect(Shawky::AuditLog.where(action: 'export', user: admin)).to exist
    end
  end

  describe 'logs' do
    it 'filters phone parameters from request logs' do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      filtered = filter.filter('phone_number' => customer_phone, 'from' => '966542921507', 'wa_id' => '966542921507',
                               'contact' => { 'identifier' => customer_phone })

      expect(filtered.to_json).not_to leak_phone(customer_phone)
    end
  end
end
