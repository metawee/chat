# A Shawky account: one WhatsApp inbox, a sales team with a supervisor, and a customer
# whose number shows up in every field Chatwoot stores it in.
# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.shared_context 'with shawky world' do
  let(:customer_phone) { '+966542921507' }
  let(:account) { create(:account) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', phone_number: '+201212239999',
                              sync_templates: false, validate_provider_config: false)
  end
  let(:inbox) { whatsapp_channel.inbox }
  let(:backup_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', phone_number: '+201212238888',
                              sync_templates: false, validate_provider_config: false)
  end
  let(:backup_inbox) { backup_channel.inbox }
  # Primary/backup routing as an administrator would configure it in Shawky settings.
  let(:configure_routing) do
    Shawky::Routing.new(account).update_settings('shawky_primary_inbox_id' => inbox.id, 'shawky_backup_inbox_id' => backup_inbox.id)
  end
  let(:team) { create(:team, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:supervisor) { create(:user, account: account, role: :agent) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:teammate) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user, account: account, role: :agent) }
  let(:contact) do
    create(:contact, account: account, name: customer_phone, phone_number: customer_phone, identifier: customer_phone,
                     additional_attributes: { 'whatsapp_number' => customer_phone.delete('+') })
  end
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: customer_phone.delete('+')) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, assignee: agent)
  end

  before do
    [supervisor, agent, teammate, outsider].each { |user| create(:inbox_member, user: user, inbox: inbox) }
    [agent, teammate].each { |user| create(:team_member, team: team, user: user) }
    Shawky::TeamSupervisor.create!(team: team, user: supervisor)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, sender: contact,
                     content: 'السلام عليكم')
  end
end

# rubocop:enable RSpec/MultipleMemoizedHelpers
# The subscriber part of the number must not appear in any formatting.
RSpec::Matchers.define :leak_phone do |phone|
  match do |body|
    body.to_s.gsub(/[\s\-().+]/, '').include?(phone.delete('^0-9')[-9..-4])
  end
end
