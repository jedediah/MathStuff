require_relative 'arithmetic'

class ContinuedFraction < NumericExpr
    include Numex

    attr :coeffs

    def initialize(coeffs)
        @coeffs = coeffs
    end

    class << self
        def new(coeffs)
            if coeffs.empty?
                super([0])
            else
                super
            end
        end

        def [](*coeffs)
            new(coeffs)
        end

        def generate(eager=false, &block)
            if eager
                coeffs = []
                block[coeffs]
                new(coeffs)
            else
                new(Enumerator.new(&block))
            end
        end

        def calculate(x)
            generate(true) do |coeffs|
                loop do
                    n, x = x.mixed_fraction
                    coeffs << n
                    break if x.zero?
                    x = x.reciprocal
                end
            end
        end
    end

    def inspect
        if coeffs.cardinality.finite?
            "<#{coeffs.first.inspect}; #{coeffs.suffix(1).map(&:inspect).join(', ')}>"
        else
            "<#{coeffs.first.inspect}; #{coeffs.subseq(1..4).map(&:inspect).join(', ')}, ...>"
        end
    end

    def inspect_latex
        if coeffs.cardinality.finite?
            coeffs.map do |c|
                Latex.render(c)
            end.reverse.reduce do |s, c|
                "#{c} + \\frac{1}{#{s}}"
            end
        else
            cc = coeffs.prefix(7).map do |c|
                Latex.render(c)
            end.reverse
            cc.suffix(1).reduce("#{cc.first} + \\ddots") do |s, c|
                "#{c} + \\frac{1}{#{s}}"
            end
        end
    end

    def hash
        coeffs.hash
    end

    def ==(x)
        coeffs == x.continued_fraction.coeffs
    end

    def mixed_fraction
        [coeffs.first, ContinuedFraction.new(coeffs.suffix(1))]
    end

    def continued_fraction
        self
    end

    # TODO
    # def <=>(x)
    #
    # end

    def reciprocal
        if coeffs.first.zero?
            ContinuedFraction.new(coeffs.suffix(1))
        else
            ContinuedFraction.new(coeffs.prepend(0))
        end
    end

    def convergents
        u0, v0 = 0, 1
        u1, v1 = 1, 0
        coeffs.each do |c|
            u0, u1 = u1, u0 + c*u1
            v0, v1 = v1, v0 + c*v1
            yield Rational(u1, v1)
        end
    end
    enum_method :convergents

    def convergent(i)
        i = i.max(0).min(coeffs.cardinality)
        if i.zero?
            0
        elsif i.infinite?
            raise "Cannot evaluate infinite continued fraction"
        else
            u0, v0 = 0, 1
            u1, v1 = 1, 0
            coeffs.take(i.max(1)).each do |c|
                u0, u1 = u1, u0 + c*u1
                v0, v1 = v1, v0 + c*v1
            end
            Rational(u1, v1)
        end
    end

    def to_f
        f0 = 0.0
        convergents.each do |r|
            f1 = r.to_f
            return f1 if f0 == f1
            f0 = f1
        end
    end
end

class Numeric
    def continued_fraction
        ContinuedFraction.calculate(self)
    end
end

class Float
    def continued_fraction
        to_r.continued_fraction
    end
end
