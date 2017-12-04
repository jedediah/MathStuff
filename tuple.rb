
class Tuple < Array
    class << self
        def new(*args, &block)
            if args.empty? || args[0] == 0
                @empty ||= super()
            else
                super(*args, &block).freeze
            end
        end

        def [](*els)
            if els.empty?
                new
            else
                super(*els).freeze
            end
        end
    end
end

