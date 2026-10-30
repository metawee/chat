class Shawky::AdminNotificationsMailer < AdministratorNotifications::BaseMailer
  def number_failover(reason)
    send_notification(
      I18n.t('shawky.mailers.number_failover.subject'),
      action_url: settings_url('shawky'),
      meta: {
        'body' => I18n.t('shawky.mailers.number_failover.body'),
        'reason' => reason,
        'action' => I18n.t('shawky.mailers.number_failover.action')
      }
    )
  end
end
