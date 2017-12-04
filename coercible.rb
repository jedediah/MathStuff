require 'active_support/concern'

module Coercible
    extend ActiveSupport::Concern

    def coerce(a)
        return Wrapper.new(a), self
    end

    PREDICATES = {
        :divides? => :divides?,
        :associated? => :associated?,
    }

    ARITHMETIC = {
        :** => :pow,
        :* => :mul,
        :/ => :div,
        :divmod => :divmod,
        :gcd => :gcd,
        :lcm => :lcm,
        :% => :mod,
        :+ => :add,
        :- => :sub,
        :>> => :shr,
        :<< => :shl,
    }

    LOGIC = {
        :& => :and,
        :| => :or,
        :^ => :xor,
    }

    OPS = {**PREDICATES, **ARITHMETIC, **LOGIC}

    OPS.each do |op, meth|
        define_method op do |b|
            self.class.__send__(meth, self, b)
        end
        define_method :"__r#{meth}" do |a|
            self.class.__send__(meth, a, self)
        end
    end

    class Wrapper
        include Comparable

        def initialize(value)
            @value = value
        end

        def ==(b)
            b == @value
        end

        def eql?(b)
            b.eql?(@value)
        end

        def <=>(b)
            -(b <=> @value)
        end

        OPS.each do |op, meth|
            define_method op do |b|
                b.__send__(:"__r#{meth}", @value)
            end
        end
    end

    module Macros
        def right(op, &block)
            op = op.to_sym
            meth = OPS[op] or raise ArgumentError, "Unknown binary operator '#{op}'"
            define_method(:"__r#{meth}", &block)
        end

        def commutative(*ops)
            ops.each do |op|
                right op do |a|
                    __send__(op, a)
                end
            end
        end
    end
    ClassMethods = Macros
end
