# A stand-in for the CRM until the real one is ready, speaking the same signed API.
# Mounted at /mock_crm when SHAWKY_MOCK_CRM=true (dev/staging only); specs use it through WebMock.
#
#   GET  /mock_crm/leads/:lead_id?agent=U-77&mobile=%2B9665...  lead page with a WhatsApp button
#   POST /mock_crm/api/integrations/shawky/resolve               { code, action } -> lead JSON
#   POST /mock_crm/api/integrations/shawky/activities            stores the activity
#   GET  /mock_crm/activities                                    activities received so far
class Shawky::MockCrm
  CODE_TTL = 60
  ACTIVITIES_KEY = 'SHAWKY::MOCK_CRM::ACTIVITIES'.freeze
  SAMPLE_LEAD = {
    'lead_id' => 'L-104582', 'name' => 'عبدالرحمن', 'mobile' => '+966542921507', 'whatsapp' => '+966542921507',
    'status' => 'Fresh', 'project' => 'طنطا', 'channel' => 'شيفت نهار', 'site_state' => 'محاره', 'area_sqm' => 120,
    'property_type' => 'شقه', 'created_at' => '2026-10-30T18:35:00+02:00',
    'agent' => { 'id' => 'U-77', 'name' => 'Hasnaa emad', 'role' => 'salesman' }, 'action' => 'whatsapp'
  }.freeze

  def self.call(env)
    new.call(env)
  end

  # Issues a single-use code for a lead, like the real CRM does behind its button.
  def self.issue_code(lead)
    code = SecureRandom.urlsafe_base64(24)
    Redis::Alfred.setex(code_key(code), lead.to_json, CODE_TTL)
    code
  end

  def self.code_key(code)
    "SHAWKY::MOCK_CRM::CODE::#{code}"
  end

  def self.activities
    Redis::Alfred.lrange(ACTIVITIES_KEY).map { |activity| JSON.parse(activity) }
  end

  def call(env)
    request = Rack::Request.new(env)
    case [request.request_method, request.path_info]
    in ['POST', '/api/integrations/shawky/resolve'] then signed(request) { |payload| resolve(payload) }
    in ['POST', '/api/integrations/shawky/activities'] then signed(request) { |payload| store_activity(payload) }
    in ['GET', '/activities'] then json(200, self.class.activities)
    in ['GET', %r{\A/leads/([\w-]+)\z}] then lead_page(request, Regexp.last_match(1))
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

  def resolve(payload)
    lead = Shawky::CrmLaunchStore.take_raw(self.class.code_key(payload['code'].to_s))
    return json(410, { error: 'code invalid or expired' }) if lead.nil?

    lead = JSON.parse(lead)
    return json(409, { error: 'action mismatch' }) if payload['action'] != lead['action']

    json(200, lead)
  end

  def store_activity(payload)
    known = self.class.activities.any? { |activity| activity['event_id'] == payload['event_id'] }
    Redis::Alfred.lpush(ACTIVITIES_KEY, payload.to_json) unless known
    json(200, { ok: true })
  end

  def lead_page(request, lead_id)
    lead = SAMPLE_LEAD.merge('lead_id' => lead_id)
    lead = lead.merge('agent' => lead['agent'].merge('id' => request.params['agent'])) if request.params['agent'].present?
    lead = lead.merge('mobile' => request.params['mobile'], 'whatsapp' => request.params['mobile']) if request.params['mobile'].present?
    url = "#{ENV.fetch('FRONTEND_URL', '')}/chat?code=#{self.class.issue_code(lead)}"
    [200, { 'Content-Type' => 'text/html; charset=utf-8' }, [lead_html(lead, url)]]
  end

  def lead_html(lead, url)
    button_style = 'background:#25d366;color:#fff;padding:12px 20px;border-radius:8px;text-decoration:none'
    "<!DOCTYPE html><html lang='ar' dir='rtl'><meta charset='utf-8'><title>Mock CRM</title>" \
      "<body style='font-family:sans-serif;padding:32px'><h2>Mock CRM — #{ERB::Util.h(lead['lead_id'])}</h2>" \
      "<p>#{ERB::Util.h(lead['name'])} — #{ERB::Util.h(lead['project'])}</p>" \
      "<a id='whatsapp' href='#{ERB::Util.h(url)}' style='#{button_style}'>WhatsApp</a></body></html>"
  end

  def json(status, payload)
    [status, { 'Content-Type' => 'application/json' }, [payload.to_json]]
  end
end
