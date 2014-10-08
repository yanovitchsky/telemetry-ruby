module Telemetry
  module Instrumentation
    module Neography
      def self.included(base)
        base.class_eval do
          methods = ["get", "post", "put", "delete"]
          methods.each do |m|
            define_method("#{m}_with_telemetry") do |path, options = {}|
              trace_id = Telemetry::SpanContext.new.current_trace_id
              span_id = Telemetry::SpanContext.new.current_span_id
              if trace_id.nil? || span_id.nil?
                span = Telemetry::Span.start_trace(Telemetry.service_name || path, nil)
              else
                span = Telemetry::Span.attach_span(trace_id, span_id)
                # args[1] = {'X-Telemetry-TraceId' => trace_id.to_s, 'X-Telemetry-SpanId' => span_id.to_s}
              end
              span.add_annotation('NeographySend', "#{m}: #{path}-#{options}")
              result = self.send("#{m}_without_telemetry", path, options = {})
              span.add_annotation('NeographyReceived', "#{m}: #{path}-#{options}")
              span.end
              result
            end

            class_eval "alias #{m}_without_telemetry #{m}"
            class_eval "alias #{m} #{m}_with_telemetry"
          end
        end
      end
    end
  end
end

if defined?(::Neography)
  p "hey Neography is defined"
  ::Neography::Connection.class_eval do
    include Telemetry::Instrumentation::Neography
  end
end