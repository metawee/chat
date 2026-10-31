# == Schema Information
#
# Table name: shawky_crm_user_mappings
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  crm_username :string          not null
#  user_id     :bigint           not null
#
# Maps a CRM salesman username (lead.salesman from the gateway, e.g. "rawda") to a Chatwoot user.
class Shawky::CrmUserMapping < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :crm_username, presence: true, uniqueness: { scope: :account_id }
  validate :user_belongs_to_account

  def self.user_for(account, crm_username)
    find_by(account: account, crm_username: crm_username)&.user
  end

  private

  def user_belongs_to_account
    errors.add(:user, :invalid) unless account&.users&.exists?(id: user_id)
  end
end
