load File.join(File.dirname(__FILE__), 'math.rb')

class Rootex < Numeric
    # [prime_roots] => coefficient
    attr :terms

    def initialize(terms)
        @terms = terms
        unless @terms.frozen?
            @terms.default = 0
            @terms.freeze
        end
    end

    class << self
        def [](terms={})
            h = {}
            h.default = 0

            terms.each do |root, co|
                prime_roots = []
                root.prime_factors.each do |prime, exponent|
                    q, r = exponent.divmod(2)
                    co *= prime**q
                    prime_roots << prime if r == 1
                end
                h[prime_roots.sort] += co
            end

            simplify(h)
        end

        def simplify(terms)
            terms.delete_if{|_, co| co == 0}

            if terms.keys.all?(&:empty?)
                terms[[]]
            else
                new(Hash[terms.sort_by{|roots, _| roots.reduce(1, &:*)}])
            end
        end
    end

    def inspect
        terms.reduce('') do |s, (roots, co)|
            if s.empty?
                s << '-' if co < 0
            else
                s << (co < 0 ? ' -' : ' +')
            end
            unless co.abs == 1
                s << co.abs.to_s
            end
            unless roots.empty?
                s << "√#{roots.reduce(1, &:*)}"
            end
            s
        end
    end

    def to_f
        terms.reduce(0.0) do |f, (roots, co)|
            f + (co * sqrt(roots.reduce(1, &:*)))
        end
    end

    def sum(d, x)
        if x == 0
            self
        else
            h = {}
            h.default = 0

            terms.each do |roots, co|
                h[roots] += co
            end

            if x.is_a? Rootex
                x.terms.each do |roots, co|
                    h[roots] += d*co
                end
            else
                h[[]] += d*x
            end

            self.class.simplify(h)
        end
    end

    def +(x)
        sum(1, x)
    end

    def -(x)
        sum(-1, x)
    end

    def -@
        self.class.new(Hash[terms.map{|roots, co| [roots, -co] }])
    end

    def *(x)
        if x == 0
            0
        elsif x == 1
            self
        else
            h = {}
            h.default = 0

            if x.is_a? Rootex
                terms.each do |aroots, aco|
                    x.terms.each do |broots, bco|
                        squares = aroots & broots
                        roots = ((aroots | broots) - squares).sort
                        h[roots] += aco * bco * squares.reduce(1, &:*)
                    end
                end
            else
                terms.each do |roots, co|
                    h[roots] += co * x
                end
            end

            self.class.simplify(h)
        end
    end

end
