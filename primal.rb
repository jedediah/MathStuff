require_relative 'arithmetic'

class Primal < NumericExpr

    ROOT_SYMBOLS = ['', '√', '∛', '∜']

    attr :prime_factors

    def initialize(negative, prime_factors)
        super()
        @negative = negative
        @prime_factors = prime_factors
    end

    class << self
        def [](factors = {})
            if factors.keys.any?(&:negative?)
                raise Math::DomainError
            elsif factors.values.all?(&:integer?)
                factors.reduce(1) do |r, (b, e)|
                    r * b**e
                end
            else
                h = _HZ
                factors.each do |b, e1|
                    b.prime_factors.each do |p, e2|
                        h[p] += e2*e1
                    end
                end
                h.freeze
                new(false, h)
            end
        end

        def from_root_map(roots)
            h = _HZ
            roots.each do |r, b|
                b.prime_factors.each do |p, e|
                    h[p] += Rational(e, r)
                end
            end
            h.freeze
            new(roots[1] && roots[1].negative?, h)
        end
    end

    def root_map
        h = NormalizedHash.new(1)
        h[1] = -1 if negative?
        prime_factors.each do |p, e|
            q, r = e.mixed_fraction
            h[1] *= p**q
            h[r.denominator] *= p**r unless r.zero?
        end
        h.sort.to_h
    end
    cache_method :root_map

    def rational_degree
        prime_factors.values.map(&:denominator).reduce(&:lcm)
    end
    cache_method :rational_degree

    # Returns [c, b, r] where self = c * b**(1/r)
    def single_radical
        c = b = 1
        prime_factors.each do |p, e|
            q, r = e.mixed_fraction
            c *= p**q
            b *= p**(r*rational_degree)
        end
        [c, b, rational_degree]
    end
    cache_method :single_radical

    def inspect
        upstairs = Hash.new(1)
        downstairs = Hash.new(1)
        prime_factors.each do |p, e|
            q, r = e.mixed_fraction
            h = e.negative? ? downstairs : upstairs
            h[1] *= p**q
            h[r.denominator] *= p**r.numerator
        end

        upstairs = ''
        downstairs = ''
        root_map.each do |e, b|
            s = e.negative? ? downstairs : upstairs
            e = e.abs
            s << if e <= 4
                "#{ROOT_SYMBOLS[e-1]}#{b}"
            else
                "#{b}^(#{e})"
            end
        end
        upstairs = '1' if upstairs.empty?
        if downstairs.empty?
            upstairs
        else
            "#{upstairs}/#{downstairs}"
        end
    end

    def inspect_latex(long: false)
        f = prime_factors.map{|p, e| "#{p.inspect_latex}^{#{e.inspect_latex}}"}
        f.unshift((-1).inspect_latex) if negative?
        c, b, r = single_radical

        s = ''
        s << '-' if negative?
        s << c.inspect_latex unless c.one?
        s << '\\sqrt'
        s << "[#{r.inspect_latex}]" unless r == 2
        s << "{#{b.inspect_latex}}"
        s << " = #{f.join('\\times')}" if long
        s
    end

    def precise?
        true
    end

    def real?
        true
    end

    def algebraic?
        true
    end

    def rational?
        false
    end

    def integer?
        false
    end

    def zero?
        false
    end

    def one?
        false
    end

    def negative?
        @negative
    end

    def to_f
        c = negative? ? -1.0 : 1.0
        b = 1.0
        prime_factors.each do |p, e|
            q, r = e.mixed_fraction
            c *= p**q
            b *= p**(r*rational_degree)
        end
        c * b**rational_degree
    end

    def terms
        [self]
    end

    def ==(x)
        if x.is_a? Primal
            negative? == x.negative? && prime_factors == x.prime_factors
        elsif x.rational?
            return false unless negative? == x.negative?

            n = d = 1
            prime_factors.each do |p, e|
                if e.integer?
                    if e.negative?
                        d *= p**e
                    else
                        n *= p**e
                    end
                else
                    return false
                end
            end
            n == x.numerator.abs && d == x.denominator
        else
            false
        end
    end

    def _create(n, h)
        if h.values.all?(&:integer?)
            h.reduce(n ? -1 : 1) do |r, (p, e)|
                r * p**e
            end
        else
            unless h.frozen?
                h.default = 0
                h.freeze
            end
            self.class.new(n, h)
        end
    end

    def pow(x)
        if negative? && x.denominator.even?
            raise Math::DomainError
        else
            h = _HZ
            prime_factors.each do |p, e|
                h[p] = e * x
            end
            _create(negative? && x.numerator.odd?, h)
        end
    end

    def -@
        self.class.new(!negative?, prime_factors)
    end

    def muldiv(x, c)
        if x.algebraic?
            if x.zero?
                0
            elsif x.one?
                self
            elsif x.respond_to? :prime_factors
                h = prime_factors.dup
                x.prime_factors.each do |p, e|
                    h[p] += c*e
                end
                h.delete_if{|_, e| e.zero? }
                _create(negative? ^ x.negative?, h)
            else
                Algebraic.product(self, x**c)
            end
        else
            to_f * x.to_f**c
        end
    end

    def mul(x)
        if x.respond_to? :prime_factors
            _create(negative? ^ x.negative?, prime_factors.merge(x.prime_factors) do |_, e1, e2|
                e1 + e2
            end)
        else
            x.polynomial.each do |gs, co|

                gs.each do |g, e|

                end
            end
        end
        muldiv(x, 1)
    end

    def div(x)
        muldiv(x, -1)
    end

    def add(x)
        Polynomial[self].add(x)
    end
end
