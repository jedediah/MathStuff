require 'active_support/concern'

require_relative 'ext'
require_relative 'enumerable'
require_relative 'math'

module Ring
    extend ActiveSupport::Concern

    module ClassMethods
        include Enumerable

        def units
            raise NotImplementedError
        end

        def naturals
            raise NotImplementedError
        end

        def primes
            raise NotImplementedError
        end

        def naturalize(x)
            raise NotImplementedError
        end

        def divides?(x, y)
            raise NotImplementedError
        end

        def mul(x, y)
            raise NotImplementedError
        end

        # Return the Euclidean remainder of x/y
        def mod(x, y)
            raise NotImplementedError
        end

        def divmod(x, y)
            raise NotImplementedError
        end

        def associates(x)
            x = naturalize(x)
            units.map{|u| mul(u, x) }
        end

        def associated?(x, y)
            divides?(x, y) && divides?(y, x)
        end

        def ideal(x)
            transform{|y| mul(x, y) }
        end

        def pow(x, y)
            if y.zero?
                1
            elsif y.one?
                x
            elsif y.integer? && !y.negative?
                binary_pow(x, y)
            else
                raise ArgumentError, "Eisenstein integer #{x} cannot be raised to exponent #{y}"
            end
        end

        # Return the common divisor of x and y with the largest norm
        def gcd(x, y)
            until y.zero?
                # puts "#{x} #{y}"
                x, y = y, mod(x, y)
            end
            x
        end

        def coprime?(x, y)
            gcd(x, y).unit?
        end

        # Return the common multiple of x and y with the smallest norm
        def lcm(x, y)
            mul(x, div(y, gcd(x, y)))
        end

        # Return [c, a, b, u, v] where
        #    c = gcd(x, y)
        #    ax + by = c
        #    |uc| = |x|
        #    |vc| = |y|
        def gcd_ex(x, y)
            s1 = t0 = 0
            s0 = t1 = 1
            until y.zero?
                x, (q, y) = y, divmod(x, y)
                s0, s1 = s1, s0 - q*s1
                t0, t1 = t1, t0 - q*t1
                # puts "x=#{x} y=#{y} s0=#{s0} s1=#{s1} t0=#{t0} t1=#{t1} q=#{q}"
            end
            return x, s0, t0, t1, s1
        end

        def prime_factors(x)
            if x.zero? || x.unit?
                {}
            else
                f = Hash.new(0)
                primes.each do |p|
                    loop do
                        q, r = divmod(x, p)
                        break unless r.zero?
                        f[p] += 1
                        return f.freeze if q.unit?
                        x = q
                    end
                end
            end
        end
    end
end

class Integer
    include Ring

    class << self
        def each
            yield 0
            1.andup do |i|
                yield i
                yield -i
            end
        end
        enum_method :each

        def units
            [1, -1].freeze
        end
        cache_method :units

        def naturals(&block)
            1.andup(&block)
        end

        def primes(&block)
            Prime.each(&block)
        end

        def naturalize(x)
            x.abs
        end

        def prime?(x)
            x.prime?
        end

        def associated?(x, y)
            x == y || x == -y
        end

        def divides?(x, y)
            y % x == 0
        end

        def mul(x, y)
            x * y
        end

        def mod(x, y)
            x % y
        end

        def divmod(x, y)
            x.divmod(y)
        end
    end
end

module GaussianInteger
    extend ActiveSupport::Concern

    include Ring

    module ClassMethods
        def each
            yield 0
            1.andup do |r|
                (-r...r).each do |k|
                    yield r  + k*I
                    yield -k + r*I
                    yield -r - k*I
                    yield k  - r*I
                end
            end
        end
        enum_method :each

        def units
            [1, Complex::I, -1, -Complex::I].freeze
        end
        cache_method :units

        def naturals
            1.andup do |a|
                (0..a).each do |b|
                    yield a-b + b*I
                end
            end
        end
        enum_method :naturals

        def seminaturals
            1.andup do |a|
                (0..a).each do |b|
                    yield a + b*I
                end
            end
        end
        enum_method :seminaturals

        def primes
            seminaturals.each do |p|
                if prime? p
                    yield p
                    yield p.imag + p.real*I unless p.imag.zero? || p.imag == p.real
                end
            end
        end
        enum_method :primes

        def pythagorean?(x)
            unless x.real.zero? || x.imag.zero?
                n = x.norm
                sqrt(n).floor**2 == n
            end
        end

        def pythagoreans
            1.andup do |i|
                (0...i).each do |j|
                    m = 2*(i-j)
                    n = 2*j+1
                    if Integer.coprime?(m, n)
                        b, a = [m**2 - n**2, 2*m*n].map(&:abs).sort
                        yield a + b*I
                    end
                end
            end
            # seminaturals.each do |p|
            #     if pythagorean? p
            #         yield p
            #         yield p.imag + p.real*I unless p.imag.zero? || p.imag == p.real
            #     end
            # end
        end
        enum_method :pythagoreans

        def naturalize(x)
            if x.real.negative?
                if x.imag.negative?
                    -x
                else
                    x.imag - x.real*I
                end
            else
                if x.imag.negative?
                    -x.imag + x.real*I
                else
                    x
                end
            end
        end

        def mul(x, y)
            x * y
        end

        def div(x, y)
            x / y
        end

        def mod(x, y)
            yc = y.conj
            u = mul(x, yc)
            v = y.norm
            (u.real % v + (u.imag % v)*I) / yc
        end

        def divmod(x, y)
            yc = y.conj
            u = mul(x, yc)
            v = y.norm
            q1,r1 = u.real.divmod(v)
            q2,r2 = u.imag.divmod(v)
            return q1 + q2*I, (r1 + r2*I) / yc
        end

        def divides?(y, x)
            yc = y.conj
            u = mul(x, yc)
            v = y.norm
            v.divides?(u.real) && v.divides?(u.imag)
        end

        def prime?(x)
            n = if x.real.zero?
                x.imag.abs
            elsif x.imag.zero?
                x.real.abs
            end
            if n
                n.integer? && n % 4 == 3 && Integer.prime?(n)
            else
                Integer.prime?(x.norm)
            end
        end

        def grid(gen=1)
            Plot.drawable do |ctx|
                ctx.grill 0, gen
                ctx.grill 0, gen*I
            end
        end
    end
end

class Complex
    include GaussianInteger

    def gaussian_integer?
        real.integer? && imag.integer?
    end
end
