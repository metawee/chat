# Routes CRM calls to Shawky::MockCrm, which checks signatures like the real CRM.
RSpec.shared_context 'with mock crm' do
  let(:crm_env) do
    { SHAWKY_CRM_BASE_URL: 'https://crm.example.com', SHAWKY_CRM_KEY_ID: 'shawky-key', SHAWKY_CRM_SECRET: 'crm-secret' }
  end

  around { |example| ClimateControl.modify(crm_env) { example.run } }

  before do
    stub_request(:post, %r{\Ahttps://crm\.example\.com/}).to_rack(Shawky::MockCrm)
    Redis::Alfred.delete(Shawky::MockCrm::ACTIVITIES_KEY)
  end
end
