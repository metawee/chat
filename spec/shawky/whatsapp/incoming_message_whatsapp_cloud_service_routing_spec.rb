require 'rails_helper'

# Real WhatsApp Cloud webhook payloads through upstream's inbound service.
RSpec.describe Whatsapp::IncomingMessageWhatsappCloudService, :shawky do
  include_context 'with shawky world'

  let(:welcome) { 'أهلاً بك في شوقي جروب' }

  def inbound(target_inbox, from, text)
    params = {
      phone_number: target_inbox.channel.phone_number, object: 'whatsapp_business_account',
      entry: [{ changes: [{ value: {
        contacts: [{ profile: { name: 'Customer' }, wa_id: from }],
        messages: [{ from: from, id: "wamid.#{SecureRandom.hex(8)}", text: { body: text }, timestamp: Time.now.to_i.to_s, type: 'text' }]
      } }] }]
    }.with_indifferent_access
    described_class.new(inbox: target_inbox, params: params).perform
  end

  before do
    configure_routing
    Shawky::Routing.new(account.reload).update_settings('shawky_welcome_message' => welcome)
    [inbox, backup_inbox].each { |each_inbox| each_inbox.update!(enable_auto_assignment: true) }
    [agent, teammate].each { |user| create(:inbox_member, user: user, inbox: backup_inbox) }
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(teammate.id.to_s => 'online')
  end

  after { Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) } }

  it 'holds a new number for the CRM owner and welcomes the customer with a free-form message' do
    perform_enqueued_jobs(only: EventDispatcherJob) { inbound(inbox, '966511111111', 'السلام عليكم') }

    new_conversation = account.conversations.order(:id).last
    expect(new_conversation.assignee).to be_nil
    expect(new_conversation.custom_attributes['shawky_routing']).to eq('awaiting_crm_owner')
    expect(new_conversation.messages.outgoing.pluck(:content)).to eq([welcome])
  end

  it 'routes a customer who now writes to the backup number to the same contact and agent' do
    conversation.update!(status: :resolved)

    perform_enqueued_jobs(only: EventDispatcherJob) { inbound(backup_inbox, '966542921507', 'رجعت تاني') }

    backup_conversation = backup_inbox.conversations.last
    expect(backup_conversation.contact).to eq(contact)
    expect(backup_conversation.assignee).to eq(agent)
    expect(backup_conversation.messages.outgoing).to be_empty
  end
end
