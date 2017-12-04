require 'set'
require_relative 'ext'

class TypeSet
    include Enumerable

    attr :types

    class << self
        def new(*args)
            types = Set[]
            args.each do |arg|
                arg.types.each do |x|
                    if Object <= x
                        return Object
                    elsif types.none?{|t| x < t }
                        types.delete_if{|t| t < x }
                        types << x
                    end
                end
            end

            case types.size
                when 0
                    @empty ||= super(types)
                when 1
                    types.first
                else
                    super(types)
            end
        end

        forward :[], :new
    end

    def initialize(types)
        @types = types.freeze
    end

    def each(&block)
        types.each(&block)
    end
    enum_method :each

    def inspect
        if types.empty?
            '{}'
        else
            types.map(&:inspect).join(' | ')
        end
    end
    forward :to_s, :inspect

    def ==(m)
        (m.is_a?(Module) || m.is_a?(TypeSet)) && types == m.types
    end
    forward :eql?, :==

    def ===(x)
        types.any?{|t| t === x }
    end

    def <(m)
        types.any?{|t| m.types.any?{|u| t < u }}
    end

    def <=(m)
        types.any?{|t| m.types.any?{|u| t <= u }}
    end

    def >(m)
        types.any?{|t| m.types.any?{|u| t > u }}
    end

    def >=(m)
        types.any?{|t| m.types.any?{|u| t >= u }}
    end

    def |(s)
        self.class.new(self, s)
    end

    module ModuleExt
        def types
            Set[self].freeze
        end

        def |(m)
            TypeSet[self, m]
        end

        def <(m)
            if m.is_a? TypeSet
                m > self
            else
                super
            end
        end

        def <=(m)
            if m.is_a? TypeSet
                m >= self
            else
                super
            end
        end

        def >(m)
            if m.is_a? TypeSet
                m < self
            else
                super
            end
        end

        def >=(m)
            if m.is_a? TypeSet
                m <= self
            else
                super
            end
        end
    end

    Module.prepend(ModuleExt)
end
