require 'mathn'
require 'matrix'
require 'active_support'

require_relative 'ext'
require_relative 'latex'

module Math
    TAU = 2*PI

    EULER_MASCHERONI = 0.5772156649015329

    def cgamma(z, iters=100)
        u = 1
        v = z
        (1..iters).each do |n|
            n = n.to_f
            u *= n * (n + 1)**z
            v *= n**z * (n + z)
        end
        u / v
    end

    def cgamma2(z, iters=100)
        u = exp(-EULER_MASCHERONI*z)
        v = z
        (1..iters).each do |n|
            n = n.to_f
            zn = z/n
            u *= exp(zn)
            v *= 1 + zn
        end
        u / v
    end
end

include Math

PI = Math::PI
TAU = Math::TAU
I = Complex::I

class Numeric
    include Latex::Inspectable

    def precise?
        false
    end

    def natural?
        integer? && !negative?
    end

    def rational?
        false
    end

    def algebraic?
        false
    end

    def unit?
        abs.one?
    end

    def one?
        self == 1
    end

    def negative?
        false
    end

    def sign
        negative? ? -1 : 1
    end

    def reciprocal
        1 / self
    end

    def mixed_fraction
        divmod(1)
    end

    def norm
        real**2 + imag**2
    end

    def min(x)
        if (self <=> x).eql? 1
            x
        else
            self
        end
    end

    def max(x)
        if (self <=> x).eql? -1
            x
        else
            self
        end
    end

    def lerp(b, n)
        self*(1-n) + b*n
    end

    def factor_out_negative_one
        if self < 0
            [-1, -self]
        else
            [1, self]
        end
    end

    # Factor out powers of the given exponent from self.
    #
    # Returns [c, b] representing the original number as c**exponent * b
    def factor_out_powers_of(exponent)
        [1, self]
    end

    def positional_expansion(radix, e_min=0)
        radix > 1 or raise ArgumentError, "Invalid radix #{radix}"

        x = abs
        places = []
        place = 1
        while place <= x
            places << place
            place *= radix
        end

        digits = NormalizedHash.new(0)
        (places.size-1).downto(0) do |e|
            digits[e], x = x.divmod(places[e])
        end
        place = 1
        -1.downto(e_min) do |e|
            place /= radix
            digits[e], x = x.divmod(place)
        end
        digits
    end

    def to_vector
        Vector[real, imag]
    end

    def to_fvector
        Vector[real.to_f, imag.to_f]
    end

    def to_matrix
        Matrix[[real, -imag], [imag, real]]
    end

    def to_fmatrix
        a = real.to_f
        b = imag.to_f
        Matrix[[a, -b], [b, a]]
    end

    def to_subscript
        to_s.to_subscript
    end

    def to_superscript
        to_s.to_superscript
    end
end

module RationalMixin
    extend ActiveSupport::Concern

    class_methods do
        attr_const zero: 0, one: 1
    end

    def precise?
        true
    end

    def rational?
        true
    end

    def algebraic?
        true
    end

    def norm
        self*self
    end

    def divides?(b)
        if b.is_a? RationalMixin
            !zero? && b % self == 0
        else
            a, b = b.coerce(self)
            if a.respond_to? :divides?
                a.divides? b
            else
                raise "#{b.class} can't be coerced into #{self.class}"
            end
        end
    end
end

