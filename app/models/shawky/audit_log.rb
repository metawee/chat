# == Schema Information
#
# Table name: shawky_audit_logs
#
#  id             :bigint           not null, primary key
#  action         :string           not null
#  auditable_type :string
#  ip_address     :string
#  metadata       :jsonb            not null
#  created_at     :datetime         not null
#  account_id     :bigint           not null
#  auditable_id   :bigint
#  user_id        :bigint
#
class Shawky::AuditLog < ApplicationRecord
  ACTIONS = %w[phone_revealed conversation_reassigned export crm_launch number_failover number_failback account_purge].freeze

  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }

  # context: user (defaults to Current.user), ip_address
  def self.record!(action, account:, auditable: nil, metadata: {}, **context)
    user = context.fetch(:user, Current.user)
    create!(
      action: action,
      account: account,
      user: user.is_a?(User) ? user : nil,
      auditable: auditable,
      metadata: metadata,
      ip_address: context[:ip_address]
    )
  end
end
