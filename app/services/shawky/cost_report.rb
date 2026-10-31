# Estimated WhatsApp spend per number and per agent from Meta's per-message pricing.
# Rates (USD per message) are entered by an administrator from Meta's rate card, by recipient
# country with a "default" fallback: { "SA" => { "marketing" => 0.0455, "service" => 0.0045 }, "default" => {...} }.
# Since 1 Oct 2026 the first 1,000 service messages per number per month are free.
class Shawky::CostReport
  FREE_SERVICE_MESSAGES_PER_MONTH = 1_000
  CATEGORIES = %w[service utility marketing authentication].freeze

  pattr_initialize [:account!, :from!, :to!]

  def perform
    rows = costs.to_a
    priced = rows.map { |row| [row, price(row)] }
    {
      from: from.to_date, to: to.to_date, currency: 'USD', rates_configured: rates.present?,
      numbers: summarize(priced, :inbox_id) { |id| account.inboxes.find_by(id: id)&.name },
      agents: summarize(priced, :sender_id) { |id| account.users.find_by(id: id)&.name }
    }
  end

  private

  def costs
    Shawky::MessageCost.where(account: account, sent_at: from..to).order(:sent_at)
  end

  def rates
    account.settings&.dig('shawky_message_rates') || {}
  end

  def price(row)
    return 0 if !row.billable || free_service_message?(row)

    (rates.dig(row.country_code.to_s, row.category) || rates.dig('default', row.category)).to_f
  end

  # Counts from the start of the message's month, not of the report, as Meta does.
  def free_service_message?(row)
    return false unless row.category == 'service'

    month = row.sent_at.all_month
    earlier = Shawky::MessageCost.where(inbox_id: row.inbox_id, category: 'service', sent_at: month.first...row.sent_at).count
    earlier < FREE_SERVICE_MESSAGES_PER_MONTH
  end

  def summarize(priced, key)
    priced.group_by { |row, _| row.public_send(key) }.map do |id, group|
      categories = CATEGORIES.index_with do |category|
        in_category = group.select { |row, _| row.category == category }
        { count: in_category.size, billable: in_category.count { |row, _| row.billable }, estimated_cost: in_category.sum(&:last).round(4) }
      end
      { id: id, name: yield(id), categories: categories, estimated_cost: group.sum(&:last).round(4) }
    end
  end
end
