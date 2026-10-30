require 'rails_helper'

RSpec.describe Shawky::EventListener, :shawky do
  include_context 'with shawky world'

  let(:listener) { described_class.instance }
  let(:welcome) { 'أهلاً بك في شوقي جروب! سيتواصل معك أحد مستشارينا خلال دقائق.' }

  before do
    configure_routing
    Shawky::Routing.new(account.reload).update_settings('shawky_welcome_message' => welcome)
  end

  def message_event(name, message)
    Events::Base.new(name, Time.zone.now, message: message)
  end

  describe 'welcome message' do
    it 'answers a brand-new customer first message with the free-form welcome, once' do
      first_message = conversation.messages.incoming.first
      2.times { listener.message_created(message_event('message.created', first_message)) }

      welcomes = conversation.messages.outgoing.where(content: welcome)
      expect(welcomes.count).to eq(1)
      expect(welcomes.first.additional_attributes).not_to have_key('template_params')
    end

    it 'does not welcome returning customers' do
      create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, status: :resolved)
      listener.message_created(message_event('message.created', conversation.messages.incoming.first))

      expect(conversation.messages.outgoing.where(content: welcome)).to be_empty
    end
  end

  describe 'failover on send errors' do
    let(:failed_message) do
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent,
                       status: :failed, external_error: '131031: Business Account locked')
    end

    it 'switches to the backup number when Meta reports the account locked' do
      listener.message_updated(message_event('message.updated', failed_message))

      expect(Shawky::Routing.new(account.reload)).to be_on_backup
    end

    it 'ignores ordinary delivery failures' do
      failed_message.update!(external_error: '131026: Message undeliverable')
      listener.message_updated(message_event('message.updated', failed_message))

      expect(Shawky::Routing.new(account.reload)).not_to be_on_backup
    end
  end
end
