
class Float
    MANT_BITS = MANT_DIG - 1
    MANT_MASK = (1 << MANT_BITS) - 1

    EXP_BITS = MAX_EXP.to_s(2).size
    EXP_MASK = (MAX_EXP | (MAX_EXP - 1)) << MANT_BITS
    EXP_OFFSET = MAX_EXP - 1

    def float_bits
        [self].pack('d').unpack('q')[0]
    end

    def float_decode
        x = float_bits
        return x < 0,
               x & MANT_MASK,
               ((x & EXP_MASK) >> MANT_BITS) - EXP_OFFSET
    end

    def float_inspect
        s, m, e = float_decode
        m = if m.zero?
            '1'
        else
            "1.#{m.to_s(2).rjust(MANT_BITS, '0').sub(/0*$/, '')}"
        end
        "#{'-' if s}#{m}e#{e}"
    end

    class << self
        def encode(neg, mant, exp)
            if exp > MAX_EXP
                INFINITY
            elsif exp < MIN_EXP
                -INFINITY
            else
                [(neg ? 1 << EXP_BITS + MANT_BITS : 0) | ((exp + EXP_OFFSET) << MANT_BITS) | (mant & MANT_MASK)].pack('q').unpack('d')[0]
            end
        end
    end
end
