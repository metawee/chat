# Server-to-server calls to the Shawky gateway (system.shawkygroup.com), which receives the CRM
# buttons and parks each lead in a one-time session. Configured with SHAWKY_GATEWAY_URL and
# SHAWKY_GATEWAY_API_KEY. Response bodies carry phone numbers, so they are never logged.
class Shawky::Gateway::Client
  TIMEOUT = 10

  # One-time: the gateway answers 410 once a session was claimed or expired.
  def claim_session(session_id)
    get("/api/sessions/#{ERB::Util.url_encode(session_id)}")
  end

  def health
    get('/health')
  end

  private

  def get(path)
    response = HTTParty.get(
      "#{ENV.fetch('SHAWKY_GATEWAY_URL').chomp('/')}#{path}",
      headers: { 'Authorization' => "Bearer #{ENV.fetch('SHAWKY_GATEWAY_API_KEY')}", 'Accept' => 'application/json' },
      timeout: TIMEOUT
    )
    raise Shawky::Gateway::Error, response.code unless response.success?

    response.parsed_response
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
    raise Shawky::Gateway::Error.new(nil, e.class.name)
  end
end
