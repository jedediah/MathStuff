require 'active_support/core_ext/object/try'

require_relative 'ext'
require_relative 'coercible'
require_relative 'math'
require_relative 'ring'
require_relative 'latex'
require_relative 'plot'

class Eisenstein < Numeric
    include Ring
    include Coercible
    include Latex::Inspectable

    attr :a, :b

    def initialize(a, b=nil)
        b ||= 0
        a.integer? or raise ArgumentError, "#{a} is not an integer"
        b.integer? or raise ArgumentError, "#{b} is not an integer"
        @a = a
        @b = b
    end

    def _inspect(om)
        if a.zero?
            case b
                when -1
                    "-#{om}"
                when 0
                    '0'
                when 1
                    om
                else
                    "#{b}#{om}"
            end
        else
            case b
                when -1
                    "#{a}-#{om}"
                when 0
                    a.to_s
                when 1
                    "#{a}+#{om}"
                else
                    if b.negative?
                        "#{a}#{b}#{om}"
                    else
                        "#{a}+#{b}#{om}"
                    end
            end
        end
    end

    def inspect
        _inspect('ω')
    end
    forward :to_s, :inspect

    def inspect_latex
        _inspect('\\omega')
    end

    def zero?
        a.zero? && b.zero?
    end

    def one?
        a.one? && b.zero?
    end

    def natural?
        a.natural? && b.zero?
    end

    def integer?
        b.zero?
    end
    forward :rational?, :integer?
    forward :real?, :integer?

    def algebraic?
        true
    end

    def real
        a - b / 2.0
    end

    def imag
        b * sqrt(3) / 2.0
    end
    forward :imaginary, :imag

    def to_c
        Complex.rect(real, imag)
    end

    def to_i
        if b.zero?
            a
        else
            raise RangeError, "Can't convert #{self} into Integer"
        end
    end
    forward :to_r, :to_i

    def to_f
        if b.zero?
            a.to_f
        else
            raise RangeError, "Can't convert #{self} into Float"
        end
    end

    def norm
        a**2 - a*b + b**2
    end

    def abs
        sqrt(norm)
    end

    def unit?
        norm.one?
    end

    def hash
        [a, b].hash
    end

    def ==(y)
        if y.is_a? Eisenstein
            a == y.a && y == y.b
        elsif y.try(&:integer?)
            a == y.to_i && y.zero?
        end
    end
    forward :eql?, :==

    def coerce(x)
        if x.integer?
            super
        else
            return x, to_c
        end
    end

    def -@
        self.class.new(-a, -b)
    end

    def conj
        self.class.new(a-b, -b)
    end
    forward :conjugate, :conj

    class << self
        include Enumerable

        def new(a, b=nil)
            if a.is_a?(Eisenstein) && b.nil?
                a
            else
                b ||= 0
                a.integer? && b.integer? or raise ArgumentError, "integers required"
                if b.zero?
                    a
                else
                    super(a.to_i, b.to_i)
                end
            end
        end
        forward :[], :new

        def _unpack(a, b=nil)
            if a.is_a?(Eisenstein) && b.nil?
                return a.a, a.b
            elsif a.try(:integer?)
                return a.to_i, b.to_i
            else
                raise ArgumentError, "#{a} is not an Eisenstein integer"
            end
        end

        def add(x, y)
            xa, xb = _unpack(x)
            ya, yb = _unpack(y)
            new(xa+ya, xb+yb)
        end

        def sub(x, y)
            xa, xb = _unpack(x)
            ya, yb = _unpack(y)
            new(xa-ya, xb-yb)
        end

        def mul(x, y)
            xa, xb = _unpack(x)
            ya, yb = _unpack(y)
            bb = xb*yb
            new(xa*ya - bb, xa*yb + xb*ya - bb)
        end

        # Return [u, v] such that u/v = x/y and v is an integer.
        # If y is an integer, this is just [x, y]
        # Otherwise, x and y are multiplied by y.conj to get
        #    u = x * y.conj
        #    v = y.norm
        def realize_denom(x, y)
            if y.integer?
                return x, y.to_i
            else
                return mul(x, y.conj), y.norm
            end
        end

        def divides?(x, y)
            if x.integer?
                x = x.to_i
                ya, yb = _unpack(y)
                x.divides?(ya) && x.divides?(yb)
            else
                u, v = realize_denom(y, x)
                divides?(v, u)
            end
        end

        # If y divides x, return the quotient x/y
        # Otherwise, raise ArgumentError
        def div(x, y)
            u, v = realize_denom(x, y)
            a = u.a / v
            b = u.b / v
            a.integer? && b.integer? or raise ArgumentError, "#{y} does not divide #{x}"
            new(a, b)
        end

        # Return the Euclidean remainder of x/y
        def mod(x, y)
            yc = y.conj
            u = mul(x, yc)
            v = y.norm
            new(u.a % v, u.b % v) / yc
        end

        # Return [q, r], the Euclidean quotient and remainder of x/y
        def divmod(x, y)
            yc = y.conj
            u = mul(x, yc)
            v = y.norm
            q1,r1 = u.a.divmod(v)
            q2,r2 = u.b.divmod(v)
            return new(q1,q2), new(r1,r2)/yc
        end

        def naturalize(x)
            a, b = _unpack(x)
            if b.negative?
                if !a.negative?
                    new(a-b, a)
                elsif b <= a
                    new(-b, a-b)
                else
                    new(-a, -b)
                end
            else
                if a.negative?
                    new(b-a, -a)
                elsif b >= a
                    new(b, b-a)
                else
                    new(a, b)
                end
            end
        end

        def prime?(x)
            a, b = _unpack(x)
            n = if b.zero? || a == b
                a.abs
            elsif x.a.zero?
                b.abs
            end
            if n
                n % 3 == 2 && Integer.prime?(n)
            else
                Integer.prime?(x.norm)
            end
        end

        def units
            @units ||= 6.times.map{|n| new(1, 1)**n }
        end

        def each
            yield 0
            1.andup do |i|
                i.times{|j| yield new(i  , j  ) }
                i.times{|j| yield new(i-j, i  ) }
                i.times{|j| yield new( -j, i-j) }
                i.times{|j| yield new( -i,  -j) }
                i.times{|j| yield new(j-i,  -i) }
                i.times{|j| yield new(j  , j-i) }
            end
        end
        enum_method :each

        def naturals
            1.andup do |i|
                i.times{|j| yield new(i,j) }
            end
        end
        enum_method :naturals

        def primes
            0.andup do |i|
                (0..i/2).each do |j|
                    if prime?(p = new(i, j))
                        yield p
                        yield new(i, i-j) unless j == 0 || (j == 1 && i == 2)
                    end
                end
            end
        end
        enum_method :primes

        def grid(gen=1)
            Grid.new(gen)
        end

        def plot(origin: 0, range: 2, size: 300, radius: nil, grid: true, &block)
            Rubyvis::Panel.new do
                size = Vector[size, size] unless size.is_a? Vector
                domain = [-range, range].map{|x| origin+x }

                width size[0]
                height size[1]

                size_minor = size[0].min(size[1])

                scale = [:real, :imag].map do |axis|
                    Rubyvis::Scale
                        .linear(*domain.map(&axis))
                        .range(0, size_minor)
                end

                if grid
                    grid_spacing = 1.max(24 * range / size_minor)
                    grid_count = (2*range/grid_spacing).ceil
                    grid_step = grid_spacing * Eisenstein[0,1].imag * Complex::I

                    Eisenstein.units.values_at(0,2,4).each do |axis|
                        (-grid_count..grid_count).each do |n|
                            line do
                                data [-1,1]
                                p = proc{|d| (2*d*range + n*grid_step) * axis }
                                left{|d| scale[0][p[d].real] }
                                bottom{|d| scale[1][p[d].imag] }
                                line_width 1
                                stroke_style n.zero? ? '#bbb' : '#eee'
                                fill_style nil
                            end
                        end
                    end
                end

                dot do
                    data []
                    left{|x| scale[0][x.real] }
                    bottom{|x| scale[1][x.imag] }
                    stroke_style nil
                    fill_style '#08a'

                    radius ||= 2.max(0.15*size_minor/range)
                    shape_radius radius

                    if radius >= 3
                        anchor('center').label do
                            text{|x| x.inspect }
                            text_style 'white'
                            font_size radius*0.7
                        end
                    end

                    instance_exec(&block)
                end
            end
        end
    end

    class Grid
        include Plot::Drawable

        attr :gen

        def initialize(gen=1)
            @gen = gen
        end

        def draw(ctx)
            g = @gen
            t = Eisenstein[0,1].imag*Complex::I
            # ctx.style stroke: '#ddd', stroke_width: ctx.px(1) do
                Eisenstein.units.values_at(0,2,4).each do |d|
                    d = g * d
                    ctx.grill 0, t*d.to_c
                    # ctx.ray 0, d, stroke: '#aaa'
                end
            # end
        end
    end
end
