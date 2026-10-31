# Holds a lead claimed from the gateway between GET /shawky/launch and the dashboard picking
# it up, so the one-time session is spent at once and lead data (including the phone number)
# stays on the server. The browser only gets a random token in an encrypted, httpOnly cookie.
module Shawky::CrmLaunchStore
  COOKIE = :shawky_crm_launch
  TTL = 5.minutes

  module_function

  def put(account_id:, lead:, session_id:)
    token = SecureRandom.urlsafe_base64(32)
    Redis::Alfred.setex(key(token), { account_id: account_id, lead: lead, session_id: session_id }.to_json, TTL)
    token
  end

  def pending?(token)
    token.present? && Redis::Alfred.exists?(key(token))
  end

  def take(token)
    return if token.blank?

    data = take_raw(key(token))
    data && JSON.parse(data)
  end

  # Atomic read-and-delete. GETDEL would bypass redis-namespace, so use MULTI.
  def take_raw(key)
    Redis::Alfred.with do |redis|
      redis.multi do |transaction|
        transaction.get(key)
        transaction.del(key)
      end
    end.first
  end

  def key(token)
    "SHAWKY::CRM_LAUNCH::#{Digest::SHA256.hexdigest(token)}"
  end
end
