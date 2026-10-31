# Stores n8n's AI review of a conversation (score 0-100, summary, flags) as conversation
# custom attributes and leaves a private note for the team. Nothing is sent to the customer.
class Shawky::AiReview
  pattr_initialize [:conversation!, :score!, :summary!, :flags!]

  def perform
    conversation.update!(custom_attributes: conversation.custom_attributes.merge(
      'ai_score' => score, 'ai_summary' => summary, 'ai_flags' => flags, 'ai_reviewed_at' => Time.current.iso8601
    ))
    conversation.messages.create!(account: conversation.account, inbox: conversation.inbox, message_type: :outgoing,
                                  private: true, content: note)
  end

  private

  def note
    I18n.with_locale(conversation.account.locale || I18n.default_locale) do
      text = I18n.t('shawky.ai_review.note', score: score, summary: summary)
      flags.any? ? "#{text}\n#{I18n.t('shawky.ai_review.flags', flags: flags.join('، '))}" : text
    end
  end
end
