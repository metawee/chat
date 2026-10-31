require 'rails_helper'

RSpec.describe 'Shawky n8n AI review, abuse alert and agent scores', :shawky, type: :request do
  include_context 'with shawky world'

  let(:secret) { 'n8n-secret' }

  around { |example| ClimateControl.modify(SHAWKY_N8N_SECRET: secret) { example.run } }

  def signed_post(path, payload)
    body = payload.merge(account_id: account.id, conversation_id: conversation.display_id).to_json
    timestamp = Time.now.to_i
    post "/shawky/hooks/n8n/#{path}", params: body, headers: {
      'CONTENT_TYPE' => 'application/json', 'X-Shawky-Timestamp' => timestamp.to_s,
      'X-Shawky-Signature' => Shawky::Hmac.sign(secret, timestamp, body)
    }
  end

  describe 'ai_review' do
    it 'stores the score, summary and flags and leaves a private note' do
      signed_post('ai_review', ai_score: 82, ai_summary: 'رد سريع ومهذب', ai_flags: ['no_follow_up'])

      expect(response).to have_http_status(:ok)
      expect(conversation.reload.custom_attributes).to include('ai_score' => 82, 'ai_summary' => 'رد سريع ومهذب', 'ai_flags' => ['no_follow_up'])
      note = conversation.messages.where(private: true).last
      expect(note.content).to include('82/100')
    end

    it 'rejects a score outside 0-100 or of the wrong type' do
      [101, -1, '80', 80.5].each do |score|
        signed_post('ai_review', ai_score: score, ai_summary: 'x')
        expect(response).to have_http_status(:unprocessable_entity)
      end
      expect(conversation.reload.custom_attributes).not_to have_key('ai_score')
    end

    it 'rejects unsigned requests' do
      post '/shawky/hooks/n8n/ai_review', params: { ai_score: 1 }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'abuse_alert' do
    it 'labels the conversation and mentions the supervisor and administrators' do
      admin
      perform_enqueued_jobs { signed_post('abuse_alert', reason: 'العميل بيشتكي من ألفاظ الموظف') }

      expect(response).to have_http_status(:ok)
      expect(conversation.reload.label_list).to include('abuse_flag')
      note = conversation.messages.where(private: true).last
      expect(note.content).to include("mention://user/#{supervisor.id}/", "mention://user/#{admin.id}/")
      expect(Notification.where(notification_type: 'conversation_mention', user: [supervisor, admin]).count).to eq(2)
    end

    it 'requires a reason' do
      signed_post('abuse_alert', reason: '')
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'agent scores' do
    let(:path) { "/api/v1/accounts/#{account.id}/shawky/agent_scores" }

    before do
      Shawky::AiReview.new(conversation: conversation, score: 80, summary: 'ok', flags: []).perform
      other = create(:conversation, account: account, inbox: inbox, assignee: agent)
      Shawky::AiReview.new(conversation: other, score: 60, summary: 'ok', flags: ['late']).perform
      outsiders = create(:conversation, account: account, inbox: inbox, assignee: outsider)
      Shawky::AiReview.new(conversation: outsiders, score: 90, summary: 'ok', flags: []).perform
    end

    it 'shows a supervisor the average of their team only' do
      get path, headers: supervisor.create_new_auth_token, as: :json

      expect(response.parsed_body['payload']).to contain_exactly(
        a_hash_including('user_id' => agent.id, 'average_score' => 70.0, 'reviewed_count' => 2, 'flagged_count' => 1)
      )
    end

    it 'shows administrators every agent' do
      get path, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['payload'].pluck('user_id')).to eq([outsider.id, agent.id])
    end

    it 'refuses plain agents' do
      get path, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
