# n8n flagged abusive or risky behaviour in a conversation: label it and notify the
# conversation's supervisors and every administrator at once (mention notifications).
class Shawky::AbuseAlert
  LABEL = 'abuse_flag'.freeze
  LABEL_COLOR = '#E5484D'.freeze

  pattr_initialize [:conversation!, :reason!]

  def perform
    account = conversation.account
    account.labels.find_or_create_by!(title: LABEL) { |label| label.color = LABEL_COLOR }
    conversation.add_labels([LABEL])

    recipients = Shawky::TeamSupervisor.users_for(conversation).or(User.where(id: account.administrators.select(:id)))
    I18n.with_locale(account.locale || I18n.default_locale) do
      text = I18n.t('shawky.abuse_alert.note', reason: reason)
      conversation.messages.create!(account: account, inbox: conversation.inbox, message_type: :outgoing, private: true,
                                    content: "#{text} #{Shawky::Mentions.markdown(recipients)}")
    end
  end
end
