# Primary/backup WhatsApp numbers. Settings live in account.settings:
#   shawky_primary_inbox_id, shawky_backup_inbox_id, shawky_active_inbox_id,
#   shawky_welcome_message, shawky_crm_owner_wait_seconds
# New outbound conversations (CRM launches, "continue on active number") use the active inbox.
class Shawky::Routing
  # Phone number statuses from Meta's health API that mean the number cannot be used.
  FAILOVER_STATUSES = %w[BANNED DISCONNECTED DELETED].freeze
  # Message failure codes that mean the account or number is blocked from sending:
  # 131031 business account locked, 368 temporarily blocked for policy violations.
  FAILOVER_ERROR_CODES = %w[131031 368].freeze
  DEFAULT_CRM_OWNER_WAIT_SECONDS = 60

  attr_reader :account

  def initialize(account)
    @account = account
  end

  def configured?
    primary_inbox_id.present?
  end

  def primary_inbox_id = settings['shawky_primary_inbox_id']
  def backup_inbox_id = settings['shawky_backup_inbox_id']

  def active_inbox_id
    settings['shawky_active_inbox_id'] || primary_inbox_id
  end

  def active_inbox
    account.inboxes.find(active_inbox_id)
  end

  def primary_inbox
    account.inboxes.find(primary_inbox_id)
  end

  def managed_inbox?(inbox)
    configured? && [primary_inbox_id, backup_inbox_id].include?(inbox.id)
  end

  def on_backup?
    backup_inbox_id.present? && active_inbox_id == backup_inbox_id
  end

  def welcome_message
    settings['shawky_welcome_message'].presence
  end

  def crm_owner_wait
    (settings['shawky_crm_owner_wait_seconds'] || DEFAULT_CRM_OWNER_WAIT_SECONDS).to_i.seconds
  end

  def failover!(reason:, details: {})
    account.with_lock do
      return false if backup_inbox_id.blank? || on_backup?

      update_settings('shawky_active_inbox_id' => backup_inbox_id)
    end
    Shawky::AuditLog.record!('number_failover', account: account, user: nil, metadata: details.merge(reason: reason))
    Shawky::AdminNotificationsMailer.with(account: account).number_failover(reason).deliver_later
    true
  end

  def failback!(user:)
    update_settings('shawky_active_inbox_id' => primary_inbox_id)
    Shawky::AuditLog.record!('number_failback', account: account, user: user)
  end

  def update_settings(changes)
    account.update!(settings: account.settings.merge(changes))
  end

  private

  def settings
    account.settings || {}
  end
end