class Integer
    include RationalMixin

    def negative?
        self < 0
    end

    def natural?
        !negative?
    end

    def quotient_remainder
        [self, 0]
    end

    def mixed_fraction
        [self, 0]
    end

    def reciprocal
        Rational(1, self)
    end

    def factorial
        if self < 0
            raise Math::DomainError
        else
            (1..self).reduce(1, &:*)
        end
    end

    def root_floor(e)
        if self < 0 || e < 1
            raise Math::DomainError
        elsif self < 2 || e == 1
            [self, 0]
        elsif e == 2
            sqrt_floor
        else
            guess = self
            em1 = e-1
            loop do
                guess_em1 = guess**em1
                guess_e = guess_em1*guess
                r = self - guess_e
                return [guess, r] if r >= 0

                guess = (em1*guess_e + self).div(e*guess_em1)
            end
        end
    end

    def sqrt_floor
        guess = self
        loop do
            guess_2 = guess*guess
            r = self - guess_2
            return [guess, r] if r >= 0

            guess = (guess_2 + self).div(2*guess)
        end
    end

    def square?
        b, r = sqrt_floor
        b if r.zero?
    end

    def partitions(buckets=nil, min_size: 1)
        if buckets
            if buckets < 1
                raise Math::DomainError
            elsif buckets == 1
                [self]
            else

            end
        else
            [*(min_size..(self/2)).flat_map do |k|
                (self-k).partitions(min_size: k).map do |a|
                    [k, *a]
                end
            end, [self]]
        end
    end

    def distributions_over(k)
        if k < 1
            raise Math::DomainError
        elsif k == 1
            [self]
        else
            (0..self).flat_map do |n|
                (self - n).distributions_over(k - 1).map do |t|
                    [n, *t]
                end
            end
        end
    end

    # Builds a radical expression equal to self**(1/exponent), in a canonical form.
    #
    # Returns [c, b, r] which form the result: c * b**(1/r)
    #
    # This is (hopefully?) unique for any given number.
    def factors_of_degree(radical)
        base = self # Number currently inside the radical
        whole = 1 # Number currently outside the radical
        radical_factor = 2 # Prime factor of the exponent currently being checked

        while radical_factor <= radical
            # Check the exponent for the next factor
            radical_residue, r = radical.divmod(radical_factor)
            if r == 0
                # We found a factor in the exponent, check if the base is a power of it.
                factor, residue = base.factor_out_powers_of(radical_factor)
                if factor != 1
                    if radical_residue == 1
                        # Found a factor inside the radical that is a power of the whole exponent,
                        # which means we can move it out of the radical and leave a quotient behind.
                        # Example: 8**(1/2) -> 2*2**(1/2)
                        whole *= factor
                        base = residue
                    elsif residue == 1
                        # The number inside the radical is a power of a factor of the exponent.
                        # This allows us to reduce the exponent. This only works when the base
                        # is a pure power, because otherwise there would be a remaining factor that
                        # needs to be under the old exponent.
                        # Example: 9**(1/6) -> 3**(1/3)
                        base = factor
                        radical = radical_residue
                    end
                end
            end
            radical_factor += 1
        end

        [whole, base, radical]
    end

    def factor_out_powers_of(exponent)
        return factor_out_squares if exponent == 2

        base = self # Number being factored
        factor = 2 # Base of the current factor being checked
        out = 1 # Product of (base) factors already extracted

        # This just searches all the powers of N until it gets too big.
        loop do
            factor_raised = factor**exponent
            break if factor_raised > base

            residue, r = base.divmod(factor_raised)
            if r == 0
                out *= factor
                base = residue
            else
                factor += 1
            end
        end

        [out, base]
    end

    def factor_out_squares
        base = self
        factor = 2
        factor_raised = 4
        delta = 3
        out = 1

        loop do
            break if factor_raised > base
            q, r = base.divmod(factor_raised)
            if r == 0
                out *= factor
                base = q
            else
                delta += 2
                factor_raised += delta
            end
        end

        [out, base]
    end

    def prime_factors
        return if zero?

        f = Hash.new(0)
        x = self.abs

        while x.even?
            x /= 2
            f[2] += 1
        end

        p = 3
        loop do
            q, r = x.divmod(p)
            if r == 0
                x = q
                f[p] += 1
            elsif q < p
                f[x] += 1 unless x == 1
                return f
            else
                p += 2
            end
        end
    end

    def minimal_addition_chains(seq=[1], limit=nil)
        # puts "#{limit} #{seq.inspect}"
        if self == seq[-1]
            [seq]
        elsif limit.nil? || seq.size < limit
            nexts = seq.multisets(2).map{|(a, b)| a + b }.uniq.sort.reverse
            if nexts.any?{|c| self == c}
                [[*seq, self]]
            else
                shortest = nil
                nexts.each do |c|
                    if c < self && !seq.include?(c) && (r = minimal_addition_chains([*seq, c], limit))
                        if limit.nil? || r[0].size < limit
                            shortest = r
                            limit = r[0].size
                        elsif r[0].size == limit
                            shortest = [*shortest, *r]
                        end
                    end
                end
                shortest
            end
        end
    end

    def minimal_addition_chain_length(seq=[1], limit=nil)
        # puts "#{limit} #{seq.inspect}"
        if self == seq[-1]
            limit = seq.size
        elsif limit.nil? || seq.size < limit
            seq.multisets(2).map{|(a, b)| a + b }.uniq.sort.reverse.reject{|c| self < c || seq.include?(c) }.each do |c|
                limit = minimal_addition_chain_length([*seq, c], limit)
            end
        end
        limit
    end
