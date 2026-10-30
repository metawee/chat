class Api::V1::Accounts::Shawky::ConversationsController < Api::V1::Accounts::BaseController
  def continue_on_active_number
    conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize conversation, :shawky_write?
    routing = ::Shawky::Routing.new(Current.account)
    return render json: { error: I18n.t('shawky.errors.no_active_number') }, status: :unprocessable_entity unless routing.configured?

    target = ::Shawky::ContinueOnActiveNumber.new(conversation: conversation, user: Current.user).perform
    render json: { id: target.display_id, inbox_id: target.inbox_id }
  end
end
