# == Schema Information
#
# Table name: shawky_crm_activities
#
#  id              :bigint           not null, primary key
#  attempts        :integer          default(0), not null
#  delivered_at    :datetime
#  kind            :string           not null
#  last_error      :string
#  payload         :jsonb            not null
#  status          :string           default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  event_id        :string           not null
#
# Indexes
#
#  idx_on_conversation_id_kind_created_at_3426dfb188  (conversation_id,kind,created_at)
#  index_shawky_crm_activities_on_account_id          (account_id)
#  index_shawky_crm_activities_on_conversation_id     (conversation_id)
#  index_shawky_crm_activities_on_event_id            (event_id) UNIQUE
#
# A WhatsApp activity reported to the CRM. The payload (and its event_id) is fixed when the
# record is created, so every retry sends exactly the same event and the CRM can dedupe it.
class Shawky::CrmActivity < ApplicationRecord
  # One "reply" activity per conversation per 24-hour window, plus one when it is resolved.
  REPLY_INTERVAL = 24.hours
  TIME_ZONE = 'Africa/Cairo'.freeze

  belongs_to :account
  belongs_to :conversation

  enum :status, { pending: 'pending', delivered: 'delivered', failed: 'failed' }
  validates :kind, inclusion: { in: %w[reply resolved] }
  validates :event_id, uniqueness: true

  after_create_commit { Shawky::CrmActivityJob.perform_later(self) }

  def self.track_reply(message)
    conversation = message.conversation
    return if exists?(conversation: conversation, kind: 'reply', created_at: REPLY_INTERVAL.ago..)

    track(conversation, kind: 'reply', agent: message.sender, status: 'sent', started_at: message.created_at)
  end

  def self.track_resolved(conversation)
    track(conversation, kind: 'resolved', agent: conversation.assignee, status: 'resolved', started_at: conversation.created_at)
  end

  def self.track(conversation, kind:, agent:, status:, started_at:)
    lead_id = conversation.contact.custom_attributes['lead_id']
    crm_agent_id = Shawky::CrmUserMapping.find_by(account: conversation.account, user: agent)&.crm_user_id if agent
    return if lead_id.blank? || crm_agent_id.blank?

    event_id = "evt_#{SecureRandom.uuid}"
    create!(
      account: conversation.account, conversation: conversation, kind: kind, event_id: event_id,
      payload: {
        event_id: event_id, lead_id: lead_id, agent_id: crm_agent_id, type: 'whatsapp', direction: 'outbound', status: status,
        started_at: started_at.in_time_zone(TIME_ZONE).iso8601, duration_sec: nil, summary: nil, recording_url: nil
      }
    )
  end
end
