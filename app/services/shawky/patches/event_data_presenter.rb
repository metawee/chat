module Shawky::Patches::EventDataPresenter
  def push_data
    return super unless Shawky::Config.enabled?(:routing)

    super.merge(shawky_window_closes_at: Shawky::MessageWindow.closes_at(__getobj__))
  end
end
