require_relative 'ext'
require_relative 'math'
require_relative 'coercible'

# Use binary algorithm to raise +x+ to the power of +n+.
#
# Any binary operation can be provided for +mul+, which defaults to the * method of +x+.
#
# If +n+ is zero, then +one+ is returned, defaulting to +x.class.one+. This is the only
# case in which one is required. Nothing is ever multiplied by one.
#
# Negative values of +n+ are supported if +x+ responds to :reciprocal:.
#
# Examples:
#
#   binary_pow(2, 8)
#     => 256
#   binary_pow(5, 11, &:+)
#     => 55
#   binary_pow('wtf',5) {|a, b| "#{a} #{b}" }
#     => "wtf wtf wtf wtf wtf"
#
def binary_pow(x, n, one=nil, &mul)
    mul ||= proc{|a, b| a * b }
    case n
        when 0
            one || x.class.one
        when 1
            x
        else
            if n.negative?
                # Should we reciprocate before or after??
                binary_pow(x.reciprocal, -n, one, &mul)
            else
                sq = x
                x = nil
                loop do
                    n, r = n.divmod(2)
                    if r.one?
                        if x.nil?
                            x = sq
                        else
                            x = mul[x, sq]
                        end
                        break x if n.zero?
                    end
                    sq = mul[sq, sq]
                end
            end
    end
end

module Multiplicable
    extend ActiveSupport::Concern
    include Coercible

    class_methods do
        abstract_method :mul_identity
        protected :mul_identity

        def one
            @mul_identity ||= mul_identity
        end
    end

    abstract_method :one?, :reciprocal, :mul, :can_mul?
    protected :reciprocal, :mul

    def validate_mul(x)
        can_mul?(x) or raise TypeError, "Cannot multiply #{self.class} with #{x.class}"
    end

    def *(x)
        if can_mul?(x)
            if one?
                x
            elsif x.one?
                self
            else
                mul(x)
            end
        elsif x.respond_to? :coerce
            a, b = x.coerce(self)
            a * b
        end
    end

    def pow(n)
        binary_pow(self, n)
    end

    def **(n)
        n.integer? or raise Math::DomainError, "#{self.class} raised to non-integer power is undefined"

        if one?
            self
        elsif n.zero?
            self.class.one
        elsif n.one?
            self
        elsif n.negative?
            reciprocal**(-n)
        else
            pow(n)
        end
    end

    # x * self * x**(-1)
    def conjugate(x)
        validate_mul(x)

        if one? || x.one?
            self
        else
            x.mul(mul(x.reciprocal))
        end
    end

    def commutator(x)
        validate_mul(x)

        if one? || x.one?
            self.class.one
        else
            mul(x).mul(reciprocal.mul(x.reciprocal))
        end
    end
end
