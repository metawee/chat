require 'rails_helper'

RSpec.describe Shawky::PayloadMasker, :shawky do
  let(:phone) { '+966542921507' }

  it 'masks phone numbers anywhere in nested payloads' do
    payload = {
      meta: { sender: { phone_number: phone, identifier: phone, name: phone, additional_attributes: { 'x' => '966542921507' } } },
      contact_inbox: { source_id: '966542921507' },
      contact_inboxes: [{ source_id: '966542921507' }],
      wa_id: '966542921507'
    }

    expect(described_class.call(payload).to_json).not_to leak_phone(phone)
  end

  it 'masks records embedded in the payload' do
    contact_inbox = build(:contact_inbox, source_id: '966542921507')

    expect(described_class.call({ contact_inbox: contact_inbox }).to_json).not_to leak_phone(phone)
  end

  it 'does not alter what the customer typed' do
    payload = { content: "my number is #{phone}", content_attributes: { 'contacts' => [{ 'phone' => phone }] } }

    expect(described_class.call(payload)).to eq(payload)
  end

  it 'keeps provider and record identifiers' do
    payload = { phone_number_id: '106540352242922', business_account_id: '102290129340398', id: '123456789012' }

    expect(described_class.call(payload)).to eq(payload)
  end

  it 'keeps exempt business numbers visible' do
    expect(described_class.call({ phone_number: '+201212239999' }, exempt: ['+201212239999'])).to eq({ phone_number: '+201212239999' })
  end
end
