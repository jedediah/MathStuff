require_relative 'arithmetic'
require_relative 'primal'

module Math
    R2 = sqrt(2)
    R3 = sqrt(3)

    ROOTS_OF_UNITY = Hash.new do |h, r|
        r0 = Rational(r)%1
        if r0 == r
            h[r] = Math.exp(I*TAU*r)
        else
            h[r0]
        end
    end.merge(
         0/4  => 1,
         1/4  => I,
         2/4  => -1,
         3/4  => -I,

         1/8  => ( R2 + I*R2)/2,
         3/8  => (-R2 + I*R2)/2,
         5/8  => (-R2 - I*R2)/2,
         7/8  => ( R2 - I*R2)/2,

         1/12 => ( R3 + I   )/2,
         2/12 => ( 1  + I*R3)/2,
         4/12 => (-1  + I*R3)/2,
         5/12 => (-R3 + I   )/2,
         7/12 => (-R3 - I   )/2,
         8/12 => (-1  - I*R3)/2,
        10/12 => ( 1  - I*R3)/2,
        11/12 => (R3  - I   )/2,
    )

    class << self
        def root_of_unity(r, index=nil)
            if index
                raise ArgumentError if r < 1
                ROOTS_OF_UNITY(index/r)
            else
                ROOTS_OF_UNITY[r]
            end
        end

        def polynomial_roots(*poly)
            case poly.size
                when 0, 1
                    0
                when 2
                    # ax + b = 0
                    a, b = poly
                    [-b/a]
                when 3
                    a, b, c = poly
                    d = sqrt(b**2 - 4*a*c)
                    [(-b-d)/2, (-b+d)/2]
                when 4
                    a, b, c, d = poly

                    # dd = 18*a*b*c*d - 4*b**3*d + b**2*c**2 - 4*a*c**2 - 27*a**2*d**2

                    d0 = b**2 - 3*a*c
                    d1 = 2*b**3 - 9*a*b*c + 27*a**2*d
                    d2 = d1**2 - 4*d0**3

                    if d2 == 0
                        if d0 == 0
                            # 1 real root
                            r = -b/(3*a)
                            [r, r, r]
                        else
                            # 2 real roots
                            r0 = (4*a*b*c - 9*a**2*d - b**3)/(a*d0)
                            r1 = (9*a*d - b*c)/(2*d0)
                            [r0, r1, r1]
                        end
                    else
                        cc = if d0 == 0
                            d1
                        else
                            (d1 + sqrt(d2))/2
                        end**(1/3)

                        (0..2).map do |n|
                            u = ROOTS_OF_UNITY[n/3] * cc
                            (-b - u - d0/u)/(3*a)
                        end
                    end
                else
                    raise "math too hard"
            end
        end
    end
end

class Polynomial < NumericExpr

    attr :polynomial

    def initialize(polynomial, generators: nil)
        super()
        @polynomial = polynomial.freeze
        generators__set(generators) if generators
    end

    class << self
        def [](expr)
            _create(expr.polynomial)
        end

        def _create(p)
            if p.empty?
                0
            elsif p.keys == [{}]
                p[{}]
            else
                new(p)
            end
        end
    end

    def terms
        polynomial.map do |gs, co|
            Mul[co, *gs.map{|g, e| Pow[g, e]}]
        end
    end

    def generators
        polynomial.keys.flat_map(&:keys).uniq.sort_by do |gs|
            [gs.rational_degree, gs.hash]
        end
    end
    cache_method :generators

    def rational_degree
        generators.pro(&:rational_degree)
    end
    cache_method :rational_degree

    def basis
        m = generators.reverse.map do |g|
            g.rational_degree.times.map do |e|
                _HZ(g => e)
            end
        end
        Enumerable.product(*m) do |*f|
            f.reverse.reduce(_HZ, &:merge!)
        end
    end
    cache_method :basis

    def ordered_terms
        h = _HZ
        basis.map do |b|
            h[b] = polynomial[b]
        end
        h
    end
    cache_method :ordered_terms

    def inspect
        ordered_terms.map do |gs, co|
            factors = gs.map do |g, e|
                Pow[g, e, simplify: true].inspect
            end
            factors.unshift(co) unless co.one? && !gs.empty?
            factors.join('×')
        end.join(' + ')
    end

    def inspect_latex
        ts = ordered_terms.map do |gens, co|
            factors = gens.map do |gen, ex|
                gen.pow(ex).inspect_latex
            end
            factors.unshift(co) unless co.one? && !gens.empty?
            factors.join
        end
        gs = generators.map(&:inspect_latex)
        "\\left\\{#{ts.join(' + ')} \\in \\mathbb{Q}\\left( #{gs.join(', ')} \\right) \\right\\}"
    end

    def to_f
        polynomial.reduce(0.0) do |f, (gs, co)|
            f + co * gs.reduce(1.0) {|t, (g, e)| t * g.to_f**e }
        end
    end

    def to_matrix
        Matrix.build(basis.size) do |i, j|
            co = 1
            factors = []
            (basis[j] / basis[i]).simplify.factors.each do |f|
                # puts "M[#{i}, #{j}] = #{f.inspect}"
                if f.rational?
                    co *= f
                else
                    p,r = f.exponent.quotient_remainder
                    co *= f.base**(-p)
                    factors << Pow[f.base, r/f.exponent.denominator]
                end
            end
            coeffs[Mul[*factors]] * co
        end
    end

    def -@
        self.class.new(polynomial.mash{|g, c| [g, -c] }, generators: generators)
    end

    def pow(n)
        if n.integer?
            gens_orig = polynomial.keys
            cos_orig = polynomial.values
            poly = _HZ
            multinomial_coefficients(polynomial.size, n) do |co, exs|
                gens = _HZ
                exs.each_with_index do |ex, i|
                    gens_orig[i].each do |gen, ex_orig|
                        degree = gen.rational_degree
                        q, ex = (ex * ex_orig).divmod(degree)
                        co *= q * gen.pow(degree) unless q.zero?
                        gens[gen] += ex
                    end
                    co *= cos_orig[i]**ex
                end
                poly[gens] += co
            end
            self.class._create(poly)
        else
            raise Math::DomainError
        end
    end

    def mul(x)
        if x.rational?
            self.class.new(polynomial.mash do |gens, co|
                [gens, co*x]
            end, generators: generators)
        else
            poly = _HZ
            polynomial.each do |gens1, co1|
                x.polynomial.each do |gens2, co2|
                    co = 1
                    gens = gens1.merge(gens2) do |gen, ex1, ex2|
                        degree = gen.rational_degree
                        q, ex = (ex1 + ex2).divmod(degree)
                        co *= q * gen.pow(degree) unless q.zero?
                        ex
                    end
                    # puts "p[#{gs.inspect}] += #{c1.inspect} * #{c2.inspect} * #{c.inspect}"
                    poly[gens] += co1 * co2 * co
                end
            end
            self.class._create(poly)
        end
    end

    def add(x)
        self.class._create(polynomial.merge(x.polynomial) {|_, co1, co2| co1 + co2 })
    end
end
