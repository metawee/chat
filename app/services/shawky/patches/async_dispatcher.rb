module Shawky::Patches::AsyncDispatcher
  def listeners
    super + [Shawky::EventListener.instance]
  end
end
