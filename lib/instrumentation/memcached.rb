module Telemetry
  module Instrumentation
    module Memcached
      def self.instrument_methods(the_class, method_names)
        method_names.each do |method_name|
          next unless the_class.method_defined?(method_name.to_sym) || the_class.private_method_defined?(method_name.to_sym)
          visibility = "private" unless the_class.method_defined?(method_name.to_sym)
          the_class.class_eval <<-EOD
            #{visibility}
            def #{method_name}_with_telemetry(*args, &block)
              key = args.first
              metrics = "Memcached/#{method_name} => " + key.to_s
              trace_id = Telemetry::SpanContext.new.current_trace_id
              span_id = Telemetry::SpanContext.new.current_span_id
              if trace_id.nil? || span_id.nil?
                span = Telemetry::Span.start_trace(Telemetry.service_name || "Memcached", nil)
              else
                span = Telemetry::Span.attach_span(trace_id, span_id)
              end
              f_ann = span.add_annotation('Memcached send', metrics)
              begin
                result = self.send("#{method_name}_without_telemetry", *args)
              ensure
                s_ann = span.add_annotation('Memcached received', metrics)
                s_ann.link_to_annotation(f_ann)
                span.end
              end
              result
            end
            alias #{method_name}_without_telemetry #{method_name}
            alias #{method_name} #{method_name}_with_telemetry
          EOD
        end
      end
    end
  end
end

commands = %w[get get_multi set add incr decr delete replace append prepend]
if defined? ::MemCache
  Telemetry::Instrumentation::Memcached.instrument_methods(::MemCache, commands)
end
if defined? ::Memcached
  if ::Memcached::VERSION >= '1.8.0'
    commands -= %w[get get_multi]
    commands += %w[single_get multi_get single_cas multi_cas]
  else
    commands << 'cas'
  end
  Telemetry::Instrumentation::Memcached.instrument_methods(::Memcached, commands)
end
if defined? ::Dalli::Client
  Telemetry::Instrumentation::Memcached.instrument_methods(::Dalli::Client, commands)
end
if defined? ::Spymemcached
  commands << 'multiget'
  Telemetry::Instrumentation::Memcached.instrument_methods(::Spymemcached, commands)
end