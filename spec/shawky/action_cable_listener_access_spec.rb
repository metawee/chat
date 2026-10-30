require 'rails_helper'

# Realtime recipients follow the access rules and every payload is masked.
RSpec.describe ActionCableListener, :shawky do
  include_context 'with shawky world'

  let(:listener) { described_class.instance }

  def broadcast_jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job| job[:job] == ActionCableBroadcastJob }
  end

  def recipients_of_last_broadcast
    ActiveJob::Arguments.deserialize(broadcast_jobs.last[:args]).first
  end

  before do
    [conversation, admin]
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end

  it 'sends conversation events only to the assignee, their supervisor and admins' do
    listener.conversation_updated(Events::Base.new('conversation.updated', Time.zone.now, conversation: conversation))

    expect(recipients_of_last_broadcast).to include(agent.pubsub_token, supervisor.pubsub_token, admin.pubsub_token)
    expect(recipients_of_last_broadcast).not_to include(teammate.pubsub_token, outsider.pubsub_token)
  end

  it 'sends message events only to allowed users' do
    message = conversation.messages.first
    listener.message_created(Events::Base.new('message.created', Time.zone.now, message: message))

    expect(recipients_of_last_broadcast).not_to include(teammate.pubsub_token, outsider.pubsub_token)
    expect(recipients_of_last_broadcast).to include(agent.pubsub_token)
  end

  it 'no longer sends contact events to the whole account stream' do
    listener.contact_updated(Events::Base.new('contact.updated', Time.zone.now, contact: contact))

    expect(recipients_of_last_broadcast).not_to include("account_#{account.id}", outsider.pubsub_token)
    expect(recipients_of_last_broadcast).to include(agent.pubsub_token, admin.pubsub_token)
  end

  it 'masks phone numbers in every broadcast payload' do
    allow(ActionCable.server).to receive(:broadcast)

    ActionCableBroadcastJob.perform_now([agent.pubsub_token], 'conversation.updated',
                                        conversation.push_event_data.merge(account_id: account.id))
    ActionCableBroadcastJob.perform_now([agent.pubsub_token], 'message.created',
                                        conversation.messages.first.push_event_data.merge(account_id: account.id))
    ActionCableBroadcastJob.perform_now([agent.pubsub_token], 'contact.updated', contact.push_event_data.merge(account_id: account.id))

    expect(ActionCable.server).to have_received(:broadcast).exactly(3).times
    expect(ActionCable.server).not_to have_received(:broadcast).with(anything, satisfy { |payload| payload.to_json.include?('542921') })
  end
end
