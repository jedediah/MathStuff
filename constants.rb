require_relative 'numex'
require_relative 'continued_fraction'

module Math
    TAU ||= 2*PI
end

module Constants
    class Number < Numeric
        include Numex
    end

    class << self
        def number(cls=Number, &decl)
            Class.new(cls, &decl).new
        end
    end

    E = number do
        attr_const inspect: 'e',
                   to_f: Math::E,
                   to_i: 2

        def continued_fraction
            ContinuedFraction.generate do |coeffs|
                coeffs << 2 << 1
                n = 2
                loop do
                    coeffs << n << 1 << 1
                    n += 2
                end
            end
        end
    end

    PI = number do
        attr_const inspect: 'π',
                   to_f: Math::PI,
                   to_i: 3
    end

    TAU = number do
        attr_const inspect: 'τ',
                   to_f: Math::TAU,
                   to_i: 6
    end

    PHI = number do
        attr_const inspect: 'φ',
                   to_f: 1.6180339887498948482,
                   to_i: 1

        def continued_fraction
            ContinuedFraction.new([1].repeat)
        end
    end
end
