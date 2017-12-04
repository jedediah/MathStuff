require_relative 'multiplicable'
require_relative 'expr'

class Symbol
    def to_atom
        Word.atom(self)
    end
end

class String
    def to_atom
        Word.atom(self)
    end

    def to_atoms
        Word.atoms(self)
    end
end

module Word
    class << self
        def empty
            Empty.new
        end
        forward :one, :empty

        def atom(name)
            Atom[name]
        end

        def atoms(*strs)
            sep ||= /\s+/
            strs.flat_map do |s|
                s.split(sep)
            end.map do |s|
                Atom[s]
            end
        end

        def rewrite(*relations, log: false)
            RewriteSystem.new(*relations, log: log)
        end
    end

    class Base
        include Comparable
        include Multiplicable
        include Latex::Inspectable

        class << self
            def mul_identity
                Empty.new
            end
        end

        forward :eql?, :==
        forward :to_s, :inspect

        def <=>(b)
            raise NotImplementedError
        end

        def one?
            false
        end

        def can_mul?(x)
            x.is_a?(Base)
        end

        def reciprocal
            Pow[self, -1]
        end

        def mul(x)
            Mul[self, x]
        end

        def pow(x)
            Pow[self, x]
        end

        def coerce(x)
            if x.eql? 1
                return Empty.new, self
            else
                super
            end
        end

        def atom?
            false
        end

        def base
            self
        end

        def exponent
            1
        end

        def factors
            [self]
        end

        def factor_head
            factors.first
        end

        def factor_tail
            Mul[*factors.drop(1)]
        end

        def prefix(n)
            Mul[*flatten[0...n]]
        end

        def suffix(n)
            a = flatten
            Mul[*a[n...a.size]]
        end

        # Return the offset of substring x
        def index_of(x)
            a = flatten
            b = x.flatten
            return nil if a.size < b.size
            (0..a.size-b.size).each do |i|
                return i if (0...b.size).all? do |j|
                    a[i+j] == b[j]
                end
            end
            nil
        end

        # Return the offset of the suffix that is a prefix of x
        def index_of_suffix(x)
            a = flatten
            b = x.flatten
            (0.max(a.size-b.size)...a.size).each do |i|
                return i if (0...b.size.min(a.size-i)).all? do |j|
                    a[i+j] == b[j]
                end
            end
            nil
        end

        # If self and x overlap, return the shortest word containing both
        def overlaps(x)
            a = flatten
            b = x.flatten
            offsets = []
            (1-b.size .. a.size-1).each do |i|
                r = 0.max(i) ... a.size.min(b.size+i)
                offsets << i if r.all? do |j|
                    a[j] == b[j-i]
                end
            end
            offsets
        end

        def matches?(w)
            w0 = w.prefix?(head) and tail.matches?(w0)
        end

        # If w is a prefix of self, return the part of self that comes after w
        def prefix?(w)
            raise NotImplementedError
        end

        # If w is a suffix of self, return the part of self that comes before w
        def suffix?(w)
            raise NotImplementedError
        end

        # If a non-empty suffix of w is a prefix of self, return [A, O ,B] where
        #   A is the part of w before the overlap
        #   O is the overlap
        #   B is the part of self after the overlap
        def partial_prefix?(w)
            raise NotImplementedError
        end

        # If a non-empty prefix of w is a suffix of self, return [A, O, B] where
        #   A is the part of self before the overlap
        #   O is the overlap
        #   B is the part of w after the overlap
        def partial_suffix?(w)
            raise NotImplementedError
        end
        
        # If self and w share a non-empty subexpression, return the shortest expression containing self and w
        def overlaps?(w)
            raise NotImplementedError
        end

        # If w is contained in self, return [X, Y]
        # where X is the part of self before w
        # and Y is the part of self after w
        def contains?(w)
            raise NotImplementedError
        end
    end

    class Empty < Base
        class << self
            def new
                @instance ||= super
            end
        end

        def inspect
            '1'
        end

        def inspect_latex
            '1'
        end

        def hash
            0
        end

        def ==(x)
            x.is_a?(Empty)
        end

        def size
            0
        end

        def <=>(x)
            if x.one?
                0
            else
                -1
            end
        end

        def one?
            true
        end

        def factors
            []
        end

        def head
            self
        end

        def tail
            nil
        end

        def matches?(w)
            w.one?
        end

        def prefix?(w)
            self if w.one?
        end

        def suffix?(w)
            self if w.one?
        end

        def partial_prefix?(w)
        end

        def partial_suffix?(w)
        end

        def contains?(w)
            [self, self] if w.one?
        end

        def overlaps?(w)
        end

        def rewrite(from, to)
            self
        end
    end

    class Atom < Base
        attr :name

        class << self
            forward :[], :new
        end

        def initialize(name)
            name = name.to_sym
            name.blank? and raise ArgumentError, "Atom name cannot be blank"

            @name = name
        end

        def inspect
            name.to_s
        end

        def inspect_latex
            name.to_s
        end

        def hash
            name.hash
        end

        def ==(x)
            x.is_a?(Atom) && name == x.name
        end

        def size
            1
        end

        def <=>(x)
            if x.one?
                1
            elsif x.atom?
                name <=> x.name
            else
                -1
            end
        end

        def atom?
            true
        end

        def flatten
            [self]
        end

        def head
            self
        end

        def tail
            Empty.new
        end

        def matches?(w)
            w.atom? && name == w.name
        end

        def prefix?(w)
            if w.one?
                self
            elsif self == w
                Empty.new
            end
        end

        def suffix?(w)
            prefix?(w)
        end

        def partial_prefix?(w)
            if w0 = w.suffix?(self)
                [w0, self, Empty.new]
            end
        end

        def partial_suffix?(w)
            if w0 = w.prefix?(self)
                [Empty.new, self, w0]
            end
        end

        def contains?(w)
            if w.one?
                [Empty.new, self]
            elsif self == w
                [Empty.new, Empty.new]
            end
        end

        def overlaps?(w)
            if (a, o, b = w.contains?(self))
                a * o * b
            end
        end

        def rewrite(from, to)
            if self == from
                to
            else
                self
            end
        end
    end

    class Pow < Base
        attr :base, :exponent

        class << self
            def [](base, exponent)
                if base.one? || exponent.zero?
                    Empty.new
                elsif exponent.one?
                    base
                elsif !base.exponent.one?
                    self[base.base, base.exponent * exponent]
                elsif base.factors.size != 1
                    if exponent.negative?
                        Mul[*(base.factors.reverse.map(&:reciprocal) * (-exponent))]
                    else
                        Mul[*(base.factors * exponent)]
                    end
                else
                    new(base, exponent)
                end
            end
        end

        def initialize(base, exponent)
            @base = base
            @exponent = exponent
        end

        def inspect
            "#{base.inspect}#{exponent.inspect.to_superscript}"
        end

        def inspect_latex
            "#{base.inspect_latex}^{#{exponent.inspect_latex}}"
        end

        def hash
            [base, exponent].hash
        end

        def ==(x)
            x.is_a?(Pow) && base == x.base && exponent == x.exponent
        end

        def size
            base.size * exponent.abs
        end

        def <=>(x)
            if exponent.negative? != x.exponent.negative?
                x.exponent <=> exponent
            else
                (n = size <=> x.size).zero? and
                    (n = base <=> x.base).zero? and
                    n = exponent.abs <=> x.exponent.abs
                n
            end
        end

        def flatten
            if exponent.negative?
                if exponent == -1
                    [self]
                else
                    base.flatten.map do |a|
                        Pow[a, -1]
                    end * -exponent
                end
            else
                base.flatten * exponent
            end
        end

        def matches?(w)
            base == w.base && exponent == w.exponent
        end

        def prefix?(w)
            if w.one?
                self
            elsif base == w.base && exponent.negative? == w.exponent.negative? && exponent.abs >= w.exponent.abs
                base**(exponent - w.exponent)
            end
        end

        def suffix?(w)
            prefix?(w)
        end

        def contains?(w)
            if w.one?
                [Empty.new, self]
            elsif base == w.base && exponent.negative? == w.exponent.negative? && exponent.abs >= w.exponent.abs
                [Empty.new, base**(exponent - w.exponent)]
            end
        end

        def overlaps?(w)
            if base == w.base
                if exponent.negative? == w.exponent.negative?
                    if exponent.negative?
                        base**(exponent.min(w.exponent))
                    else
                        base**(exponent.max(w.exponent))
                    end
                end
            elsif w.exponent.one?
                w.overlaps?(self)
            end
        end

        def partial_prefix?(w)
            w.partial_suffix?(self)
        end

        def partial_suffix?(w)
            if base == w.base
                if exponent.negative? == w.exponent.negative?
                    if exponent.abs <= w.exponent.abs
                        [Empty.new, self, w.base**(w.exponent - exponent)]
                    else
                        [base**(exponent - w.exponent), w, Empty.new]
                    end
                end
            elsif w.exponent.one?
                w.partial_prefix?(self)
            end
        end

        def rewrite(from, to)
            if base == from.base
                if exponent == from.exponent
                    to
                elsif exponent.negative? == from.exponent.negative? && exponent.abs >= from.exponent.abs
                    q, r = exponent.divmod(from.exponent)
                    to**q * base**r
                else
                    self
                end
            else
                self
            end
        end
    end

    class Mul < Base
        attr :factors

        class << self
            def [](*factors)
                a = []
                factors.flat_map(&:factors).each do |f|
                    if f.one?
                        next
                    elsif !a.empty? && a[-1].base == f.base
                        f = Pow[f.base, a.pop.exponent + f.exponent]
                        a << f unless f.one?
                    else
                        a << f
                    end
                end
                case a.size
                    when 0
                        Empty.new
                    when 1
                        a[0]
                    else
                        new(a)
                end
            end
        end

        def initialize(factors)
            @factors = factors.freeze
        end

        def inspect
            factors.map(&:inspect).join
        end

        def inspect_latex
            factors.map(&:inspect_latex).join
        end

        def hash
            factors.hash
        end

        def ==(x)
            x.is_a?(Mul) && factors == x.factors
        end

        def size
            factors.sum(&:size)
        end

        def <=>(x)
            n = size <=> x.size
            return n unless n.zero?
            flatten <=> x.flatten
        end

        def flatten
            factors.flat_map(&:flatten)
        end

        def subproduct(r)
            f = factors[r]
            case f.size
                when 0
                    Empty.new
                when 1
                    f[0]
                else
                    Mul.new(f)
            end
        end

        def matches?(w)
            w0 = w.prefix?(factor_head) and factor_tail.matches?(w0)
        end

        def prefix?(w)
            if w.one?
                self
            elsif w0 = w.prefix?(factors[0])
                subproduct(1..-1).prefix?(w0)
            elsif f0 = factor_head.prefix?(w)
                f0 * subproduct(1..-1)
            end
        end

        def suffix?(w)
            if w.one?
                self
            elsif w0 = w.suffix?(factors[-1])
                subproduct(0..-2).suffix?(w0)
            elsif f0 = factors[-1].suffix?(w)
                subproduct(0..-2) * f0
            end
        end

        def contains?(w)
            if w.one?
                [Empty.new, self]
            elsif (a, b = factors[0].contains?(w))
                [a, b * subproduct(1..-1)]
            elsif (a, _, w0 = factors[0].partial_suffix?(w)) && (b = subproduct(1..-1).prefix?(w0))
                [a, b]
            elsif (a, b = subproduct(1..-1).contains?(w))
                [factors[0] * a, b]
            end
        end

        def overlaps?(w)
            if w.one?
                nil
            elsif factors.any?{|f| f.contains?(w) }
                self
            elsif (a, o, b = partial_suffix?(w))
                a * o * b
            elsif (a, o, b = partial_prefix?(w))
                a * o * b
            end
        end

        def partial_prefix?(w)
            if (w0, o, h0 = factors[-1].partial_prefix?(w)) && (w1 = w0.suffix?(head = subproduct(0..-2)))
                [w1, head * o, h0]
            elsif (w0, o, t0 = subproduct(0..-2).partial_prefix?(w))
                [w0, o, t0 * factors[-1]]
            end
        end

        def partial_suffix?(w)
            if (h0, o, w0 = factors[0].partial_suffix?(w)) && (w1 = w0.prefix?(tail = subproduct(1..-1)))
                [h0, o * tail, w1]
            elsif (t0, o, w0 = subproduct(1..-1).partial_suffix?(w))
                [factors[0] * t0, o, w0]
            end
        end

        # Iteratively replace from with to while from is a subexpression of self
        def rewrite(from, to)
            f0 = factors[0].rewrite(from, to)
            if (a, _, w0 = f0.partial_suffix?(from)) && (b = subproduct(1..-1).prefix?(w0))
                Mul[a, to, b.rewrite(from, to)].rewrite(from, to)
            else
                Mul[f0, subproduct(1..-1).rewrite(from, to)]
            end
        end
    end

    class RewriteSystem
        include Latex::Inspectable

        attr :relations, :rules

        def inspect
            "#{self.class.name}#{rules.inspect}"
        end

        def inspect_latex
            if rules.empty?
                "#{self.class.name}\\{\\}"
            else
                a = rules.to_a
                Latex.table(rules.size, 3, border: false) do |i, j|
                    case j
                        when 0
                            Latex.render(a[i][0])
                        when 1
                            '\\rightarrow'
                        when 2
                            Latex.render(a[i][1])
                    end
                end
            end
        end

        def initialize(*relations, rules: nil, log: false)
            self.log = log
            @relations = Hash.mapping
            @rules = rules ? rules.dup : Hash.mapping

            relations.each do |r|
                if r.respond_to? :to_hash
                    r.to_hash.each do |a, b|
                        _add_relation(a, b, true)
                    end
                else
                    _add_relation(r, r.class.one, true)
                end
            end

            @relations.freeze

            _log "completion" do
                ALEPH0.times do |tries|
                    done = true
                    _log "round #{tries}" do
                        @rules.dup.combination(2) do |(from1, to1), (from2, to2)|
                            if o = from1.overlaps?(from2)
                                _log "found overlap between #{from1} -> #{to1} and #{from2} -> #{to2}" do
                                    _log "reducing #{o} with both rules"
                                    r1 = apply(o.rewrite(from1, to1))
                                    r2 = apply(o.rewrite(from2, to2))
                                    _log "rule 1 reduces it to #{r1}"
                                    _log "rule 2 reduces it to #{r2}"
                                    if _add_relation(r1, r2)
                                        done = false
                                    else
                                        _log "no relations added"
                                    end
                                end
                            end
                        end
                    end
                    break if done

                    tries >= bailout and raise "Rewrite system could not be completed in #{bailout} iterations"
                end
            end

            @rules.freeze
        end

        def bailout
            100
        end

        def log?
            !!@log
        end

        def log=(b)
            if b
                @log ||= ''
            else
                @log = nil
            end
            b
        end

        def _log(msg)
            if log?
                puts "#{@log}#{msg}"
                if block_given?
                    old = @log
                    @log = "#{@log}  "
                    begin
                        yield
                    ensure
                        @log = old
                    end
                end
            else
                yield if block_given?
            end
        end

        def _add_rule(k, v)
            _log "add rule #{k} -> #{v}" do
                rules.reject! do |k0, v0|
                    k0.contains?(k).tap do |b|
                        b and _log "remove obsolete rule #{k0} -> #{v0}"
                    end
                end
                rules[k] = v
            end
        end

        def _add_relation(a, b, explicit=false)
            case a <=> b
                when -1
                    relations[b] = a if explicit
                    _add_rule(b, a)
                    [b, a]
                when 1
                    relations[a] = b if explicit
                    _add_rule(a, b)
                    [a, b]
            end
        end

        def unify(a)
            equate(a, a.class.one)
        end

        def equate(a, b)
            self.class.new(relations.merge(a => b), rules: rules, log: log?)
        end

        def merge(rr={})
            if rr.empty?
                self
            else
                self.class.new(relations.merge(rr), rules: rules, log: log?)
            end
        end

        def apply(w)
            loop do
                w1 = rules.reduce(w) do |w0, (from, to)|
                    w0.rewrite(from, to)
                end
                break w if w == w1
                w = w1
            end
        end
        forward :[], :apply
    end
end
