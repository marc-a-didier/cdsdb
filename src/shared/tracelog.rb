
module Trace

    GST = 'GST: '.blue.bold
    PPQ = 'PPQ: '.blue.bold
    NET = 'NET: '.blue.bold
    SQL = 'SQL: '.blue.bold
    DBC = 'DBC: '.blue.bold
    IMC = 'IMC: '.blue.bold

    class << self
        def trace
            @trace ||= Logger.new(STDOUT)
        end

        def method_missing(method, *args, &block)
            self.trace.send(method, *args, &block)
        end

        def gst(msg)
            self.trace.debug(GST+msg) if Cfg.trace_gst
        end

        def ppq(msg)
            self.trace.debug(PPQ+msg) if Cfg.trace_gstqueue
        end

        def net(msg)
            self.trace.debug(NET+msg) if Cfg.trace_network
        end

        def sql(msg)
            self.trace.debug(SQL+msg) if Cfg.trace_sql
        end

        def dbc(msg)
            self.trace.debug(DBC+msg) if Cfg.trace_db_cache
        end

        def imc(msg)
            self.trace.debug(IMC+msg) if Cfg.trace_image_cache
        end
    end
end

module Log
    class << self
        def log
            @log ||= Logger.new(Cfg.log_file, 100, 20*1024*1024)
        end

        def method_missing(method, *args, &block)
            self.log.send(method, *args, &block)
        end
    end
end

