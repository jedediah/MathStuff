require 'active_support/core_ext/object/try'

require_relative 'math'
require_relative 'coercible'
require_relative 'set'

class Numeric
    def ordinal?
        false
    end

    def cardinal?
        false
    end
end

class Integer
    def ordinal?
        !negative?
    end

    def limit_ordinal?
        false
    end

    def successor_ordinal?
        self > 0
    end

    def cantor_normal_form
        ordinal? or raise TypeError, "#{inspect} is not an ordinal"
        NormalizedHash.new(0).merge!(0 => self)
    end

    def cardinal?
        !negative?
    end

    def countable?
        true
    end

    def andup
        if block_given?
            n = self
            loop do
                yield n
                n += 1
            end
        else
            self .. ALEPH0 # TODO should be ordinal
        end
    end
end

class Cardinal < Numeric
    include Coercible
    include Comparable
    include Latex::Inspectable

    attr :cardinal_index

    def initialize(index)
        index.ordinal? or raise TypeError, "#{index.inspect} is not an ordinal"
        @cardinal_index = index
    end

    class << self
        def new(index)
            if index.zero?
                @aleph_zero ||= super(0)
            elsif index.one?
                @aleph_one ||= super(1)
            else
                super(index)
            end
        end
        alias_method :[], :new

        def _verify(*s)
            s.each do |x|
                x.try(:cardinal?) or raise ArgumentError, "#{x} is not a cardinal number"
            end
        end

        def cmp(a, b)
            _verify(a, b)
            if a.finite?
                if b.finite?
                    a.to_i <=> b.to_i
                else
                    -1
                end
            else
                if b.finite?
                    1
                else
                    a.cardinal_index <=> b.cardinal_index
                end
            end
        end

        def add(a, b)
            _verify(a, b)
            a.max(b)
        end

        def sub(a, b)
            _verify(a, b)
            if a > b
                a
            else
                raise Math::DomainError
            end
        end

        def mul(a, b)
            _verify(a, b)
            if a.zero? || b.zero?
                0
            else
                a.max(b)
            end
        end

        def div(a, b)
            _verify(a, b)
            raise ZeroDivisionError if b.zero?
            if a > b
                a
            else
                raise Math::DomainError
            end
        end
    end

    forward :to_s, :inspect

    def inspect
        "ℵ#{cardinal_index.to_subscript}"
    end

    def inspect_latex
        "\\aleph_#{cardinal_index}"
    end

    def cardinal?
        true
    end

    def finite?
        false
    end

    def infinite?
        true
    end

    def countable?
        cardinal_index.zero?
    end

    def ==(x)
        x.is_a?(Cardinal) && cardinal_index == x.cardinal_index
    end

    def <=>(x)
        if x.is_a?(Numeric) && x.cardinal?
            if x.finite?
                1
            else
                cardinal_index <=> x.cardinal_index
            end
        end
    end

    def times
        countable? or raise "#{self} is not enumerable"

        if block_given?
            i = 0
            loop do
                yield i
                i += 1
            end
        else
            enum_for :times
        end
    end

    module RangePrepend
        def size
            if self.end.infinite?
                ALEPH0
            else
                super
            end
        end
    end
end

class Range
    prepend Cardinal::RangePrepend
end

ALEPH0 = Cardinal[0]
ALEPH1 = Cardinal[1]

