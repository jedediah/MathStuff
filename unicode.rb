
require_relative 'ext'

class String
    class << self
        def codepoints(*cp)
            cp.pack('U*')
        end
    end

    SUPERSCRIPT = Hash.mapping(
        'a' => "\u1d43",
        'b' => "\u1d47",
        'c' => "\u1d9c",
        'd' => "\u1d48",
        'e' => "\u1d49",
        'f' => "\u1da0",
        'g' => "\u1d4d",
        'h' => "\u02b0",
        'i' => "\u2071",
        'j' => "\u02b2",
        'k' => "\u1d4f",
        'l' => "\u02e1",
        'm' => "\u1d50",
        'n' => "\u207f",
        'o' => "\u1d52",
        'p' => "\u1d56",
        # 'q' => "\u????",
        'r' => "\u02b3",
        's' => "\u02e2",
        't' => "\u1d57",
        'u' => "\u1d58",
        'v' => "\u1d5b",
        'w' => "\u02b7",
        'x' => "\u02e3",
        'y' => "\u02b8",
        'z' => "\u1dbb",

        '0' => "\u2070",
        '1' => "\u00b9",
        '2' => "\u00b2",
        '3' => "\u00b3",
    )

    SUBSCRIPT = Hash.mapping(
        'a' => "\u2090",
        'e' => "\u2091",
        'i' => "\u1d62",
        'j' => "\u2c7c",
        'o' => "\u2092",
        'r' => "\u1d63",
        'u' => "\u1d64",
        'v' => "\u1d65",
        'x' => "\u2093",
    )

    (4..9).each do |n|
        SUPERSCRIPT[n.to_s] = String.codepoints(0x2070 + n)
    end

    (0..9).each do |n|
        SUBSCRIPT[n.to_s] = String.codepoints(0x2080 + n)
    end

    %w{+ - = ( )}.each_with_index do |c, i|
        SUPERSCRIPT[c] = String.codepoints(0x207a + i)
        SUBSCRIPT[c] = String.codepoints(0x208a + i)
    end

    DOUBLE_STRIKE = Hash.mapping(
        'C' => "\u2102",
        'H' => "\u210d",
        'N' => "\u2115",
        'P' => "\u2119",
        'Q' => "\u211a",
        'R' => "\u211d",
        'Z' => "\u2124",
    )

    ('A'..'Z').each_with_index do |c, i|
        DOUBLE_STRIKE[c] = String.codepoints(0x1d538 + i) unless DOUBLE_STRIKE.key?(c)
    end

    ('a'..'z').each_with_index do |c, i|
        DOUBLE_STRIKE[c] = String.codepoints(0x1d552 + i)
    end

    def to_superscript
        if size == 1
            SUPERSCRIPT[self]
        else
            chars.map(&:to_superscript).join
        end
    end

    def to_subscript
        if size == 1
            SUBSCRIPT[self]
        else
            chars.map(&:to_subscript).join
        end
    end

    def overline
        gsub(/./){|c| "#{c}\u0305" }
    end

    def double_strike
        if size == 1
            DOUBLE_STRIKE[self]
        else
            chars.map(&:double_strike).join
        end
    end
end
