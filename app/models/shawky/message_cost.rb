# == Schema Information
#
# Table name: shawky_message_costs
#
#  id           :bigint           not null, primary key
#  billable     :boolean          default(FALSE), not null
#  category     :string
#  country_code :string
#  pricing_type :string
#  sent_at      :datetime         not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  inbox_id     :bigint           not null
#  message_id   :bigint           not null
#  sender_id    :bigint
#
# Meta's pricing for one outgoing WhatsApp message, as reported in its status webhooks:
# pricing: { billable, pricing_model, category: marketing|utility|authentication|service, type }
class Shawky::MessageCost < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :message
  belongs_to :sender, class_name: 'User', optional: true

  def self.capture(message, pricing)
    return if pricing.blank? || !message.outgoing?

    record = find_or_initialize_by(message: message)
    record.update!(
      account_id: message.account_id, inbox_id: message.inbox_id, sender: message.sender.is_a?(User) ? message.sender : nil,
      category: pricing[:category], pricing_type: pricing[:type], billable: pricing[:billable] == true,
      country_code: TelephoneNumber.parse(message.conversation.contact.phone_number.to_s).country&.country_id,
      sent_at: message.created_at
    )
  end
end
