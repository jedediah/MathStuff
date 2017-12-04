require_relative 'ext'
require_relative 'latex'
require_relative 'multiplicable'

class Permutation
    include Multiplicable
    include Latex::Inspectable

    attr :to_h

    def initialize(to_h)
        @to_h = to_h.freeze
    end

    class << self
        def mul_identity
            p = allocate
            p.__send__(:initialize, Hash.mapping)
            p
        end

        def validate_index(i)
            raise TypeError, "Invalid index #{i}" unless i.is_a?(Numeric) && i.ordinal?
        end

        protected :validate_index

        forward :sort_key, :hash

        def new(h)
            if h.empty?
                one
            else
                super
            end
        end

        def mapping(h)
            if h.empty?
                one
            else
                m = Hash.mapping
                seen = Set[]
                h.each do |from, to|
                    seen.add?(to) or raise "Duplicate index #{to}"
                    m[from] = to
                end
                new(m.sort_by_key)
            end
        end

        def image(*ii)
            if ii.empty?
                one
            else
                ii.size == ii.max or raise "Incomplete index list"

                m = Hash.mapping
                seen = Set[]
                ii.each_with_index do |from, to|
                    validate_index(from)
                    seen.add?(from) or raise "Duplicate index #{from}"
                    to += 1
                    m[from] = to unless from == to
                end
                new(m)
            end
        end

        def preimage(*ii)
            if ii.empty?
                one
            else
                ii.size == ii.max or raise "Incomplete index list"

                m = Hash.mapping
                seen = Set[]
                ii.each_with_index do |to, from|
                    validate_index(to)
                    seen.add?(to) or raise "Duplicate index #{to}"
                    from += 1
                    m[from] = to unless from == to
                end
                new(m)
            end
        end

        def cycle(*c)
            if c.size < 2
                one
            else
                m = Hash.mapping
                seen = Set[]
                from = c.last
                c.each do |to|
                    validate_index(to)
                    seen.add?(to) or raise "Duplicate index #{to}"
                    m[from] = to
                    from = to
                end
                new(m.sort_by_key)
            end
        end

        def hutchins(n)
            n.odd? or raise ArgumentError, "#{n} is not odd"
            m = n.div(2)+1
            Permutation.image(m, *(m+1).upto(n).zip((m-1).downto(1)).flatten)
        end
    end

    def inspect
        if one?
            "()"
        else
            orbits.map{|o| "(#{o.map(&:inspect).join(' ')})" }.join
        end
    end

    def inspect_latex
        if one?
            Latex.vector([])
        else
            orbits.map{|o| Latex.vector(o.map(&:inspect_latex)) }.join
        end
    end

    def one?
        orbits.empty?
    end

    def parity
        orbits.sum{|o| o.size % 2 }
    end

    def even?
        parity.zero?
    end

    def odd?
        parity.one?
    end

    def <=>(x)
        sort_key <=> x.sort_key
    end

    def sort_key
        [Permutation.sort_key, to_h.size, *to_h.values]
    end

    delegate :hash, to: :to_h

    def ==(x)
        x.is_a?(Permutation) && to_h == x.to_h
    end
    forward :eql?, :==

    def size
        to_h.keys.max
    end
    cache_method :size

    def support
        (to_h.keys | to_h.values).sort
    end
    cache_method :support

    def fixes?(i)
        !to_h.key?(i)
    end

    def fixed_points
        (1..size).select{|i| fixes? i }
    end
    cache_method :fixed_points

    def orbits
        m = to_h.dup
        orbs = []
        until m.empty?
            orb = []
            i = m.keys.first
            orb << i while (i = m.delete(i))
            orb.rotate!(orb.min_with_index[1])
            orbs << orb
        end
        orbs.sort
    end
    cache_method :orbits

    def cycles
        [*orbits, *fixed_points.map{|i| [i] }].sort
    end
    cache_method :cycles

    def cycle_counts
        cycles.map(&:size).unique_counts
    end
    cache_method :cycle_counts

    def order
        orbits.reduce(1) do |p, o|
            p.lcm(o.size)
        end
    end

    def apply(x)
        if x.is_a?(Numeric) && x.ordinal?
            to_h[x]
        elsif x.is_a?(Enumerable)
            i = 1
            m = to_h.invert_mapping
            x.map do
                e = x[m[i] - 1]
                i += 1
                e
            end
        else
            raise TypeError, "Cannot permute a #{x.class}"
        end
    end
    forward :[], :apply

    def preimage
        if one?
            []
        else
            h = to_h
            n = h.keys.max
            (1..n).map{|n| h[n] }
        end
    end

    def image
        if one?
            []
        else
            h = to_h
            n = h.keys.max
            a = Array.new(n)
            (1..n).map{|n| a[h[n]-1] = n }
            a
        end
    end

    def reciprocal
        if one?
            self
        else
            q = self.class.new(to_h.invert_mapping.sort_by_key)
            q.__set_reciprocal(self)
            q
        end
    end
    cache_method :reciprocal

    def to_matrix(n=nil)
        m = to_h
        n ||= support.max
        Matrix.build(n) do |i, j|
            i+1 == m[j+1] ? 1 : 0
        end
    end

    def can_mul?(x)
        x.is_a?(Permutation)
    end

    def mul(x)
        a = to_h
        b = x.to_h
        m = Hash.mapping
        (support | x.support).sort.each do |i|
            m[i] = a[b[i]]
        end
        self.class.new(m)
    end

    forward :conjugate, :mul_conjugate
end
