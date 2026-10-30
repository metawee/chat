require 'rails_helper'

RSpec.describe Integrations::App, :shawky do
  let(:account) { create(:account) }

  it 'only allows allowlisted integrations' do
    expect(described_class.find(id: 'webhook').active?(account)).to be(true)
    expect(described_class.find(id: 'dashboard_apps').active?(account)).to be(false)
    expect(described_class.find(id: 'dialogflow').active?(account)).to be(false)
  end

  it 'refuses to create hooks for other integrations' do
    hook = build(:integrations_hook, account: account, app_id: 'slack')

    expect(hook).not_to be_valid
    expect(hook.errors[:app_id]).to be_present
  end
end
