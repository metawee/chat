# Contract: personal data is deleted within 30 days after the contract ends.
# Removes Shawky's own records, then hands the account to upstream's AccountDeletionService:
# users who belong to no other account are soft-deleted and DeleteObjectJob destroys the
# account with its contacts, conversations, messages and attachment files.
class Shawky::AccountPurge
  SHAWKY_MODELS = [
    Shawky::CrmActivity, Shawky::DelayAlert, Shawky::MessageCost, Shawky::CrmUserMapping, Shawky::TeamSupervisor, Shawky::AuditLog
  ].freeze

  pattr_initialize [:account!]

  def perform
    report = counts
    Shawky::DataExport.where(account: account).find_each { |export| export.file.purge && export.destroy! }
    SHAWKY_MODELS.each { |model| model.where(account_id: account.id).delete_all }
    AccountDeletionService.new(account: account).perform
    report
  end

  private

  def counts
    {
      account_id: account.id, contacts: account.contacts.count, conversations: account.conversations.count,
      messages: account.messages.count, attachments: Attachment.where(account_id: account.id).count
    }
  end
end
