# == Schema Information
#
# Table name: shawky_delay_alerts
#
#  id               :bigint           not null, primary key
#  waiting_since    :datetime         not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  assignee_id      :bigint           not null
#  conversation_id  :bigint           not null
#  reassigned_to_id :bigint
#
# One row per waiting customer message that went unanswered too long (R4), so the
# supervisor is alerted once per wait however often the scan runs.
class Shawky::DelayAlert < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :assignee, class_name: 'User'
  belongs_to :reassigned_to, class_name: 'User', optional: true

  validates :waiting_since, uniqueness: { scope: :conversation_id }
end
