require 'rails_helper'

RSpec.describe Shawky::Routing, :shawky do
  subject(:routing) { described_class.new(account.reload) }

  include_context 'with shawky world'

  before { configure_routing }

  it 'starts on the primary number' do
    expect(routing.active_inbox).to eq(inbox)
    expect(routing).to be_managed_inbox(backup_inbox)
  end

  it 'fails over once, audits it and emails administrators' do
    admin
    expect { routing.failover!(reason: 'health_status BANNED') }
      .to have_enqueued_mail(Shawky::AdminNotificationsMailer, :number_failover)

    expect(described_class.new(account.reload).active_inbox).to eq(backup_inbox)
    expect(described_class.new(account).failover!(reason: 'again')).to be(false)
    expect(Shawky::AuditLog.where(action: 'number_failover').count).to eq(1)
  end

  it 'switches back on failback' do
    routing.failover!(reason: 'test')
    described_class.new(account.reload).failback!(user: admin)

    expect(described_class.new(account.reload).active_inbox).to eq(inbox)
    expect(Shawky::AuditLog.where(action: 'number_failback', user: admin)).to exist
  end

  describe Shawky::NumberHealthJob do
    let(:health_service) { instance_double(Whatsapp::HealthService) }

    before { allow(Whatsapp::HealthService).to receive(:new).and_return(health_service) }

    it 'fails over when Meta reports the primary number banned' do
      allow(health_service).to receive(:sync_health_status!) { whatsapp_channel.update!(phone_number_health: { 'status' => 'BANNED' }) }

      described_class.perform_now(account)

      expect(Shawky::Routing.new(account.reload)).to be_on_backup
    end

    it 'stays on the primary number while it is connected' do
      allow(health_service).to receive(:sync_health_status!) { whatsapp_channel.update!(phone_number_health: { 'status' => 'CONNECTED' }) }

      described_class.perform_now(account)

      expect(Shawky::Routing.new(account.reload)).not_to be_on_backup
    end
  end

  describe Shawky::ScheduledJobsJob do
    it 'checks the primary number of configured accounts' do
      expect { described_class.perform_now }.to have_enqueued_job(Shawky::NumberHealthJob).with(account)
    end
  end
end
