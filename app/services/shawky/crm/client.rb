# Signed activity calls to the CRM (spec sent to the CRM company). Launches go through the gateway.
#   X-Shawky-Key-Id, X-Shawky-Timestamp, X-Shawky-Signature: sha256=HMAC(secret, timestamp + "." + raw_body)
# Configured with SHAWKY_CRM_BASE_URL, SHAWKY_CRM_KEY_ID and SHAWKY_CRM_SECRET (env only, never logged).
class Shawky::Crm::Client
  ACTIVITIES_PATH = '/api/integrations/shawky/activities'.freeze
  TIMEOUT = 10

  def post_activity(payload)
    post(ACTIVITIES_PATH, payload)
  end

  private

  def post(path, payload)
    body = payload.to_json
    timestamp = Time.now.to_i.to_s
    response = HTTParty.post(
      "#{base_url}#{path}",
      body: body, timeout: TIMEOUT,
      headers: {
        'Content-Type' => 'application/json', 'X-Shawky-Key-Id' => ENV.fetch('SHAWKY_CRM_KEY_ID'),
        'X-Shawky-Timestamp' => timestamp, 'X-Shawky-Signature' => Shawky::Hmac.sign(ENV.fetch('SHAWKY_CRM_SECRET'), timestamp, body)
      }
    )
    raise Shawky::Crm::Error, response.code unless response.success?

    response.parsed_response
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
    raise Shawky::Crm::Error.new(nil, e.class.name)
  end

  def base_url
    url = ENV.fetch('SHAWKY_CRM_BASE_URL').chomp('/')
    raise ArgumentError, 'SHAWKY_CRM_BASE_URL must use https' if Rails.env.production? && !url.start_with?('https://')

    url
  end
end
