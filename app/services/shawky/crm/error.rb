# A failed call to the CRM. status is the HTTP status, or nil when the CRM was unreachable.
class Shawky::Crm::Error < StandardError
  attr_reader :status

  def initialize(status, message = nil)
    @status = status
    super(message || "CRM responded with #{status.inspect}")
  end

  # Unreachable, rate limited or a server error: worth retrying later.
  def retryable?
    status.nil? || status == 429 || status >= 500
  end
end
