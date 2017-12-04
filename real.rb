
class Real
    attr :exp, :mant

    def initialize(exp, mant)
        @exp = exp
        @mant = mant
    end

    def inspect
        "#{'R'}(2^#{exp} * #{mant.take(20).map{|d| d.negative? ? (-d).to_s.overline : d.to_s }.join('')} = #{to_f})"
    end

    def to_f
        e = exp - 1
        m = 0
        s = 0
        i = 0
        mant.each do |d|
            if s.zero?
                if d.zero?
                    e -= 1
                    break if e < Float::MIN_EXP
                else
                    s = d
                end
            else
                m = (m << 1) + d*s
                i += 1
                break if i > Float::MANT_BITS # one extra bit for rounding
            end
        end

        if s.zero?
            0.0
        else
            Float.encode(s < 0, m.odd? ? (m >> 1) + 1 : m >> 1, e)
        end
    end

    def coerce(x)
        return Real[x], self
    end

    def -@
        Real.new(exp, mant.transform{|d| -d })
    end

    def pred

    end

    def succ

    end

    def +(x)
        a = self
        b = Real[x]
        a,b = b,a if a.exp < b.exp
        Real.digits(a.exp + 1) do |y|
            ea = a.mant.each
            eb = b.mant.each
            (b.exp - a.exp - 1).times do
                y << ea.next
            end
            d = 0
            loop do
                d += ea.next + eb.next
                if d >= 2
                    y << 1
                    d -= 2
                elsif d <= -2
                    y << -1
                    d += 2
                else
                    y << 0
                end
                d *= 2
            end
        end
    end

    class << self
        def zero
            new(0, Enumerable.cycle(0))
        end

        def digits(exp=0, seq=nil, &block)
            new(exp, (seq || Enumerable.generate(&block)).concat(Enumerable.cycle(0)))
        end

        def comparable(value, exp=nil)
            if exp
                upper = 2**exp
                lower = -upper
            else
                case value <=> 0
                    when -1
                        upper = 0
                        lower = -1
                        exp = 0
                        while (value <=> lower) == -1
                            lower *= 2
                            exp += 1
                        end
                    when 1
                        lower = 0
                        upper = 1
                        exp = 0
                        while (value <=> upper) == 1
                            upper *= 2
                            exp += 1
                        end
                    else
                        return zero
                end
            end

            digits(exp) do |out|
                probe = 0
                loop do
                    case value <=> probe
                        when -1
                            out << -1
                            upper = probe
                            probe = (probe + lower) / 2
                        when 1
                            out << 1
                            lower = probe
                            probe = (probe + upper) / 2
                        else
                            break
                    end
                end
            end
        end

        def [](x)
            x.is_a? Real and return x
            x.is_a? Numeric or raise ArgumentError, "#{x} is not a number"
            x.zero? and return zero

            if x.is_a? Float
                s, m, e = x.float_decode
                s = s ? -1 : 1
                p = 0
                Float::MANT_BITS.times do
                    p <<= 1
                    p |= m & 1
                    m >>= 1
                end
                p <<= 1
                p |= 1

                digits(e+1) do |y|
                    q = p
                    until q.zero?
                        y << (q.odd? ? s : 0)
                        q >>= 1
                    end
                end
            elsif x.integer?
                s = if x.negative?
                    x = -x
                    -1
                else
                    1
                end
                e = 0
                p = 0

                until x.zero?
                    e += 1
                    p <<= 1
                    p |= x & 1
                    x >>= 1
                end

                digits(e) do |y|
                    q = p
                    until q.zero?
                        y << (q.odd? ? s : 0)
                        q >>= 1
                    end
                end
            elsif x.rational?
                s = if x.negative?
                    x = -x
                    -1
                else
                    1
                end
                e = 1

                while x < 1
                    e -= 1
                    x *= 2
                end
                while 2 < x
                    e += 1
                    x /= 2
                end

                digits(e) do |y|
                    u = x.numerator
                    v = x.denominator
                    until u.zero?
                        if u < v
                            y << 0
                        else
                            y << s
                            u -= v
                        end
                        u *= 2
                    end
                end
            else
                raise ArgumentError, "Don't know how to calculate binary digits for #{x.class}"
            end
        end
    end
end
