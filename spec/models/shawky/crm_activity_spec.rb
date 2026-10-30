require 'rails_helper'

RSpec.describe Shawky::CrmActivity, :shawky do
  include_context 'with shawky world'
  include_context 'with mock crm'

  let(:listener) { Shawky::EventListener.instance }

  before do
    Shawky::CrmUserMapping.create!(account: account, crm_user_id: 'U-77', user: agent)
    contact.update!(custom_attributes: { 'lead_id' => 'L-104582' })
  end

  def agent_reply(content = 'أهلاً يا فندم')
    message = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent, content: content)
    listener.message_created(Events::Base.new('message.created', Time.zone.now, message: message))
  end

  it 'reports the first agent reply of the day to the CRM' do
    perform_enqueued_jobs(only: Shawky::CrmActivityJob) { agent_reply }

    activity = described_class.last
    expect(activity).to be_delivered
    expect(Shawky::MockCrm.activities).to contain_exactly(
      a_hash_including('event_id' => activity.event_id, 'lead_id' => 'L-104582', 'agent_id' => 'U-77', 'type' => 'whatsapp',
                       'direction' => 'outbound', 'status' => 'sent', 'duration_sec' => nil, 'summary' => nil, 'recording_url' => nil)
    )
    expect(Shawky::MockCrm.activities.first['started_at']).to match(/\+0[23]:00\z/)
    expect(Shawky::MockCrm.activities.to_json).not_to leak_phone(customer_phone)
  end

  it 'reports one reply per 24 hours and a separate resolve' do
    perform_enqueued_jobs(only: Shawky::CrmActivityJob) do
      agent_reply
      agent_reply('رد تاني')
      listener.conversation_resolved(Events::Base.new('conversation.resolved', Time.zone.now, conversation: conversation))
    end

    expect(Shawky::MockCrm.activities.pluck('status')).to contain_exactly('sent', 'resolved')
  end

  it 'ignores private notes, bots and contacts that are not CRM leads' do
    note = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: agent, private: true)
    listener.message_created(Events::Base.new('message.created', Time.zone.now, message: note))
    contact.update!(custom_attributes: {})
    agent_reply

    expect(described_class.count).to eq(0)
  end

  describe Shawky::CrmActivityJob do
    let(:activity) { Shawky::CrmActivity.last }

    before { agent_reply }

    it 'retries while the CRM is down, sending the same event_id' do
      stub_request(:post, 'https://crm.example.com/api/integrations/shawky/activities').to_return(status: 503)

      expect { described_class.perform_now(activity) }.to have_enqueued_job(described_class)
      expect(activity.reload).to be_pending
      expect(activity.attempts).to eq(1)

      stub_request(:post, %r{\Ahttps://crm\.example\.com/}).to_rack(Shawky::MockCrm)
      2.times { described_class.perform_now(activity.reload) }

      expect(activity.reload).to be_delivered
      expect(Shawky::MockCrm.activities.pluck('event_id')).to eq([activity.event_id])
    end

    it 'gives up on errors a retry cannot fix' do
      stub_request(:post, 'https://crm.example.com/api/integrations/shawky/activities').to_return(status: 422)

      expect { described_class.perform_now(activity) }.not_to have_enqueued_job(described_class)
      expect(activity.reload).to be_failed
    end
  end
end
