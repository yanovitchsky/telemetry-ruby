# visibleo_api
module Telemetry
  module Instrumentation
    module VisibleoApi
      def self.included(base)
        base.class_eval do
          methods = [:get, :post, :put, :delete]
          methods.each do |m|
            define_method("#{m}_with_telemetry") do |*args|
              path = self.http.path
              trace_id = Telemetry::SpanContext.new.current_trace_id
              span_id = Telemetry::SpanContext.new.current_span_id
              if trace_id.nil? || span_id.nil?
                span = Telemetry::Span.start_trace(Telemetry.service_name || path, nil)
              else
                span = Telemetry::Span.attach_span(trace_id, span_id)
                args[1] = {'X-Telemetry-TraceId' => trace_id.to_s, 'X-Telemetry-SpanId' => span_id.to_s}
              end
              f_ann = span.add_annotation('ClientSend', "#{m}: #{path}")
              result = self.send("#{m}_without_telemetry", *args)
              s_ann = span.add_annotation('ClientReceived', "#{m}: #{path}")
              s_ann.link_to_annotation(f_ann)
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

if defined?(::Visibleo) and defined?(::Visibleo::HttpRequest)
  ::Visibleo::HttpRequest.class_eval do
    include Telemetry::Instrumentation::VisibleoApi
  end
end