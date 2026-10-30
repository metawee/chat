# Signature scheme shared with n8n and the CRM:
#   X-Shawky-Timestamp: unix seconds
#   X-Shawky-Signature: sha256=<hex HMAC-SHA256(secret, timestamp + "." + raw_body)>
module Shawky::Hmac
  MAX_SKEW = 300

  module_function

  def sign(secret, timestamp, body)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, "#{timestamp}.#{body}")}"
  end

  def valid?(secret:, timestamp:, signature:, body:)
    return false if secret.blank? || timestamp.blank? || signature.blank?
    return false if (Time.now.to_i - timestamp.to_i).abs > MAX_SKEW

    ActiveSupport::SecurityUtils.secure_compare(sign(secret, timestamp, body), signature)
  end
end