end

class Rational
    include RationalMixin

    def inspect_latex
        "#{'-' if negative?}\\frac{#{numerator.abs.inspect_latex}}{#{denominator.inspect_latex}}"
    end

    def negative?
        numerator.negative?
    end

    def quotient_remainder
        numerator.divmod(denominator)
    end

    def mixed_fraction(allow_negative=false)
        if allow_negative
            q, r = numerator.abs.divmod(denominator)
            f = Rational(r, denominator)
            if negative?
                [-q, -f]
            else
                [q, f]
            end
        else
            q, r = numerator.divmod(denominator)
            [q, Rational(r, denominator)]
        end
    end

    def reciprocal
        Rational(denominator, numerator)
    end

    def factor_out_powers_of(exponent)
        # puts "#{self}.factor_out_powers_of(#{exponent}) n=#{numerator} d=#{denominator}"
        cu, bu = numerator.factor_out_powers_of(exponent)
        cd, bd = denominator.factor_out_powers_of(exponent)
        [cu/cd, bu/bd]
    end

    def prime_factors
        h = numerator.prime_factors
        denominator.prime_factors.each do |b, e|
            h[b] = -e
        end
        h
    end
end

class Float
    class << self
        attr_const zero: 0.0, one: 1.0
    end

    def negative?
        self < 0
    end
end

class Complex
    def inspect_latex
        if imag.zero?
            real.inspect_latex
        else
            imag_abs = imag.abs
            b = "#{imag_abs.inspect_latex unless imag_abs.one?}i"
            if real.zero?
                if imag.negative?
                    "-#{b}"
                else
                    b
                end
            else
                "#{real.inspect_latex} #{imag.negative? ? '-' : '+'} #{b}"
            end
        end
    end
end

class Vector
    include Latex::Inspectable

    class << self
        def polar(angle, length)
            self[length * sin(angle), length * cos(angle)]
        end

        def delta(n, i)
            a = [0] * n
            a[i] = 1
            self[*a]
        end

        def lorentz_event(time:, position:)
            self[time, *position]
        end

        def lorentz_velocity(v)
            g = v.gamma
            self[g, *(g*v)]
        end

        def lorentz_momentum(mass:, velocity:)
            e = mass/velocity.alpha
            self[e, *(e*velocity)]
        end
    end

    alias_method :dot, :inner_product

    def -@
        self * -1
    end

    def inspect
        "#{self.class.name}[#{to_a.map(&:inspect).join(', ')}]"
    end

    def inspect_latex
        Latex.vector(map(&:inspect_latex))
    end

    def to_s
        "(#{to_a.join(',')})"
    end

    def to_c
        size == 2 or raise TypeError, "Cannot convert #{size}-vector to Complex"
        self[0] + self[1]*Complex::I
    end

    def to_vector
        self
    end

    def zero?
        all?(&:zero?)
    end

    def norm2
        @norm2 ||= dot(self)
    end

    def outer_product
        Matrix.build(size) do |i, j|
            self[i] * self[j]
        end
    end

    def alpha
        # @alpha ||= sqrt(1.0 - norm2)
        @alpha ||= (1 - norm2).sqrt
    end

    def gamma
        # @gamma ||= 1.0 / alpha
        @gamma ||= 1 / alpha
    end

    def reflect(n)
        self - (2 * dot(n)) * n
    end

    def add_velocity(u)
        if norm2 == 0
            u
        else
            uv = dot(u)
            (alpha*u + ((1.0 - alpha)*uv/norm2 + 1.0)*self) / (1 + uv)
        end
    end

    def local_velocity(u)
        if norm2 == 0
            u
        else
            uv = dot(u)
            (alpha*u + ((1.0 - alpha)*uv/norm2 - 1.0)*self) / (1 - uv)
        end
    end

    def lorentz_inner_product(v)
        self.timelike * v.timelike - self.spacelike.inner_product(v.spacelike)
    end

    def lorentz_magnitude2
        @lorentz_magnitude2 ||= lorentz_inner_product(self)
    end

    def lorentz_magnitude
        @lorentz_magnitude ||= Math.sqrt(lorentz_magnitude2.to_f)
    end

    def timelike
        self[0]
    end

    def spacelike
        @spacelike ||= Vector[*self[1..-1]]
    end

    def x
        self[0]
    end

    def y
        self[1]
    end

    def z
        self[2]
    end

    def component(axis)
        map_with_index do |x, i|
            axis == i ? x : 0
        end
    end

    def vx
        component(0)
    end

    def vy
        component(1)
    end

    def vz
        component(2)
    end

    [2,3].each do |n|
        [:x,:y,:z].permutation(n) do |(*p)|
            define_method p.join do
                Vector[*p.map{|m| __send__(m) }]
            end
        end
    end

    def clamp(lower=nil, upper=nil)
        lower ||= self
        upper ||= self
        map_with_index do |c, i|
            c.clamp(lower[i], upper[i])
        end
    end

    def lower(v)
        map_with_index do |c, i|
            c.min(v[i])
        end
    end

    def upper(v)
        map_with_index do |c, i|
            c.max(v[i])
        end
    end

    def piecewise(v, &op)
        if v.is_a? Vector
            size == v.size or raise ErrDimensionMismatch, "Vector dimension mismatch"
            map_with_index do |x, i|
                op[x, v[i]]
            end
        else
            a, v = v.coerce(self)
            a.piecewise(v, &op)
        end
    end

    def turn(axis, n=1)
        case n % 4
            when 0
                self
            when 1
                Vector[*self[0...axis], -self[axis+1], self[axis], *self[axis+2...size]]
            when 2
                Vector[*self[0...axis], -self[axis], -self[axis+1], *self[axis+2...size]]
            when 3
                Vector[*self[0...axis], self[axis+1], -self[axis], *self[axis+2...size]]
        end
    end
