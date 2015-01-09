module Telemetry
  module Instrumentation
    module Moped
      def logging_with_telemetry(operations, &block)
        operation_name, collection = determine_operation_and_collection(operations.first)
        log_statement = operations.first.log_inspect.encode("UTF-8")
        operation = case operation_name
                    when 'INSERT', 'UPDATE', 'CREATE'               then 'save'
                    when 'QUERY', 'COUNT', 'GET_MORE', "AGGREGATE"  then 'find'
                    when 'DELETE'                                   then 'destroy'
                    else
                      nil
                    end

        command = Proc.new { logging_without_telemetry(operations, &block) }
        res = nil

        if operation
          metric = "ActiveRecord/#{collection}/#{operation}"

          trace_id = Telemetry::SpanContext.new.current_trace_id
          span_id = Telemetry::SpanContext.new.current_span_id
          if trace_id.nil? || span_id.nil?
            span = Telemetry::Span.start_trace(Telemetry.service_name || "moped trace", nil)
          else
            span = Telemetry::Span.attach_span(trace_id, span_id)
          end

          f_ann = span.add_start_annotation('Moped query sent', operations)
          begin
            res = command.call
          ensure
            s_ann = span.add_end_annotation('Moped query received', operations)
            s_ann.link_to_annotation(f_ann)
            span.end
          end
        else
          res =  command.call
        end
        res
      end

      def determine_operation_and_collection(operation)
        # A voir comment logger les infos
        # p "---------------------------------------------"
        # p operation
        # p "---------------------------------------------"
        log_statement = operation.log_inspect.encode("UTF-8")
        collection = "Unknown"
        if operation.respond_to?(:collection)
          collection = operation.collection
        end
        operation_name = log_statement.split[0]
        if operation_name == 'COMMAND' && log_statement.include?(":mapreduce")
          operation_name = 'MAPREDUCE'
          collection = log_statement[/:mapreduce=>"([^"]+)/,1]
        elsif operation_name == 'COMMAND' && log_statement.include?(":count")
          operation_name = 'COUNT'
          collection = log_statement[/:count=>"([^"]+)/,1]
        elsif operation_name == 'COMMAND' && log_statement.include?(":aggregate")
          operation_name = 'AGGREGATE'
          collection = log_statement[/:aggregate=>"([^"]+)/,1]
        end
        return operation_name, collection
      end
    end
  end
end

if defined?(::Moped)
  ::Moped::Node.class_eval do
    include ::Telemetry::Instrumentation::Moped
    alias :logging_without_telemetry :logging
    alias :logging :logging_with_telemetry
  end
end