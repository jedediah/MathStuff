
module TypeExpression
    module Operations
        def ~
            Negation.new(self)
        end

        def &(x)
            Intersection.new(self, x)
        end

        def |(x)
            Union.new(self, x)
        end
    end

    class Base
        include Operations
    end

    class Empty < Base
        def self.new
            @instance ||= super
        end

        def inspect
            '{}'
        end

        def ===(x)
            false
        end

        def potential_modules
            Set.empty
        end
    end

    class Negation < Base
        attr :type

        class << self
            def new(type)
                if type.is_a? Empty
                    Object
                elsif type == Object
                    Empty.new
                elsif type.is_a? Negation
                    type.type
                else
                    super
                end
            end
        end

        def initialize(type)
            @type = type
        end

        def potential_modules
            Object
        end
    end

    class Aggregate < Base
        attr :types

        def initialize(types)
            @types = types.freeze
        end
    end

    class Intersection < Aggregate
        class << self
            def new(*args)
                types = Set[]
                args.each do |arg|
                    if arg.is_a? Intersection
                        types |= arg.types
                    elsif arg.is_a? Empty
                        return Empty.new
                    elsif types.none?{|t| t < arg }
                        types.delete_if{|t| arg < t }
                        types << arg
                    end
                end

                case types.size
                    when 0
                        Object
                    when 1
                        types.first
                    else
                        super(types)
                end
            end
        end

        def inspect
            @types.map(&:inspect).join(' & ')
        end

        def ===(x)
            @types.all? do |t|
                t === x
            end
        end

        def potential_modules
            @types
        end
    end

    class Union < Aggregate
        class << self
            def new(*args)
                types = Set[]
                args.each do |arg|
                    if arg.is_a? Intersection
                        types |= arg.types
                    elsif arg == Object
                        return Object
                    elsif !arg.is_a?(Empty) && types.none?{|t| arg < t }
                        types.delete_if{|t| t < arg }
                        types << arg
                    end
                end

                case types.size
                    when 0
                        Empty.new
                    when 1
                        types.first
                    else
                        super(types)
                end
            end
        end

        def inspect
            @types.map(&:inspect).join(' | ')
        end

        def ===(x)
            @types.any? do |t|
                t === x
            end
        end

        def potential_modules
            @types
        end
    end
end

class Module
    includ TypeExpression::Operations

    def potential_modules
        Set[self]
    end
end
