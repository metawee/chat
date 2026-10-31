# A failed call to the Shawky gateway. status is the HTTP status, or nil when unreachable.
class Shawky::Gateway::Error < StandardError
  attr_reader :status

  def initialize(status, message = nil)
    @status = status
    super(message || "Gateway responded with #{status.inspect}")
  end
end
