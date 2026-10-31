# Shawky features are on in production. Upstream specs run with them off so they keep
# asserting upstream behaviour; specs tagged `shawky: true` run with them on.
SHAWKY_FLAG_KEYS = %w[SHAWKY_PHONE_MASKING SHAWKY_ACCESS_CONTROL SHAWKY_INTEGRATIONS_ALLOWLIST SHAWKY_ROUTING SHAWKY_CRM_INTEGRATION
                      SHAWKY_GATEWAY_LAUNCH].freeze

RSpec.configure do |config|
  config.around do |example|
    value = example.metadata[:shawky] ? 'true' : 'false'
    ClimateControl.modify(SHAWKY_FLAG_KEYS.index_with { value }) { example.run }
  end
end
