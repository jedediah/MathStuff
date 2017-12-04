class Integer
    def residue(p)
        Residue.new(self, p)
    end
end

class Residue
    attr :r, :p

    def initialize(r, p)
        @r = r % p
        @p = p
    end

    def inspect
        "#{r.inspect}#{p.inspect.to_subscript}"
    end

    def inspect_latex
        "#{r.inspect_latex}_{#{p.inspect_latex}}"
    end

    def to_i
        r
    end

    def _coerce(x)
        if x.is_a?(Residue) && p == x.p
            if p == x.p
                x
            else
                raise TypeError, "Cannot coerce from modulo #{p} to modulo #{x.p}"
            end
        else
            self.class.new(x, p)
        end
    end

    def coerce(a)
        return _coerce(a), self
    end

    def hash
        [r, p].hash
    end

    def eql?(b)
        b.is_a?(Residue) && r == b.r && p == b.p
    end

    def zero?
        r.zero?
    end

    def one?
        r.one?
    end

    def congruent?(b)
        if b.is_a? Residue
            r == b.r && p == b.p
        else
            r == b % p
        end
    end

    def _rep(x)
        if x.is_a? Residue
            if p == x.p
                x.r
            else
                raise TypeError, "Cannot coerce from modulo #{p} to modulo #{x.p}"
            end
        else
            x % p
        end
    end

    def -@
        self.class.new(-r, p)
    end

    def +(b)
        self.class.new(r + _rep(b), p)
    end

    def -(b)
        self.class.new(r - _rep(b), p)
    end

    def reciprocal
        t = p.class.zero
        t0 = p.class.one
        a = p
        a0 = r
        until a0.zero?
            a, q, a0 = a0, *a.divmod(a0)
            t, t0 = t0, t - q*t0
        end
        a.one? or raise TypeError, "#{inspect} has no multiplicative inverse"
        self.class.new(t, p)
    end

    def *(b)
        self.class.new(r * _rep(b), p)
    end

    def /(b)
        self.class.new(r * _coerce(b).reciprocal.r, p)
    end

    def **(n)
        n.integer? or raise ArgumentError, "Non-integer powers not implemented"
        if n < 0
            reciprocal**(-n)
        else
            self.class.new(r**n, p)
        end
    end

    class << self
        def modulo(p)
            (0...p).map{|r| new(r, p) }
        end
    end
end
