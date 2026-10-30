# The company's own WhatsApp/SMS numbers are not customer data, so they stay visible.
module Shawky::BusinessNumbers
  def self.for(account)
    return [] if account.blank?

    account.inboxes.includes(:channel).filter_map { |inbox| inbox.channel.try(:phone_number) }
  end
end
