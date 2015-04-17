
module Trace
    class << self
        def trace
            @trace ||= Logger.new(STDOUT)
        end

        def method_missing(method, *args, &block)
            self.trace.send(method, *args, &block)
        end
    end
end

module Log
    class << self
        def log
            @log ||= Logger.new(Cfg.log_file, 100, 2*1024*1024)
        end

        def method_missing(method, *args, &block)
            self.log.send(method, *args, &block)
        end
    end
end

