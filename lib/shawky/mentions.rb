# Markdown mentions for private notes; Chatwoot turns them into web, push and email notifications.
module Shawky::Mentions
  # The link part is URL-encoded: markdown ends a link at the first space.
  def self.markdown(users)
    users.map { |user| "[@#{user.name}](mention://user/#{user.id}/#{ERB::Util.url_encode(user.name)})" }.join(' ')
  end
end
