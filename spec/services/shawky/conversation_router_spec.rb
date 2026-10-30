require 'rails_helper'

RSpec.describe Shawky::ConversationRouter, :shawky do
  include_context 'with shawky world'

  let(:new_contact) { create(:contact, account: account, phone_number: '+966500000077') }

  before do
    configure_routing
    inbox.update!(enable_auto_assignment: true)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(teammate.id.to_s => 'online')
  end

  def new_conversation(contact)
    contact_inbox = ContactInbox.find_by(contact: contact, inbox: inbox) ||
                    create(:contact_inbox, contact: contact, inbox: inbox, source_id: contact.phone_number.delete('+'))
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, assignee: nil)
  end

  it 'sends a returning customer back to their previous agent' do
    conversation.update!(status: :resolved)

    expect(new_conversation(contact).reload.assignee).to eq(agent)
  end

  it 'uses round robin when the previous agent left the inbox' do
    conversation.update!(status: :resolved)
    InboxMember.find_by(user: agent, inbox: inbox).destroy!

    returning = new_conversation(contact).reload
    expect(returning.assignee).to eq(teammate)
    expect(returning.custom_attributes['shawky_routing']).to eq('round_robin')
  end

  it 'holds a brand-new lead for the CRM owner and falls back to round robin' do
    lead_conversation = new_conversation(new_contact).reload

    expect(lead_conversation.assignee).to be_nil
    expect(lead_conversation.custom_attributes['shawky_routing']).to eq('awaiting_crm_owner')
    expect(Shawky::CrmOwnerTimeoutJob).to have_been_enqueued.with(lead_conversation)

    Shawky::CrmOwnerTimeoutJob.perform_now(lead_conversation)
    expect(lead_conversation.reload.assignee).to eq(teammate)
    expect(lead_conversation.custom_attributes['shawky_routing']).to eq('round_robin_fallback')
  end

  it 'uses round robin straight away for a contact already known to the CRM' do
    new_contact.update!(custom_attributes: { 'lead_id' => 'L-1' })

    expect(new_conversation(new_contact).reload.assignee).to eq(teammate)
  end

  it 'leaves inboxes outside Shawky routing to upstream assignment' do
    other_inbox = create(:inbox, account: account, enable_auto_assignment: false)
    other = create(:conversation, account: account, inbox: other_inbox, contact: new_contact, assignee: nil)

    expect(other.reload.custom_attributes).not_to have_key('shawky_routing')
  end

  it 'links a customer writing to the backup number to the same contact' do
    contact_inbox = ContactInboxWithContactBuilder.new(
      inbox: backup_inbox, source_id: '966542921507', contact_attributes: { name: 'x', phone_number: customer_phone }
    ).perform

    expect(contact_inbox.contact).to eq(contact)
  end
end
