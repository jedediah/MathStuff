class Ordinal < Numeric
    include Coercible
    include Comparable
    include Sett::Base
    include Latex::Inspectable

    # "Cantor Normal Form" polynomial
    # { e1 => c1, e2 => c2, ... }
    # self == ω**e1 * c1 + ω**e2 * c2 ...
    # e[i] is ordinal, c[i] is integer > 0
    # map is always sorted by e[i] descending
    attr :cantor_normal_form

    def initialize(cnf)
        cnf.nil? and raise ArgumentError
        @cantor_normal_form = cnf
    end

    class << self
        def [](cnf={})
            cnf.each do |e, c|
                e.ordinal? or raise ArgumentError, "Exponent #{e} must be an ordinal"
                c.integer? or raise ArgumentError, "Coefficient #{c} must be an integer"
                c.negative? and raise ArgumentError, "Coefficient #{c} must be non-negative"
            end

            h = NormalizedHash.new(0)
            cnf.keys.sort_desc.each do |e|
                h[e] = cnf[e]
            end

            if h.empty?
                0
            elsif h.size == 1 && h.keys.first.zero?
                h[0]
            else
                new(h)
            end
        end

        def _verify(*s)
            s.each do |x|
                x.try(:ordinal?) or raise ArgumentError, "#{x} is not an ordinal number"
            end
        end

        def cmp(a, b)
            _verify(a, b)
            if a.finite?
                if b.finite?
                    a.to_i <=> b.to_i
                else
                    -1
                end
            else
                if b.finite?
                    1
                else
                    Enumerable.zip(a.cantor_normal_form, b.cantor_normal_form) do |(ae, ac), (be, bc)|
                        if ae.nil?
                            return -1
                        elsif be.nil?
                            return 1
                        elsif ae != be
                            return ae <=> be
                        elsif ac != bc
                            return ac <=> bc
                        end
                    end

                    0
                end
            end
        end

        def add(a, b)
            return a if b.zero?
            return b if a.zero?

            cnf = NormalizedHash.new(0)
            (be1, bc1), *btail = b.cantor_normal_form.to_a

            a.cantor_normal_form.each do |ae, ac|
                break if ae <= be1
                cnf[ae] = ac
            end

            cnf[be1] = a.cantor_normal_form[be1] + bc1

            btail.each do |be, bc|
                cnf[be] = bc
            end

            new(cnf)
        end

        def mul(a, b)
            return 0 if a.zero? || b.zero?
            return b if a.one?
            return a if b.one?

            ae1, ac1 = a.cantor_normal_form.first
            b.cantor_normal_form.sum do |be, bc|
                if be.zero?
                    self[a.cantor_normal_form.merge(ae1 => ac1 * bc)]
                else
                    self[ae1 + be => bc]
                end
            end
        end

        def pow(a, b)
            return 1 if a.zero? || b.zero?
            return a if a.one? || b.one?

            if b.natural?
                (ae1, ac1), *amid, (_, am) = a._decompose_ordinal
                p = ae1 * (b-1)
                if am.zero?
                    a.cantor_normal_form.sum do |e, c|
                        self[p + e => c]
                    end
                else
                    ainf = [[ae1, ac1], *amid]
                    [
                        *ainf.map do |e, c|
                            self[p + e => c]
                        end,
                        *(1..(b-1)).flat_map do |j|
                            [
                                self[ae1 * (b-j) => ac1*am],
                                *amid.map do |e, c|
                                    self[ae1 * (b-j-1) + e => c]
                                end
                            ]
                        end,
                        am
                    ].sum
                end
            elsif b.ordinal?
                if a.finite?
                    b.cantor_normal_form.pro do |be, bc|
                        if be.zero?
                            a**bc
                        elsif be.finite?
                            self[self[be-1 => bc] => 1]
                        else
                            self[self[be => bc] => 1]
                        end
                    end
                else
                    *binf, (_, bm) = b._decompose_ordinal
                    self[a.cantor_normal_form.keys.first * self[binf.to_h] => 1] * a**bm
                end
            else
                raise Math::DomainError
            end
        end
    end

    def inspect
        cantor_normal_form.map do |e, c|
            if e.zero?
                c.inspect
            else
                s = 'ω'
                s << "**(#{e.inspect})" unless e.one?
                s << " * #{c.inspect}" unless c.one?
                s
            end
        end.join(' + ')
    end
    forward :to_s, :inspect

    def inspect_latex
        cantor_normal_form.map do |e, c|
            if e > 0
                s = '\\omega'
                s << " ^{#{e.inspect_latex}}" unless e.one?
                s << " #{c.inspect_latex}" unless c.one?
                s
            else
                c.inspect_latex
            end
        end.join(' + ')
    end

    def zero?
        false
    end

    def one?
        false
    end

    def finite?
        false
    end

    def infinite?
        true
    end

    def ordinal?
        true
    end

    def limit_ordinal?
        cantor_normal_form[0].zero?
    end

    def successor_ordinal?
        !limit_ordinal?
    end

    # Return ordinal CNF terms as
    #   [[e1, c1], *[e_n, c_n], [0, m]]
    # where [e1, c1] are the leading exponent and coefficient,
    # [0, m] is the last (finite) term, and *[e_n, c_n] are
    # the (possibly empty) terms in between.
    # For a natural number, the first and last terms will be the same.
    def _decompose_ordinal
        if limit_ordinal?
            [*cantor_normal_form, [0, 0]]
        else
            cantor_normal_form.to_a
        end
    end

    def pred
        c0 = cantor_normal_form[0]
        c0.zero? and raise TypeError, "No predecessor defined for limit ordinal #{self}"
        Ordinal[cantor_normal_form.merge(0 => c0 - 1)]
    end

    def succ
        Ordinal[cantor_normal_form.merge(0 => cantor_normal_form[0] + 1)]
    end

    def hash
        cantor_normal_form.hash
    end

    def ==(x)
        x.ordinal? && cantor_normal_form == x.cantor_normal_form
    end
    forward :eql?, :==

    def size
        ALEPH0
    end

    def include?(x)
        x.ordinal? && x < self
    end

    OMEGA = self[1 => 1]
end
