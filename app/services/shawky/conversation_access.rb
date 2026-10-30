# Single source of truth for who can see and act on which conversation.
#
# - administrator: everything
# - supervisor (Shawky::TeamSupervisor): conversations assigned to members of their teams,
#   conversations routed to their teams, and unassigned conversations in their teams' inboxes
# - agent: conversations assigned to them
#
# Anyone who can work a conversation can also read (not write) the contact's other conversations.
class Shawky::ConversationAccess
  attr_reader :user, :account

  def self.enabled?
    Shawky::Config.enabled?(:access_control)
  end

  def self.for(user, account)
    new(user, account)
  end

  # User ids allowed to receive realtime events about the conversation.
  def self.viewer_ids(conversation)
    account = conversation.account
    team_ids = [conversation.team_id]
    team_ids += if conversation.assignee_id
                  TeamMember.where(user_id: conversation.assignee_id).pluck(:team_id)
                else
                  TeamMember.where(user_id: conversation.inbox.inbox_members.select(:user_id)).pluck(:team_id)
                end
    supervisor_ids = Shawky::TeamSupervisor.where(account_id: account.id, team_id: team_ids.compact).pluck(:user_id)

    (account.administrators.pluck(:id) + supervisor_ids + [conversation.assignee_id]).compact.uniq
  end

  def initialize(user, account)
    @user = user
    @account = account
  end

  def administrator?
    account_user&.administrator?
  end

  def supervisor?
    supervised_team_ids.any?
  end

  # Conversations the user works on: lists, filters, counts and writes.
  def workable_conversations
    return account.conversations if administrator?

    scope = account.conversations.where(assignee_id: user.id)
    return scope unless supervisor?

    scope.or(account.conversations.where(assignee_id: team_member_ids))
         .or(account.conversations.where(team_id: supervised_team_ids))
         .or(account.conversations.where(assignee_id: nil, inbox_id: team_inbox_ids))
  end

  # Workable conversations plus the read-only history of the same contacts.
  def readable_conversations
    return account.conversations if administrator?

    account.conversations.where(contact_id: workable_conversations.select(:contact_id))
  end

  def filter_workable(relation)
    return relation if administrator?

    relation.where(id: workable_conversations.select(:id))
  end

  def filter_readable(relation)
    return relation if administrator?

    relation.where(id: readable_conversations.select(:id))
  end

  def readable?(conversation)
    administrator? || readable_conversations.exists?(id: conversation.id)
  end

  def writable?(conversation)
    administrator? || workable_conversations.exists?(id: conversation.id)
  end

  def filter_contacts(relation)
    return relation if administrator?

    relation.where(id: workable_conversations.select(:contact_id))
  end

  # Creating contacts or conversations by typing a number is not allowed for plain agents.
  def can_start_conversations?
    administrator? || supervisor?
  end

  def can_edit_contact_identity?
    administrator?
  end

  def can_search_by_phone?
    administrator?
  end

  def can_assign_to?(assignee)
    return true if administrator? || supervisor?
    return false unless assignee.is_a?(User)

    TeamMember.where(user_id: user.id).exists?(team_id: TeamMember.where(user_id: assignee.id).select(:team_id))
  end

  private

  def account_user
    @account_user ||= AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def supervised_team_ids
    @supervised_team_ids ||= Shawky::TeamSupervisor.where(account_id: account.id, user_id: user.id).pluck(:team_id)
  end

  def team_member_ids
    @team_member_ids ||= TeamMember.where(team_id: supervised_team_ids).pluck(:user_id) | [user.id]
  end

  def team_inbox_ids
    @team_inbox_ids ||= InboxMember.joins(:inbox).where(inboxes: { account_id: account.id }, user_id: team_member_ids).pluck(:inbox_id)
  end
end
