require 'rails_helper'

RSpec.describe 'Shawky attachment link expiry', :shawky, type: :request do
  include_context 'with shawky world'

  around do |example|
    ActiveStorage.urls_expire_in = 24.hours
    example.run
  ensure
    ActiveStorage.urls_expire_in = nil
  end

  it 'stops serving a copied attachment link after it expires' do
    attachment = conversation.messages.first.attachments.new(account: account, file_type: :image)
    attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
    attachment.save!
    link = URI.parse(attachment.file_url).path

    get link
    expect(response).to have_http_status(:redirect)

    travel 25.hours do
      get link
      expect(response).to have_http_status(:not_found)
    end
  end
end