end

class Matrix
    include Latex::Inspectable

    class << self
        def build_symmetric(n, &block)
            a = []
            build(n) do |i, j|
                if i <= j
                    a[i*n+j] = block.call(i, j)
                else
                    a[j*n+i]
                end
            end
        end

        def lorentz_boost(v, g=nil)
            return Matrix.I(v.size+1) if v.zero?

            g ||= v.gamma
            g1 = g-1
            v2 = v.norm2

            build_symmetric(v.size+1) do |i, j|
                if i == 0
                    if j == 0
                        g
                    else
                        -g*v[j-1]
                    end
                else
                    g1*v[i-1]*v[j-1]/v2 + (i==j ? 1 : 0)
                end
            end
        end

        alias_method :lorentz_transform_in, :lorentz_boost

        def lorentz_transform_out(v, g=nil)
            lorentz_boost(-v, g)
        end
    end

    def to_matrix
        self
    end

    def to_c
        row_count == 2 && column_count == 2 or raise TypeError, "Cannot convert #{row_count}x#{column_count} matrix to complex"
        self[0, 0] == self[1, 1] && self[0, 1] == -self[1, 0] or raise TypeError, "Matrix #{self} does not represent a complex number"
        self[0, 0] + self[1, 0]*Complex::I
    end

    def inspect_latex
        Latex.matrix(row_count, column_count) do |i, j|
            Latex.render(self[i, j])
        end
    end

    def to_multiline
        s = map(&:inspect)
        widths = column_count.times.map do |col|
            s.column(col).map(&:size).max
        end
        row_count.times.map do |row|
            "[#{column_count.times.map do |col|
                s[row, col].ljust(widths[col])
            end.join(' ')}]\n"
        end.join
    end

    def size?(rows, cols=rows)
        row_count == rows || column_count == cols
    end
end

if defined? IRuby::Display
    IRuby::Display::Registry.class_eval do
        type { Complex }
        priority 1
        format('text/latex') {|c| c.to_latex }

        type { Matrix }
        priority 1
        format('text/latex') {|m| m.to_latex }
    end
end

def CV(*a)
    Matrix.column_vector(a)
end

def RV(*a)
    Matrix.row_vector(a)
end

def _goodstein(x, base)
    if x < base
        x
    else
        x.positional_expansion(base).reduce(0) do |total, (exp, digit)|
            total + digit * (base+1)**_goodstein(exp, base)
        end
    end
end

def goodstein_sequence(x, n=ALEPH0)
    (2..n).each do |base|
        yield x
        break if x.zero?
        x = _goodstein(x, base) - 1
    end
end
Object.enum_method :goodstein_sequence
