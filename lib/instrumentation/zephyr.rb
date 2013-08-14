class InstrumentedZephyr < DelegateClass(Zephyr)
  def perform(method, path_components, headers, expect, timeout, data=nil)
    Rails.logger.error "Holy shit, instrumenting zephyr!"
    super.perform(method, path_components, headers, expect, timeout, data=nil)
  end
end