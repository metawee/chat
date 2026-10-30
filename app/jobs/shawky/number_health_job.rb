# Checks the primary number with Meta's health API and fails over to the backup
# number when Meta reports it banned, disconnected or deleted.
class Shawky::NumberHealthJob < ApplicationJob
  queue_as :low

  def perform(account)
    routing = Shawky::Routing.new(account)
    channel = routing.primary_inbox.channel
    Whatsapp::HealthService.new(channel).sync_health_status!
    status = channel.reload.phone_number_health['status']
    routing.failover!(reason: "health_status #{status}", details: { status: status }) if Shawky::Routing::FAILOVER_STATUSES.include?(status)
  rescue Whatsapp::HealthService::ApiError => e
    Rails.logger.warn("[SHAWKY] primary number health check failed for account #{account.id}: #{e.message}")
  end
end
