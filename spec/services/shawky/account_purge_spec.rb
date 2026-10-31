require 'rails_helper'

RSpec.describe Shawky::AccountPurge, :shawky do
  include_context 'with shawky world'

  let(:other_account) { create(:account) }

  before do
    # Deleting a WhatsApp inbox unsubscribes its webhook at Meta (upstream behaviour).
    stub_request(:any, %r{\Ahttps://graph\.facebook\.com/})
    conversation
    Shawky::AuditLog.record!('phone_revealed', account: account, auditable: contact, user: admin)
    create(:account_user, account: other_account, user: teammate)
  end

  it 'removes Shawky records and deletes the account with its customers and messages' do
    report = nil
    perform_enqueued_jobs(only: [DeleteObjectJob, ActiveRecord::DestroyAssociationAsyncJob]) do
      report = described_class.new(account: account).perform
    end

    expect(report).to include(contacts: 1, conversations: 1, messages: 1)
    expect(Account.exists?(account.id)).to be(false)
    expect(Contact.exists?(contact.id)).to be(false)
    expect(Message.where(account_id: account.id)).to be_empty
    expect(Shawky::AuditLog.where(account_id: account.id)).to be_empty
    expect(Shawky::TeamSupervisor.where(account_id: account.id)).to be_empty
  end

  it 'soft-deletes users who belong to no other account' do
    perform_enqueued_jobs(only: [DeleteObjectJob, ActiveRecord::DestroyAssociationAsyncJob]) { described_class.new(account: account).perform }

    expect(agent.reload.email).to end_with(AccountDeletionService::SOFT_DELETE_EMAIL_DOMAIN)
    expect(teammate.reload.email).not_to end_with(AccountDeletionService::SOFT_DELETE_EMAIL_DOMAIN)
  end

  describe 'rake shawky:purge_account' do
    before do
      Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == 'shawky:purge_account' }
      Rake::Task['shawky:purge_account'].reenable
    end

    it 'refuses without the exact account name' do
      expect { Rake::Task['shawky:purge_account'].invoke(account.id.to_s) }.to raise_error(SystemExit)
      expect(Account.exists?(account.id)).to be(true)
    end
  end
end
