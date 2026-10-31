# A stand-in for the Shawky gateway (system.shawkygroup.com) for dev/staging and specs.
# Mounted at /mock_gateway when SHAWKY_MOCK_GATEWAY=true; specs use it through WebMock.
#
#   GET /mock_gateway/launch?phone=%2B2012...&name=...&salesman=rawda   like the Chrome extension: creates a
#                                                                       session and opens /shawky/launch
#   GET /mock_gateway/api/sessions/:id   (Bearer SHAWKY_GATEWAY_API_KEY) one-time session JSON, then 410
#   GET /mock_gateway/health
class Shawky::MockGateway
  SESSION_TTL = 120
  LEAD_FIELDS = %w[name phone salesman project status channel created_at site_state area cs_agent lead_id].freeze

  def self.call(env)
    new.call(env)
  end

  # Parks a lead like the real gateway and returns the session id.
  def self.create_session(lead, action: 'whatsapp')
    session_id = "s_#{SecureRandom.urlsafe_base64(18).tr('-', '_')}"
    payload = { action: action, createdAt: Time.now.utc.iso8601, lead: lead }
    Redis::Alfred.setex(session_key(session_id), payload.to_json, SESSION_TTL)
    session_id
  end

  def self.session_key(session_id)
    "SHAWKY::MOCK_GATEWAY::SESSION::#{session_id}"
  end

  def call(env)
    request = Rack::Request.new(env)
    case [request.request_method, request.path_info]
    in ['GET', '/health'] then json(200, { status: 'ok' })
    in ['GET', '/launch'] then launch(request)
    in ['GET', %r{\A/api/sessions/([\w-]+)\z}] then claim(request, Regexp.last_match(1))
    else json(404, { error: 'not found' })
    end
  end

  private

  def claim(request, session_id)
    return json(401, { error: 'unauthorized' }) unless request.get_header('HTTP_AUTHORIZATION') == "Bearer #{ENV.fetch('SHAWKY_GATEWAY_API_KEY', nil)}"

    data = Shawky::CrmLaunchStore.take_raw(self.class.session_key(session_id))
    data ? json(200, JSON.parse(data)) : json(410, { error: 'session expired or used' })
  end

  def launch(request)
    lead = request.params.slice(*LEAD_FIELDS).merge('extra' => { 'source' => 'mock_gateway' })
    session_id = self.class.create_session(lead, action: request.params.fetch('action', 'whatsapp'))
    [302, { 'Location' => "#{ENV.fetch('FRONTEND_URL', '')}/shawky/launch?session=#{session_id}" }, []]
  end

  def json(status, payload)
    [status, { 'Content-Type' => 'application/json' }, [payload.to_json]]
  end
end
