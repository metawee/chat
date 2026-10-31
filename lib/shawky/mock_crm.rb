# A stand-in for the CRM's activities API until the real one is ready, speaking the same signed API.
# Mounted at /mock_crm when SHAWKY_MOCK_CRM=true (dev/staging only); specs use it through WebMock.
#
#   POST /mock_crm/api/integrations/shawky/activities   stores the activity
#   GET  /mock_crm/activities                           activities received so far
class Shawky::MockCrm
  ACTIVITIES_KEY = 'SHAWKY::MOCK_CRM::ACTIVITIES'.freeze

  def self.call(env)
    new.call(env)
  end

  def self.activities
    Redis::Alfred.lrange(ACTIVITIES_KEY).map { |activity| JSON.parse(activity) }
  end

  def call(env)
    request = Rack::Request.new(env)
    case [request.request_method, request.path_info]
    in ['POST', '/api/integrations/shawky/activities'] then signed(request) { |payload| store_activity(payload) }
    in ['GET', '/activities'] then json(200, self.class.activities)
    else json(404, { error: 'not found' })
    end
  end

  private

  def signed(request)
    body = request.body.read
    valid = request.get_header('HTTP_X_SHAWKY_KEY_ID') == ENV.fetch('SHAWKY_CRM_KEY_ID', nil) && Shawky::Hmac.valid?(
      secret: ENV.fetch('SHAWKY_CRM_SECRET', nil), timestamp: request.get_header('HTTP_X_SHAWKY_TIMESTAMP'),
      signature: request.get_header('HTTP_X_SHAWKY_SIGNATURE'), body: body
    )
    return json(401, { error: 'bad signature' }) unless valid

    yield JSON.parse(body)
  end

  def store_activity(payload)
    known = self.class.activities.any? { |activity| activity['event_id'] == payload['event_id'] }
    Redis::Alfred.lpush(ACTIVITIES_KEY, payload.to_json) unless known
    json(200, { ok: true })
  end

  def json(status, payload)
    [status, { 'Content-Type' => 'application/json' }, [payload.to_json]]
  end
end
