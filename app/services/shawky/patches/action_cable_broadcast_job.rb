module Shawky::Patches::ActionCableBroadcastJob
  private

  def broadcast_to_members(members, event_name, broadcast_data)
    return super unless Shawky::Config.enabled?(:phone_masking)

    account = Account.find_by(id: broadcast_data[:account_id])
    super(members, event_name, Shawky::PayloadMasker.call(broadcast_data, exempt: Shawky::BusinessNumbers.for(account)))
  end
end
