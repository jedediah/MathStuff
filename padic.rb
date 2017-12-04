require_relative 'expr'


class Padic
    include Expr

    attr :radix, :digits, :period

    def initialize(radix, digits, period)
        radix.integer? or raise ArgumentError, "radix must be an integer"
        radix >= 2 or raise ArgumentError, "radix must be >= 2"
        period <= digits.size or raise ArgumentError, "period #{period} cannot exceed number of digits #{digits.size}"

        @radix = radix
        @digits = digits
        @period = period
    end

    def inspect
        if radix <= 36
            digits.zip_index.reverse.map do |d, e|
                d.to_s(radix).send_if(e + period >= digits.size, :overline)
            end.join + radix.to_subscript
        else
            "P[#{radix}]{" +
            digits.zip_index.reject{|(d, _)| d.zero? }.reverse.map do |(d, e)|
                exp = if e + period >= digits.size
                    "#{e}+#{period}n"
                elsif e > 1
                    e.to_s
                else
                    ''
                end.to_superscript
                if e > 0
                    "#{d}×#{radix}#{exp}"
                else
                    d.to_s
                end
            end.join(' + ') + "}"
        end
    end
end

class Integer
    def to_padic(radix)
        p = positional_expansion(radix)
        Padic.new(radix, (0..p.keys.max).map{|e| p[e] }, 0)
    end
end

class Rational
    def to_padic(radix)

    end
end
