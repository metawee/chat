# Writes the conversations active in an export's date range, with their messages in that
# range, as JSON (one object per conversation) or CSV (one row per message). Phone numbers
# are masked unless the administrator asked for them (the export is audited either way).
class Shawky::DataExportBuilder
  CSV_HEADERS = %w[conversation_id conversation_created_at inbox status contact_id contact_name contact_phone lead_id assignee
                   message_id message_created_at direction private sender content attachments].freeze

  pattr_initialize [:export!]

  def write(io)
    export.file_format == 'csv' ? write_csv(io) : write_json(io)
  end

  private

  def conversations
    range = export.date_range
    export.account.conversations.where(created_at: ..range.last).where(last_activity_at: range.first..)
          .includes(:inbox, :assignee, :contact).order(:id)
  end

  def messages(conversation)
    conversation.messages.where(created_at: export.date_range).includes(:attachments, :sender).order(:created_at)
  end

  def write_json(io)
    io.write('[')
    conversations.find_each.with_index do |conversation, index|
      io.write(',') if index.positive?
      io.write(protect(conversation_hash(conversation)).to_json)
    end
    io.write(']')
  end

  def write_csv(io)
    io.write(CSVSafe.generate_line(CSV_HEADERS))
    conversations.find_each do |conversation|
      conversation_data = protect(conversation_hash(conversation))
      conversation_data[:messages].each { |message| io.write(CSVSafe.generate_line(csv_row(conversation_data, message))) }
    end
  end

  def csv_row(conversation, message)
    contact = conversation[:contact]
    [conversation[:id], conversation[:created_at], conversation[:inbox], conversation[:status], contact[:id], contact[:name],
     contact[:phone_number], contact[:lead_id], conversation[:assignee], message[:id], message[:created_at], message[:direction],
     message[:private], message[:sender], message[:content], message[:attachments].join(' ')]
  end

  def conversation_hash(conversation)
    contact = conversation.contact
    {
      id: conversation.display_id, created_at: conversation.created_at.iso8601, inbox: conversation.inbox.name,
      status: conversation.status, assignee: conversation.assignee&.name,
      contact: { id: contact.id, name: contact.name, phone_number: contact.phone_number, lead_id: contact.custom_attributes['lead_id'],
                 custom_attributes: contact.custom_attributes },
      messages: messages(conversation).map { |message| message_hash(message) }
    }
  end

  def message_hash(message)
    {
      id: message.id, created_at: message.created_at.iso8601, direction: message.message_type, private: message.private,
      sender: message.sender.try(:name), content: message.content,
      attachments: message.attachments.map { |attachment| attachment.file.attached? ? attachment.file.filename.to_s : attachment.file_type }
    }
  end

  def protect(data)
    export.include_phone_numbers ? data : Shawky::PayloadMasker.call(data, exempt: Shawky::BusinessNumbers.for(export.account))
  end
end
