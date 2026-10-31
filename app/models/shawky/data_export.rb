# == Schema Information
#
# Table name: shawky_data_exports
#
#  id                    :bigint           not null, primary key
#  file_format           :string           not null
#  from_date             :date             not null
#  include_phone_numbers :boolean          default(FALSE), not null
#  status                :string           default("pending"), not null
#  to_date               :date             not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  user_id               :bigint           not null
#
# R7: an administrator's full export of conversations and messages for a date range.
class Shawky::DataExport < ApplicationRecord
  FORMATS = %w[json csv].freeze
  MAX_RANGE = 366.days

  belongs_to :account
  belongs_to :user
  has_one_attached :file

  enum :status, { pending: 'pending', completed: 'completed', failed: 'failed' }
  validates :file_format, inclusion: { in: FORMATS }
  validate :valid_range

  def date_range
    from_date.in_time_zone.beginning_of_day..to_date.in_time_zone.end_of_day
  end

  private

  def valid_range
    return if from_date.blank? || to_date.blank?

    errors.add(:to_date, :invalid) if to_date < from_date || (to_date - from_date).days > MAX_RANGE
  end
end
