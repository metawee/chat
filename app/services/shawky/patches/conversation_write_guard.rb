# Prepended to the conversation controllers: any non-GET request needs write access,
# so an agent can read a contact's older conversations but not act on them.
module Shawky::Patches::ConversationWriteGuard
  READ_ONLY_SAFE_ACTIONS = %w[update_last_seen].freeze

  private

  def conversation
    super
    return @conversation if request.get? || READ_ONLY_SAFE_ACTIONS.include?(action_name)

    authorize @conversation, :shawky_write?
    @conversation
  end
end
