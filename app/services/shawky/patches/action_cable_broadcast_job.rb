module Shawky::Patches::ActionCableBroadcastJob
  private

  def broadcast_to_members(members, event_name, broadcast_data)
    account = Account.find_by(id: broadcast_data[:account_id])
    return super unless Shawky::PhoneMask.enabled?(account)

    super(members, event_name, Shawky::PayloadMasker.call(broadcast_data, exempt: Shawky::BusinessNumbers.for(account)))
  end
end
