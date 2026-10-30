# Masks phone numbers in every API response and drops masked placeholders from
# incoming params, so a masked value sent back by a client never overwrites real data.
module Shawky::ApiPayloadMasking
  extend ActiveSupport::Concern

  included do
    before_action :shawky_strip_masked_params
    after_action :shawky_mask_response
  end

  private

  def shawky_strip_masked_params
    return unless Shawky::Config.enabled?(:phone_masking)

    shawky_strip_masked(params)
  end

  def shawky_strip_masked(parameters)
    parameters.each_key.to_a.each do |key|
      value = parameters[key]
      next parameters.delete(key) if Shawky::PhoneMask.masked?(value)

      parameters[key] = shawky_strip_masked_value(value)
    end
    parameters
  end

  def shawky_strip_masked_value(value)
    case value
    when ActionController::Parameters then shawky_strip_masked(value)
    when Array then value.reject { |item| Shawky::PhoneMask.masked?(item) }.map { |item| shawky_strip_masked_value(item) }
    else value
    end
  end

  def shawky_mask_response
    return unless Shawky::Config.enabled?(:phone_masking)
    return if response.body.blank?

    case response.media_type
    when 'application/json' then response.body = shawky_masked_json(response.body)
    when 'text/csv' then response.body = shawky_masked_csv(response.body)
    end
  end

  def shawky_masked_json(body)
    Shawky::PayloadMasker.call(JSON.parse(body), exempt: Shawky::BusinessNumbers.for(Current.account)).to_json
  rescue JSON::ParserError
    body
  end

  def shawky_masked_csv(body)
    masker = Shawky::PayloadMasker.new(Shawky::BusinessNumbers.for(Current.account))
    CSV.generate { |csv| CSV.parse(body).each { |row| csv << row.map { |cell| shawky_masked_cell(masker, cell) } } }
  end

  # CSVSafe prefixes formula-like cells ('+966…') with an apostrophe.
  def shawky_masked_cell(masker, cell)
    return masker.mask(cell) unless cell&.start_with?("'")

    masked = masker.mask(cell.delete_prefix("'"))
    Shawky::PhoneMask.masked?(masked) ? masked : cell
  end
end
