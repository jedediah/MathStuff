require_relative 'expr'
# require_relative 'numex'

def _HZ(h=nil)
    x = NormalizedHash.new(0)
    x.merge!(h) if h
    x
end

def _bc0(e, k1, a, &block)
    k2 = e-k1
    block[a, [k1, k2]]
    k3 = k1+1
    _bc0(e, k3, (a * (e - k3 + 1)) / k3, &block) if k3 < k2
    block[a, [k2, k1]] if k1 < k2
end

def binomial_coefficients(e, &block)
    if e.negative?
        raise Math::DomainError
    elsif block
        _bc0(e, 0, 1, &block)
    elsif e.zero?
        _HZ
    else
        h = _HZ([e,0] => 1, [0,e] => 1)
        a = 1
        (1..(e/2+1)).each do |k|
            a = (a * (e - k + 1)) / k
            h[[k, e-k]] = h[[e-k, k]] = a
        end
        h
    end
end

def _mc0(m, e, &block)
    if m == 1
        block[1, [e]]
    else
        _bc0(e, 0, 1) do |c1, (k, _)|
            _mc0(m-1, e-k) do |c2, es|
                block[c1*c2, [*es, k]]
            end
        end
    end
end

def multinomial_coefficients(m, e, &block)
    if e.negative?
        raise Math::DomainError
    elsif block
        _mc0(m, e, &block)
    else
        h = _HZ
        _mc0(m, e) do |c, es|
            h[es] = c
        end
        h
    end
end

class Numeric
    def simplify
        self
    end

    def expand
        self
    end

    def base
        self
    end

    def exponent
        1
    end

    def fraction
        [numerator, denominator]
    end

    def factors
        if one?
            []
        else
            [self]
        end
    end

    def terms
        if zero?
            []
        else
            [self]
        end
    end

    def precedence
        0
    end

    def as_power(e)
        self
    end

    def highest_power
        1
    end

    def rational_degree
        nil
    end

    # {{gen => power, ...} => coeff, ...}
    #
    # where
    #   coeff is rational
    #   gen is irrational
    #   power is integer >= 1
    #
    # e.g
    #   ax^3 + bx^2y + cxy^2 + dy^3 + e
    # returns
    #   {{x => 3} => a, {x => 2, y => 1} => b, {x => 1, y => 2} => c, {y => 3} => d, {} => e}
    def polynomial
        if zero?
            {}
        else
            _HZ(_HZ(self => 1) => 1)
        end
    end
end

module RationalMixin
    def rational_degree
        1
    end

    def polynomial
        _HZ(_HZ => self)
    end
end

class Integer
    def as_power(e)
        return self if e.one?
        x = self
        u = e.numerator
        v = e.denominator
        if u.negative?
            x = x.reciprocal
            u = -u
        end
        if u > 1
            x,r = root_floor(u)
            return self unless r.zero?
        end
        if v > 1
            x = x**v
        end
        Pow[x, e]
    end
end

class Rational
    def as_power(e)
        return self if e.one?
        n = numerator
        d = denominator
        u = e.numerator
        v = e.denominator
        if u.negative?
            n,d = d,n
            u = -u
        end
        if u > 1
            n,r = n.root_floor(u)
            return self unless r.zero?
            d,r = d.root_floor(u)
            return self unless r.zero?
        end
        if v > 1
            n = n**v
            d = d**v
        end
        Pow[Rational(n,d), e]
    end
end

class NumericExpr < Numeric
    include Operation

    class << self
        def [](*args, simplify: false)
            args = normalize_args(*args)
            return args if args.is_a? Numeric

            if simplify
                args = simplify_args(*args)
                return args if args.is_a? Numeric
            end

            case args.size
                when 0
                    new0
                when 1
                    new1(args[0])
                else
                    new(*sort_args(*args))
            end
        end

        def normalize_args(*args)
            args
        end

        def simplify_args(*args)
            args
        end

        def sort_args(*args)
            args
        end

        def new0
            new
        end

        def new1(x)
            new(x)
        end
    end

    def precise?
        args.all?(&:precise?)
    end

    def algebraic?
        true
    end

    def zero?
        false
    end

    def one?
        false
    end

    def simplify
        self.class[*args.map(&:simplify), simplify: true]
    end

    def -@
        mul(-1)
    end

    def reciprocal
        pow(-1)
    end

    def pow(x)
        Pow[self, x]
    end

    def mul(x)
        Mul[self, x]
    end

    def div(x)
        mul(x.reciprocal)
    end

    def add(x)
        Add[self, x]
    end

    def sub(x)
        add(-x)
    end

    def **(x)
        if x.algebraic?
            if x.zero?
                1
            elsif x.one?
                self
            else
                pow(x)
            end
        else
            to_f ** x
        end
    end

    def *(x)
        if x.algebraic?
            if x.zero?
                0
            elsif x.one?
                self
            else
                mul(x)
            end
        else
            to_f * x
        end
    end

    def +(x)
        if x.algebraic?
            if x.zero?
                self
            else
                add(x)
            end
        else
            to_f + x
        end
    end

    def -(x)
        if x.algebraic?
            if x.zero?
                self
            else
                sub(x)
            end
        else
            to_f - x
        end
    end

    def /(x)
        if x.algebraic?
            if x.zero?
                raise ZeroDivisionError
            elsif x.one?
                self
            else
                div(x)
            end
        else
            to_f / x
        end
    end
end

