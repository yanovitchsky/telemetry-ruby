class Zephyr
  alias_method :old_perform, :perform

  def perform(method, path_components, headers, expect, timeout, data=nil)
    Rails.logger.error "Holy shit, instrumenting zephyr!"
    old_perform(method, path_components, headers, expect, timeout, data)
  end
end