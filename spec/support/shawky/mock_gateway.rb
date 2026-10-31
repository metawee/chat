# Routes gateway calls to Shawky::MockGateway, which checks the API key like the real gateway.
RSpec.shared_context 'with mock gateway' do
  around do |example|
    ClimateControl.modify(SHAWKY_GATEWAY_URL: 'https://gateway.example.com', SHAWKY_GATEWAY_API_KEY: 'gw-key') { example.run }
  end

  before { stub_request(:get, %r{\Ahttps://gateway\.example\.com/}).to_rack(Shawky::MockGateway) }
end
