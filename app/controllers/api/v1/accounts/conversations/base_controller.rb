class Api::V1::Accounts::Conversations::BaseController < Api::V1::Accounts::BaseController
  before_action :conversation

  private

  def conversation
    @conversation ||= Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize @conversation, :show?
  end
end
Api::V1::Accounts::Conversations::BaseController.prepend(Shawky::Patches::ConversationWriteGuard) # SHAWKY: history conversations are read-only
