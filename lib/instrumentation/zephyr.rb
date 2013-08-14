class Zephyr
  alias_method :old_perform, :perform

  def perform(method, path_components, headers, expect, timeout, data=nil)
    span = Telemetry::Span.start_span(uri(path_components))
    span.add_annotation('ClientSent')

    begin
      old_perform(method, path_components, headers, expect, timeout, data)
    rescue Exception => e
      span.add_annotation('ClientException', e.class.name)
      raise
    ensure
      span.add_annotation('ClientReceived')
      span.end
    end
  end
end