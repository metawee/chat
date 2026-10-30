# == Schema Information
#
# Table name: shawky_team_supervisors
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  team_id    :bigint           not null
#  user_id    :bigint           not null
#
class Shawky::TeamSupervisor < ApplicationRecord
  belongs_to :account
  belongs_to :team
  belongs_to :user

  before_validation { self.account_id = team&.account_id }

  validates :user_id, uniqueness: { scope: :team_id }
  validate :user_belongs_to_account

  private

  def user_belongs_to_account
    errors.add(:user, :invalid) unless account&.users&.exists?(id: user_id)
  end
end
