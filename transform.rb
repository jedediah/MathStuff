require_relative 'multiplicable'

module Transform
    class Base
        include Multiplicable
        include Latex::Inspectable

        class << self
            def mul_identity
                Identity.new
            end

            forward :sort_key, :hash
        end

        def can_mul?(x)
            case x
                when Base
                    true
                when Vector
                    x.size == 2
                when Matrix
                    x.size?(2)
                else
                    false
            end
        end

        forward :eql?, :==

        def <=>(x)
            sort_key <=> x.sort_key
        end
    end

    class << self
        def identity
            Identity.new
        end

        def rotation(angle)
            Rotoflection.new(false, angle)
        end

        def reflection(angle)
            Rotoflection.new(true, angle*2)
        end
    end

    class Identity < Base
        class << self
            def new
                @instance ||= super
            end
        end

        def inspect
            "I"
        end
        forward :to_s, :inspect

        def inspect_latex
            "I"
        end

        def sort_key
            [Base.sort_key]
        end

        def one?
            true
        end

        def reciprocal
            self
        end

        def mul(x)
            x
        end

        def hash
            [false, 0].hash
        end

        def ==(x)
            x.is_a?(Base) && x.one?
        end

        def to_matrix
            Matrix.identity(2)
        end

        def to_c
            1
        end
    end

    class Rotoflection < Base
        class << self
            def new(reflect, angle)
                angle %= 1
                reflect = !!reflect
                if angle.zero? && !reflect
                    Identity.new
                else
                    super
                end
            end
        end

        attr :angle

        def initialize(reflect, angle)
            @angle = angle
            @reflect = reflect
        end

        def reflect?
            @reflect
        end

        def inspect
            "#{'F' if reflect?}R[#{angle.inspect}]"
        end
        forward :to_s, :inspect

        def inspect_latex
            if reflect?
                s = 'F'
                # a = angle/2
                a = angle
            else
                s = 'R'
                a = angle
            end
            a = if a.denominator.divides?(360)
                "#{a * 360}°"
            else
                "\\frac{#{a.numerator unless a.numerator.one?}\\tau}{#{a.denominator}}"
            end
            "#{s}_{#{a}}"
        end

        def sort_key
            [Base.sort_key, reflect? ? 1 : 0, angle]
        end

        def hash
            [reflect?, angle].hash
        end

        def ==(x)
            x.is_a?(Rotoflection) && reflect? == x.reflect? && angle == x.angle
        end

        def one?
            false
        end

        def reciprocal
            if reflect?
                self
            else
                self.class.new(false, -angle)
            end
        end

        def mul(x)
            case x
                when Vector, Matrix
                    to_matrix * x
                when Rotoflection
                    self.class.new(x.reflect? ^ reflect?, reflect? ? angle - x.angle : angle + x.angle)
                else
                    super
            end
        end

        def to_matrix
            d = reflect? ? -1 : 1
            t = angle * TAU
            ct = cos(t)
            st = sin(t)
            Matrix[[d*ct, d*st], [-st, ct]]
        end

        def to_c
            (reflect? ? -1 : 1) * if angle.denominator.divides?(4)
                Complex::I**(angle*4)
            else
                Math.exp(angle * Math::TAU * Complex::I)
            end
        end
    end
end

