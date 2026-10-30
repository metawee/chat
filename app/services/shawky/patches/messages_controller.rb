# Upstream stores a free-form WhatsApp message sent outside the 24-hour window and marks it
# failed. Refuse it up front so agents (web or mobile) know to pick a template.
module Shawky::Patches::MessagesController
  def create
    return super unless Shawky::Config.enabled?(:routing) && shawky_outside_window_free_form?

    render json: { error: I18n.t('shawky.errors.outside_messaging_window') }, status: :unprocessable_entity
  end

  private

  def shawky_outside_window_free_form?
    @conversation.inbox.channel_type == 'Channel::Whatsapp' &&
      !ActiveModel::Type::Boolean.new.cast(params[:private]) &&
      params[:template_params].blank? &&
      !@conversation.can_reply?
  end
end
