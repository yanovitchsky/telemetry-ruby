require 'instrumentation/rack'
require 'instrumentation/goliath'
require 'instrumentation/zephyr'
require 'instrumentation/visibleo_api'
require 'instrumentation/karibu'
require 'instrumentation/moped'
require 'instrumentation/memcached'
require 'instrumentation/redis'
require 'instrumentation/neography'

require 'sinks/telemetry_service'
require "sinks/udp_service"
require "sinks/redis_service"
require "sinks/kafka_service"

# The Telemetry module models a dapper(http://research.google.com/pubs/pub36356.html)-like
# system for distributed execution tracing.
module Telemetry
  class << self
    attr_accessor :span_sinks
    attr_accessor :max_id
    attr_accessor :service_name
  end
  Telemetry.span_sinks = []
  Telemetry.max_id = (2**63) - 1
  Telemetry.service_name = nil

  # Ruby 1.8.7 only does seconds as a float. Newer versions have explicit nanosecond
  # support. Until then...
  def self.now_in_nanos
    (Time.now.to_f * 1000000000).to_i
  end

  # Stores the span context so information can be carried across function call boundaries
  # without resorting to ugly parameter passing. The Java analog uses a ThreadLocal variable.
  class SpanContext
    @@spans = []

    # Gets the current trace ID.
    def current_trace_id
      if @@spans.empty?
        nil
      else
        @@spans.slice(-1).trace_id
      end
    end

    # Gets the current trace
    def current_trace
      if @@spans.empty?
        nil
      else
        @@spans.slice(-1)
      end
    end

    # Gets the current span ID.
    def current_span_id()
      if @@spans.empty?
        nil
      else
        @@spans.slice(-1).id
      end
      # if Thread.current[:spans].empty?
      #   nil
      # else
      #   Thread.current[:spans].slice(-1).id
      # end
    end

    # Start the given span. Switches the current context to run in the context of this span
    # and all of it's associated IDs.
    def start_span(span)
      @@spans.push(span)
    end

    # Ends the given span. Restores the current context to run in the context of the span
    # started immediately before this span.
    def end_span(span)
      popped_span = @@spans.pop()

      # It's possible that someone may have started a span without ending it. Shame on them,
      # but shame on us (too) if we don't guard against it.
      while !popped_span.id.eql?(span.id)
        popped_span = @@spans.pop()
      end
    end

    def inspect
      "SpanContext(current = #{@@spans.slice(-1).inspect}, length = #{@@spans.length})"
    end
  end

  # Models a span of execution within a trace.
  class Span
    attr_reader :trace_id
    attr_reader :id
    attr_reader :parent_id
    attr_reader :name
    attr_reader :start_time_nanos
    attr_reader :duration
    attr_reader :custom_attributes
    attr_reader :endpoint
    @@context = SpanContext.new


    ANNOTATION_START = 1  # a annotation beginning
    ANNOTATION_END   = 2  # a annotation end
    ANNOTATION_ERROR = 3  # a annotation error 

    # Start a brand new trace.
    def self.start_trace(name, endpoint)
      start(name, nil, nil, nil, true, endpoint)
    end

    # Start a new span within a trace.
    def self.start_span(name, endpoint)
      start(name, nil, nil, nil, true, endpoint)
    end

    # Attach to an existing span. This is useful when a span has been created elsewhere
    # (probably on another host) and you'd like to log annotations against that span locally.
    def self.attach_span(trace_id, span_id)
      start(nil, trace_id, span_id, nil, false, nil)
    end

    def self.start(name, trace_id, span_id, parent_span_id, log_span, endpoint)
      # Thread.current[:spans] ||= []
      trace_id ||= @@context.current_trace_id() || rand(Telemetry.max_id)
      span_id ||= rand(Telemetry.max_id)
      parent_span_id ||= @@context.current_span_id() # attention de marche pas avec les threads.

      span = Span.new(trace_id, span_id, parent_span_id, name, Telemetry.now_in_nanos, log_span, endpoint)
      @@context.start_span(span)
      # Thread.current[:spans] << span
      span
    end

    def initialize(trace_id, id, parent_id, name, start_time_nanos, log_span, endpoint)
      @trace_id = trace_id
      @id = id
      @parent_id = parent_id
      @name = name
      @start_time_nanos = start_time_nanos
      @duration = -1
      @log_span = log_span
      @endpoint = endpoint
      @annotations = []
    end

    # Adds an annotation to the current span.
    def add_annotation(name, message = nil)
      ann = AnnotationData.new(name, message)
      @annotations.push(ann)
      ann
      # p "in add annotations #{@annotations}"
    end

    def add_start_annotation(name, message=nil)
      annotation = add_annotation(name, message)
      annotation.type = ANNOTATION_START
      annotation
    end

    def add_end_annotation(name, message=nil)
      annotation = add_annotation(name, message)
      annotation.type = ANNOTATION_END
      annotation
    end

    def add_error_annotation(name, message=nil)
      annotation = add_annotation(name, message)
      annotation.type = ANNOTATION_ERROR
      annotation
    end

    # Ends a span.
    def end
      # Stop the span timer.
      @duration = Telemetry.now_in_nanos - @start_time_nanos

      # Pop the span context.
      @@context.end_span(self)

      # Log the span (if enabled) and any annotations to any configured span sink(s).
      Telemetry.span_sinks.each { |sink|
        if (@log_span)
          p sink
          sink.record(self)
        end

        # p "in sink annotations #{@annotations}"
        @annotations.each { |annotation|
          # p annotation
          sink.record_annotation(@trace_id, @id, annotation)
        }
      }
    end

    def get_annotations
      @annotations
    end

    # Add custom infos to span
    def add_infos(hash)
      self.custom_attributes.merge!(hash)
    end

    def inspect
      "Span(name = #{name}, trace_id = #{trace_id}, id = #{id}, parent_id = #{parent_id}) duration = #{duration}"
    end

    def to_hash
      {
        name: name,
        trace_id: trace_id,
        id: id,
        parent_id: parent_id,
        start_time_nanos: start_time_nanos,
        duration: duration,
        endpoint: endpoint,
        custom_attributes: custom_attributes
      }
    end
  end

  # Point in time annotation within a span.
  class AnnotationData
    attr_reader :start_time_nanos
    attr_reader :name
    attr_reader :message
    attr_accessor :luid
    attr_accessor :type

    def initialize(name, message = nil)
      @start_time_nanos = Telemetry.now_in_nanos
      @name = name
      @message = message
    end

    def to_hash
      {
        name: @name,
        message: @message,
        start_time_nanos: @start_time_nanos,
        luid: @luid,
        type: @type
      }
    end

    def link_to_annotation(annotation)
      if annotation.luid.nil?
        luid = SecureRandom.hex
        @luid = annotation.luid = luid
      end
    end

    def inspect
      "AnnotationData(name = #{name}, message = #{message}"
    end
  end
end
