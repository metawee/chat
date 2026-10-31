require 'rails_helper'

RSpec.describe Shawky::ResponseDelayScanJob, :shawky do
  include_context 'with shawky world'

  let(:alert_notes) { conversation.messages.where(private: true).where('content LIKE ?', '%⏱%') }

  before do
    configure_routing
    conversation.update!(waiting_since: 3.hours.ago)
  end

  it 'alerts the agent supervisor once per waiting message, with a mention notification' do
    2.times { described_class.perform_now(account.reload) }

    expect(alert_notes.count).to eq(1)
    note = alert_notes.first
    expect(note.content).to include("mention://user/#{supervisor.id}/#{ERB::Util.url_encode(supervisor.name)})", agent.name)

    Messages::MentionService.new(message: note).perform
    expect(Notification.where(user: supervisor, notification_type: 'conversation_mention', primary_actor: conversation)).to exist
  end

  it 'alerts again for a new wait' do
    described_class.perform_now(account.reload)
    conversation.update!(waiting_since: 150.minutes.ago)
    described_class.perform_now(account)

    expect(Shawky::DelayAlert.where(conversation: conversation).count).to eq(2)
  end

  it 'waits for the configured delay (2 hours by default)' do
    conversation.update!(waiting_since: 90.minutes.ago)
    described_class.perform_now(account.reload)
    expect(Shawky::DelayAlert.count).to eq(0)

    Shawky::Routing.new(account).update_settings('shawky_reply_delay_minutes' => 60)
    described_class.perform_now(account.reload)
    expect(Shawky::DelayAlert.count).to eq(1)
  end

  it 'mentions administrators when the agent has no supervisor' do
    Shawky::TeamSupervisor.delete_all
    admin
    described_class.perform_now(account.reload)

    expect(alert_notes.first.content).to include("mention://user/#{admin.id}/")
  end

  it 'reassigns to an online teammate when enabled, and audits it' do
    Shawky::Routing.new(account).update_settings('shawky_auto_reassign_on_delay' => true)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(teammate.id.to_s => 'online')

    described_class.perform_now(account.reload)

    expect(conversation.reload.assignee).to eq(teammate)
    expect(Shawky::DelayAlert.last.reassigned_to).to eq(teammate)
    expect(Shawky::AuditLog.find_by!(action: 'conversation_reassigned').metadata).to include('source' => 'response_delay')
  end

  it 'ignores resolved and unassigned conversations' do
    conversation.update_columns(status: Conversation.statuses[:resolved]) # rubocop:disable Rails/SkipsModelValidations
    described_class.perform_now(account.reload)

    expect(Shawky::DelayAlert.count).to eq(0)
  end
end
