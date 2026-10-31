# Per-request (and per-job) cache; Rails resets CurrentAttributes after each request and job,
# so a settings change is seen by the next request or broadcast without a restart.
class Shawky::RequestCache < ActiveSupport::CurrentAttributes
  attribute :settings
end
