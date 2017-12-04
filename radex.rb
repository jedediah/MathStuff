load File.join(File.dirname(__FILE__), 'numex.rb')

class Integer
    def sqrt
        Radex[0, 1, self]
    end
end

class Rational
    def sqrt
        Radex[0, 1, self]
    end
end

# a + b * sqrt(c) where a, b, c = Rational
class Radex < Numeric
    include Numex

    attr :a, :b, :c

    def initialize(a, b, c)
        @a = a
        @b = b
        @c = c
    end

    class << self
        def [](a, b, c)
            if b == 0 || c == 0
                a
            else
                x, c = c.factor_out_powers_of(2)

                if c == 1
                    a + b*x
                else
                    new(a, b*x, c)
                end
            end
        end
    end

    def create(a, b)
        if b == 0
            a
        else
            self.class.new(a, b, c)
        end
    end

    def inspect
        babs = b.abs
        "#{a unless a == 0}#{b < 0 ? '-' : ('+' unless a == 0)}#{babs unless babs == 1}√#{c}"
    end

    def to_s
        inspect
    end

    def to_f
        sqrt(c.to_f) * b.to_f + a.to_f
    end

    def is_radex?(x)
        if x.is_a? Radex
            unless self.c == x.c
                raise "Cannot combine mismatched radicals #{self.c} and #{x.c}"
            end
            true
        end
    end

    def ==(x)
        x.is_a?(Radex) && a == x.a && b == x.b && c == x.c
    end

    def positive?
        if a == 0 || a*a < b*b*c
            b > 0
        else
            a > 0
        end
    end

    def <=>(x)
        if is_radex?(x)
            da = a - x.a
            db = b - x.b
        else
            da = a - x
            db = b
        end

        if da == 0 || da*da < db*db*c
            db <=> 0
        else
            da <=> 0
        end
    end

    def sum(x, d=1)
        if is_radex?(x)
            create(a + d*x.a, b + d*x.b)
        else
            create(a + d*x, b)
        end
    end

    def +(x)
        sum(x, 1)
    end

    def -(x)
        sum(x, -1)
    end

    def -@
        create(-a, -b)
    end

    def *(x)
        if is_radex?(x)
            create(a*x.a + b*x.b*c, a*x.b + b*x.a)
        else
            create(a*x, b*x)
        end
    end

    def reciprocal_denominator
        a*a - b*b*c
    end

    def reciprocal
        #    1       a - b_c
        # ------- = ----------
        # a + b_c   a^2 - cb^2
        d = reciprocal_denominator
        create(a/d, -b/d)
    end

    def /(x)
        if is_radex?(x)
            d = reciprocal_denominator
            create((a*x.a - b*x.b*c)/d, (b*x.a - a*x.b)/d)
        else
            create(a/x, b/x)
        end
    end

    def **(x)
        unless x.denominator == 1
            raise "Can't raise radical to fractional exponent"
        end

        if x < 0
            reciprocal**(-x)
        elsif x == 0
            1
        elsif x == 1
            self
        else
            self * self**(x-1)
        end
    end
end