class Pow < NumericExpr

    defop :**, Numeric, Numeric, &method(:[])

    class << self
        def normalize_args(base, exponent)
            if exponent.zero?
                1
            elsif exponent.one?
                base
            elsif !exponent.rational?
                raise Math::DomainError, "Irrational exponent: #{exponent.inspect}"
            else
                [base.base, base.exponent * exponent]
            end
        end

        def simplify_args(base, exponent)
            if (factors = base.factors).size > 1
                Mul[*factors.map{|f| Pow[f, exponent, simplify: true] }]
            else
                einv = exponent.reciprocal
                x = base.as_power(einv)
                if x.exponent == einv
                    Pow[x.base, exponent]
                else
                    [base, exponent]
                end
            end
        end
    end

    def base
        args[0]
    end

    def exponent
        args[1]
    end

    def precedence
        30
    end

    def inspect
        "#{inspect_child(base)}**#{inspect_child(exponent)}"
    end

    def inspect_latex
        s = base.inspect_latex
        u, v = exponent.fraction
        s = "{#{s}}^{#{u.inspect_latex}}" unless u.one?
        s = Latex.root(v, s) unless v.one?
        s
    end

    def to_f
        base.to_f ** exponent.to_f
    end

    def highest_power
        exponent.numerator.max(base.highest_power)
    end

    def expand
        s, e = exponent.factor_out_negative_one
        b = base.expand

        b = e.numerator.times.reduce(1) do |p, _|
            (p * b).expand
        end

        Pow[b, Rational(s, e.denominator), simplify: true]
    end

    def rational_degree
        base.prime_factors.pro{|_, e| (e*exponent).denominator }
    end

    def polynomial
        if base.rational?
            c = 1
            gens = _HZ
            base.prime_factors.each do |p, e|
                q, e = (e * exponent).mixed_fraction
                c *= p**q
                gens[Pow[p, Rational(1, e.denominator)]] = e.numerator unless e.integer?
            end
            _HZ(gens => c)
        else
            _HZ(_HZ(Pow[base, Rational(1, exponent.denominator)] => exponent.numerator) => 1)
        end
    end

    def ==(x)
        base == x.base && exponent == x.exponent
    end

    def reciprocal
        Pow[base, -exponent]
    end

    def as_power(e)
        return self if exponent == e
        x = e / exponent
        b = base.as_power(x)
        if b.exponent == x
            Pow[b.base, e]
        else
            self
        end
    end

    def prime_factors
        base.prime_factors.mash{|p, e| [p, e*exponent] }
    end
end

class Mul < NumericExpr
    defop :*, Numeric, Numeric, &method(:[])

    class << self
        def normalize_args(*factors)
            factors = factors.flat_map(&:factors).reject(&:one?)
            if factors.any?(&:zero?)
                0
            else
                factors
            end
        end

        def simplify_args(*factors)
            co = 1
            bases = Hash.new(0)

            factors.each do |f|
                if f.rational?
                    co *= f
                else
                    bases[f.base] += f.exponent
                end
            end

            factors = []
            factors << co unless co.one?
            bases.each do |b, e|
                factors << Pow[b, e] unless e.zero?
            end

            factors
        end

        def sort_args(*factors)
            factors.sort_by do |t|
                [t.rational_degree, t.highest_power, t.hash]
            end
        end

        def new0
            1
        end

        def new1(x)
            x
        end
    end

    def factors
        args
    end

    def polynomial
        co = 1
        gens = []
        factors.each do |f|
            if f.rational?
                co *= f.to_r
            else
                gens << f
            end
        end
        p = Hash.new(0)
        p[Mul[*gens]] = co
        p
    end

    def precedence
        20
    end

    def inspect
        factors.map{|x| inspect_child(x) }.join(' × ')
    end

    def inspect_latex
        factors.map{|x| inspect_child_latex(x) }.join
    end

    def to_f
        factors.reduce(1.0) do |p, f|
            p * f.to_f
        end
    end

    def highest_power
        factors.map(&:highest_power).max
    end

    def expand
        ft = factors.map do |f|
            f.expand.terms
        end

        return self if ft.all?{|f| f.size <= 1 }

        Add[*Enumerable.product(*ft) do |*tf|
            tf.reduce do |p, f|
                Mul[p, f, simplify: true]
            end
        end, simplify: true]
    end

    def rational_degree
        factors.reduce(1) do |d, f|
            d.max(f.rational_degree)
        end
    end

    def rational_reduction
        factors.each do |f|
            # TODO
        end
    end

    def ==(x)
        factors == x.factors
    end

    def prime_factors
        pf = _HZ
        factors.each do |f|
            pf.merge!(f.prime_factors){|_, e1, e2| e1+e2 }
        end
        pf
    end
end

class Add < NumericExpr
    defop :+, Numeric, Numeric, &method(:[])

    class << self
        def normalize_args(*terms)
            terms.flat_map(&:terms).reject(&:zero?)
        end

        def simplify_args(*terms)
            r = 0
            exprs = []

            terms.each do |t|
                if t.rational?
                    r += t
                else
                    exprs << t
                end
            end

            if r.zero?
                exprs
            else
                [r, *exprs]
            end
        end

        def sort_args(*terms)
            terms.sort_by do |t|
                [t.rational_degree, t.highest_power, t.hash]
            end
        end

        def new0
            0
        end

        def new1(x)
            x
        end
    end

    def terms
        args
    end

    def polynomial
        terms.reduce(_HZ) do |p, t|
            p.merge!(t.polynomial){|_, c1, c2| c1 + c2 }
        end
    end

    def precedence
        10
    end

    def inspect
        terms.map{|x| inspect_child(x) }.join(' + ')
    end

    def inspect_latex
        terms.map{|x| inspect_child_latex(x) }.join(' + ')
    end

    def to_f
        terms.reduce(0.0) do |s, t|
            s + t.to_f
        end
    end

    def highest_power
        terms.map(&:highest_power).max
    end

    def rational_degree
        terms.reduce(1) do |d, t|
            d.max(t.rational_degree)
        end
    end

    def ==(x)
        terms == x.terms
    end
end
