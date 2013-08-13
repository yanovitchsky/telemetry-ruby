module Rack
  class RequestTracer
    def initialize(app, options = {})
      Rails.logger.error "INITIALIZING MY REQUEST TRACKER GEM!"
      @app, @options = app, options
    end

    def call(env)
      Rails.logger.error "HOLY SHIT WE'RE TRACING A REQUEST FROM A GEM!"
      return @app.call(env)
    end
  end
end