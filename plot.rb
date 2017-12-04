require 'base64'
require 'active_support/core_ext/module/delegation'
require 'rasem'
require 'chunky_png'

module Plot
    class << self
        def vec(c, w=1)
            if c.is_a? Vector
                c = c.map(&:to_f)
                if c.size == 2
                    Vector[*c, w]
                else
                    c
                end
            elsif c.is_a? Array
                Vector[*c.map(&:to_f), w]
            elsif c.respond_to?(:real) && c.respond_to?(:imag)
                Vector[c.real.to_f, c.imag.to_f, w]
            elsif c.respond_to?(:to_c)
                c = c.to_c
                Vector[c.real.to_f, c.imag.to_f, w]
            elsif c.respond_to?(:to_f)
                Vector[c.to_f, 0, w]
            else
                raise ArgumentError, "Don't know how to plot #{c}"
            end
        end

        def line(a, d=nil, to: nil)
            if a.is_a?(Line) && d.nil? && to.nil?
                a
            elsif !to.nil?
                a = vec(a)
                Line.new(a, vec(to)-a)
            else
                Line.new(vec(a), vec(d, 0))
            end
        end

        def transform(t=nil)
            if t.nil?
                Matrix.identity(3)
            elsif t.respond_to? :to_matrix
                t = t.to_matrix
                if t.row_count == 3 && t.column_count == 3
                    t
                else
                    Matrix[[*t.row(0), 0],
                           [*t.row(1), 0],
                           [0, 0, 1]]
                end
            else
                raise ArgumentError, "Cannot coerce #{t.class} into a transform"
            end
        end

        def scale(s)
            if s.is_a? Vector
                Matrix[[s.x, 0,   0],
                       [0,   s.y, 0],
                       [0,   0,   1]]
            else
                s = s.to_f
                Matrix[[s, 0, 0],
                       [0, s, 0],
                       [0, 0, 1]]
            end
        end

        def translate(v)
            v = vec(v)
            Matrix[[1, 0, v.x],
                   [0, 1, v.y],
                   [0, 0, 1]]
        end

        def rotate(r)
            s = sin(r)
            c = cos(r)
            Matrix[[c, s, 0],
                   [-s, c, 0],
                   [0, 0, 1]]
        end

        def drawable(&draw)
            Drawable::Anonymous.new(&draw)
        end
    end

    module Transformable
        class Transformer
            def initialize(trans)
                @trans = Plot.transform(trans)
            end

            def *(x)
                if x.is_a? Transformable
                    x.transform(@trans)
                else
                    @trans * x
                end
            end
        end

        def coerce(trans)
            return Transformer.new(trans), self
        end

        def transform(trans)
            raise NotImplementedError
        end
    end

    module Drawable
        def draw(ctx)
            raise NotImplementedError
        end

        class Anonymous
            include Drawable
            def initialize(&draw)
                @draw = draw
            end

            def draw(ctx)
                @draw[ctx]
            end
        end
    end

    class Line
        include Transformable

        attr :origin, :delta

        def initialize(origin, delta)
            @origin = Plot.vec(origin)
            @delta = Vector[*Plot.vec(delta, 0).xy, 0]
        end

        class << self
            def between(a, b)
                a = Plot.vec(a)
                b = Plot.vec(b)
                new(a, b-a)
            end
        end

        def inspect
            "#{origin} -> #{tip} delta=#{delta}"
        end
        forward :to_s, :inspect

        def length2
            delta.norm2
        end
        cache_method :length2

        def length
            sqrt(length2)
        end
        cache_method :length

        def tip
            origin + delta
        end
        cache_method :tip

        def piecewise_intercepts(v)
            v.to_vector.xy.map_with_index do |c, i|
                (c - origin[i]) / delta[i]
            end
        end

        def perpendicular_intercept(v)
            (v - origin).dot(delta)/length2
        end

        def point(p)
            origin + p*delta
        end

        def segment(p1, p2)
            self.class.new(point(p1), delta * (p2-p1))
        end

        def [](p1, p2=nil)
            if p2
                segment(p1, p2)
            else
                point(p1)
            end
        end

        def transform(trans)
            self.class.new(trans * origin, trans * delta)
        end
    end

    class View
        include Transformable

        attr :matrix

        def initialize(trans)
            @matrix = Plot.transform(trans)
        end

        def diagonal
            matrix.column(0) + matrix.column(1)
        end

        def lower
            matrix.column(2)
        end

        def upper
            lower + diagonal
        end

        def corners
            [lower,
             lower + matrix.column(0),
             upper,
             lower + matrix.column(1)
            ].freeze
        end

        def intercepts(line)
            l = line.piecewise_intercepts(lower)
            u = line.piecewise_intercepts(upper)
            if l.none?(&:nan?) && u.none?(&:nan?)
                rx = [l.x, u.x].sort
                ry = [l.y, u.y].sort
                if rx[0] <= ry[1] && ry[0] <= rx[1]
                    return [rx[0], ry[0]].max, [rx[1], ry[1]].min
                end
            end
        end

        def clip(line)
            if (p1, p2 = intercepts(line))
                p1 = p1.clamp(0, 1)
                p2 = p2.clamp(0, 1)
                if p1 != p2
                    line.segment(p1.min(p2), p1.max(p2))
                end
            end
        end

        def transform(trans)
            self.class.new(trans * matrix)
        end
    end

    class Box
        include Transformable

        attr :lower, :upper, :bounds

        def initialize(lower, upper)
            @lower = lower
            @upper = upper
            @bounds = [lower, upper]
        end

        class << self
            def between(a, b)
                new(a.lower(b), a.upper(b))
            end
        end

        def size
            upper - lower
        end
        cache_method :size

        def corners
            [lower,
             Vector[lower.x, upper.y, 1],
             upper,
             Vector[upper.x, lower.y, 1],
            ].freeze
        end
        cache_method :corners

        def intercepts(line)
            l = line.piecewise_intercepts(lower)
            u = line.piecewise_intercepts(upper)
            if l.none?(&:nan?) && u.none?(&:nan?)
                rx = [l.x, u.x].sort
                ry = [l.y, u.y].sort
                if rx[0] <= ry[1] && ry[0] <= rx[1]
                    return [rx[0], ry[0]].max, [rx[1], ry[1]].min
                end
            end
        end

        def clip(line)
            if (p1, p2 = intercepts(line))
                p1 = p1.clamp(0, 1)
                p2 = p2.clamp(0, 1)
                if p1 != p2
                    line.segment(p1.min(p2), p1.max(p2))
                end
            end
        end

        def transform(trans)
            trans[0,1].zero? && trans[1,0].zero? or raise ArgumentError, "Cannot rotate a #{self.class}"
            self.class.new(trans * lower, trans * upper)
        end
    end

    class Builder
        attr :parent, :domain, :function

        def initialize(parent, domain, scale, function: nil)
            @parent = parent
            @domain = domain
            @scale = scale
            @function = function
        end

        def to_svg
            parent.to_svg
        end

        def i
            Complex::I
        end

        def center
            (domain[0] + domain[1]) / 2
        end

        def range
            (domain[1] - domain[0]) / 2
        end

        def bounds
            Box.between(*domain.map{|c| vec(c) })
        end

        def lower
            bounds.lower
        end

        def upper
            bounds.upper
        end

        def size
            bounds.size
        end

        def radius
            [range.real, range.imag].max
        end

        cache_method :center, :range, :bounds, :lower, :upper, :size

        delegate :vec, to: Plot

        def pos(v)
            if function
                vec(function[v.to_c])
            else
                vec(v)
            end
        end

        def px(n=1)
            (n/@scale).to_f
        end

        def rot(n)
            E**(I*TAU*n)
        end

        def rgb(r, g, b, a=1)
            "rgba(#{[r,g,b].map{|c| (c.to_f*255).round }.join(',')},#{a.to_f})"
        end

        def hsl(h, s=1, l=0, a=1)
            h = h % TAU
            s = s * (1-l.abs)
            s0 = 1-s
            l = ((l+1)/2).to_f
            t = TAU/3
            rgb(*(case h
                when 0...t
                    [t-h, h, 0]
                when t...2*t
                    [0, 2*t-h, h-t]
                else
                    [h-2*t, 0, TAU-h]
            end.map{|c| s*c/t + s0*l }), a)
        end

        def visible?(v)
            v = vec(v)
            lower.x <= v.x && v.x <= upper.x && lower.y <= v.y && v.y <= upper.y
        end

        def draw(thing, **opts)
            thing.is_a? Drawable or raise ArgumentError, "Don't know to draw a #{thing.class}"
            if opts.empty?
                thing.draw(self)
            else
                style **opts do
                    thing.draw(self)
                end
            end
        end

        def group(**opts, &block)
            g = self.class.new(@parent.group(**opts), @domain, @scale)
            g.instance_eval(&block)
            g
        end

        def style(**opts, &block)
            parent.push_defaults(**opts)
            instance_eval(&block)
        ensure
            parent.pop_defaults
        end

        def transform(trans = nil, &block)
            if block
                group(&block).transform(trans)
            else
                trans = Plot.transform(trans)
                parent.matrix(*3.times.flat_map{|i| trans.column(i).xy.to_a.map(&:to_f) })
            end
        end

        def translate(delta, &block)
            transform(Plot.translate(delta), &block)
        end

        def scale(s, &block)
            transform(Plot.scale(s), &block)
        end

        def rotate(r, &block)
            transform(Plot.rotate(r), &block)
        end

        def text(p, words, anchor: 'inherit', vanchor: 'inherit', **opts)
            parent.text(0, 0, :'text-anchor' => anchor, :'alignment-baseline' => vanchor, **opts){ raw words }
                .translate(*vec(p).xy)
                .scale(px, -px)
        end

        def circle(center, radius, **opts)
            parent.circle(*vec(center).xy, radius.to_f, **opts)
        end

        def dots(pos, radius=nil, **opts)
            pos.each do |v|
                # break unless visible? v
                dot(v, radius, **opts)
            end
        end

        def dot(pos, radius=nil, label: nil, **opts)
            radius ||= label ? px(15) : px(5)
            circle(vec(pos), radius, **opts)

            if label
                label = label[pos] if label.is_a? Proc
                label = label.to_s
                translate pos do
                    scale 0.7 do
                        text(0, label, anchor: 'middle', vanchor: 'central', fill: 'white')
                    end
                end
            end
        end

        def rect(a, b=nil, radius: nil, **opts)
            c = if a.is_a?(Box) && b.nil?
                a
            else
                Box.between(vec(a), vec(b))
            end
            parent.rect(*c.lower.xy, *c.size.xy, *(vec(radius).xy if radius), **opts)
        end

        def seg(a, d=nil, to: nil, arrow: false, **opts)
            full = Plot.line(a, d, to: to)
            if line = bounds.clip(full)
                a = line.origin.xy
                b = line.tip.xy
                if arrow && line.tip == full.tip
                    u = (full.delta.xy / full.length) * px(3)
                    v = Vector[u.y, -u.x]
                    parent.line(*a, *(b - 3*u), **opts)
                    arrow_opts = opts.merge(:'stroke-width' => 0)
                    arrow_opts[:fill] = arrow_opts.delete(:stroke) || parent.merge_defaults[:stroke]
                    parent.path **arrow_opts do
                        moveToA *b
                        lineTo *(-3*u+v)
                        lineTo *(-2*v)
                        close
                    end
                else
                    parent.line(*a, *b, **opts)
                end
                line
            end
        end

        def arrow(a, d=nil, to: nil, **opts)
            seg(a, d, to: to, arrow: true, **opts)
        end

        def ray(a, d=nil, to: nil, **opts)
            line = Plot.line(a, d, to: to)
            if (p1, p2 = bounds.intercepts(line))
                p1 = p1.max(0)
                p2 = p2.max(0)
                if p1 != p2
                    parent.line(*line[p1].xy, *line[p2].xy, **opts)
                    line
                end
            end
        end

        def line(a, d=nil, to: nil, **opts)
            line = Plot.line(a, d, to: to)
            if (p1, p2 = bounds.intercepts(line))
                parent.line(*line[p1].xy, *line[p2].xy, **opts)
                line
            end
        end

        def rule(a, d=nil, to: nil, ticks: true, **opts)
            style stroke: '#ccc' do
                line = Plot.line(a, d, to: to)
                line(line, **opts)

                if ticks && line.length >= px(5)
                    t = line.delta.normalize.turn(0) * px(5) # 1/2 height of a tick
                    pmin, pmax = bounds.corners.map{|c| line.perpendicular_intercept(c) }.minmax
                    (pmin.ceil .. pmax.floor).each do |p|
                        v = line[p]
                        seg(v-t, to: v+t, **opts)
                    end
                end
            end
        end

        def axes(pos=0, **opts)
            rule pos, 1, **opts
            rule pos, i, **opts
        end

        def grill(a, b=nil, to: nil, **opts)
            line = Plot.line(a, b, to: to)

            p = line.length / px
            if p < 5
                line = Line.new(line.origin, line.delta * (5/p).ceil)
            end

            pmin, pmax = bounds.corners.map{|c| line.perpendicular_intercept(c) }.minmax
            n = line.delta.turn(0)
            # puts "line = #{line}"
            # puts "a..b = #{a}...#{b}"
            (pmin.ceil .. pmax.floor).each do |p|
                v = line[p]
                line(v, n, **opts)
            end
        end

        def _curve(a, b, fa, fb, res, **opts, &f)
            d = (fa-fb).norm
            if d <= res
                parent.line(*fa.to_vector, *fb.to_vector, **opts)
                # seg(fa, to: fb, **opts)
            else
                c = (a+b)/2.0
                fc = f[c]
                _curve(a, c, fa, fc, res, **opts, &f)
                _curve(c, b, fc, fb, res, **opts, &f)
            end
        end

        def curve(a, b, **opts, &f)
            a = a.to_c
            b = b.to_c
            _curve(a, b, f[a], f[b], px(5)**2, **opts, &f)
        end

        def func(expr=nil, min: nil, center: nil, step: 1, count: 20, frames: 10, **opts, &block)
            block ||= Function[expr]
            min ||= (center || self.center) - count*step*(1+I)/2.0

            if block.arity >= 2
                anim = (0..1).step((1/frames).to_f)
                f = block
            else
                anim = [1]
                f = proc{|z, _| block[z] }
            end

            parent.linearGradient :realAxis do
                stop 0, '#f00', 1
                stop 0.5, 'black', 1
                stop 1, '#0f0', 1
            end

            [[step, step*I], [step*I, step]].each do |jstep, kstep|
                (0..count).each do |j|
                    z = min + j*jstep
                    parent.path fill: 'transparent',
                                stroke: (z.real? && kstep.real? ? 'url(#realAxis)' : 'black'),
                                stroke_width: px(1),
                                **parent.merge_defaults.merge(opts) do

                        frames = []
                        anim.each do |t|
                            fh = (-1..1).map do |k|
                                f[z + k*kstep, t].to_fvector
                            end # 4x vertices

                            th = [(fh[2] - fh[0]) / 6.0] # 2x estimated tangents
                            moves = ["M#{fh[1].x},#{fh[1].y}"]
                            # moveToA *fh[1]

                            (1..count+1).each do |k|
                                fh << f[z + k*kstep, t].to_fvector
                                th << (fh[3] - fh[1]) / 6.0

                                q1 = fh[1] + th[0]
                                q2 = fh[2] - th[1]
                                # curveToA *fh[2], *q1, *q2
                                # lineToA *fh[2]
                                moves << " L#{fh[2].x},#{fh[2].y}"

                                fh.shift
                                th.shift
                            end

                            frames << moves.join(' ')
                        end
                        animate attributeName: 'd', begin: '1s', dur: '5s', Fill: 'freeze', values: frames.join(';')
                    end
                end
            end
        end

        def method_missing(meth, *args, &block)
            parent.__send__(meth, *args, &block)
        end
    end

    class << self
        def complex(size: Vector[960, 600], range: 2, center: 0, left: nil, min: nil, background: nil, &block)
            if size.is_a? Numeric
                size = Vector[size, size]
            elsif size.is_a? Array
                size = Vector[*size]
            end
            size_min = size.x.min(size.y)

            scale = size_min/(2*range)
            range = (range*size.x + range*size.y*Complex::I)/size_min
            if left
                center = left + range.real
            elsif min
                center = min + range
            end
            domain = [center-range, center+range]
            scale = scale.to_f

            img = Rasem::SVGImage.new(width: size.x, height: size.y)
            background and img.rect(0, 0, *size, stroke: '', fill: background)
            group = img.group
                .translate(size.x/2.0, size.y/2.0)
                .scale(scale, -scale)
                .translate(-center.real.to_f, -center.imag.to_f)
            group.push_defaults(stroke_width: 1/scale)

            builder = Builder.new(group, domain, scale)
            builder.instance_eval(&block) if block

            img
        end

        def image(size: Vector[1920, 1200], aa: 1, range: 2, center: 0, &block)
            if size.is_a? Array
                size = Vector[*size]
            elsif !size.is_a? Vector
                size = Vector[size, size]
            end

            png = ChunkyPNG::Image.new(size.x, size.y)
            samp = size*aa
            scale = (2*range/[samp.x, samp.y].min).to_f
            tl = center - (samp.x-1)*scale/2 + I*(samp.y-1)*scale/2

            f = proc do |x, y|
                block[tl + x*scale - y*scale*I]
            end

            if aa == 1
                (0...size.y).each do |py|
                    (0...size.x).each do |px|
                        png[px, py] = f[px, py]
                    end
                end
            else
                aa2 = aa**2
                (0...size.y).each do |py|
                    (0...size.x).each do |px|
                        r = g = b = 0
                        (py*aa...(py+1)*aa).each do |y|
                            (px*aa...(px+1)*aa).each do |x|
                                v = f[x, y]
                                r += ChunkyPNG::Color.r(v)
                                g += ChunkyPNG::Color.g(v)
                                b += ChunkyPNG::Color.b(v)
                            end
                        end
                        png[px, py] = ChunkyPNG::Color.rgb(r.div(aa2), g.div(aa2), b.div(aa2))
                    end
                end
            end

            png
        end

        def map(step: 1, **opts, &block)
            image(**opts) do |z|
                v = block[z]
                (((v.real/step).floor & 1) ^ ((v.imag/step).floor & 1)).even? ? ChunkyPNG::Color::BLACK : ChunkyPNG::Color::WHITE
            end
        end

        def set(**opts, &block)
            image(**opts) do |z|
                block[z] ? ChunkyPNG::Color::BLACK : ChunkyPNG::Color::WHITE
            end
        end

        def scalar(**opts, &block)
            image(**opts) do |z|
                s = (block[z]*255).round
                ChunkyPNG::Color.rgb(s,s,s)
            end
        end
    end
end

module Rasem
    class SVGTag
        forward :to_svg, :to_s

        def validate_tag(tag)
            tag.to_sym
        end

        def validate_attribute(attribute)
            attribute.to_sym
        end

        def tag(name, attrs={}, &body)
            append_child Rasem::SVGTagWithParent.new(@img, name, attrs, &body)
        end

        def animate(id=nil, **attrs, &body)
            attrs = attrs.merge(:'xlink:href' => "##{id}") if id
            attrs = attrs.mash do |k, v|
                [k, if v.is_a? Enumerable
                    v.map(&:to_s).join(';')
                else
                    v
                end]
            end
            tag(:animate, attrs, &body)
        end
    end
end

module ChunkyPNG
    module Color
        def to_rgb(c)
            [r(c), g(c), b(c)]
        end
    end

    module Chunk
        class Structured < Base
            class << self
                def define(type, **attrs)
                    attr_accessor *attrs.keys

                    define_singleton_method :read do |_, content|
                        new(type, **attrs.keys.zip(content.unpack(attrs.values.join)).mash)
                    end

                    define_method :content do
                        attrs.keys.map{|k| __send__(k) }.pack(attrs.values.join)
                    end

                    CHUNK_TYPES[type] = self
                end
            end
        end

        # 0   num_frames     (unsigned int)    Number of frames
        # 4   num_plays      (unsigned int)    Number of times to loop this APNG.  0 indicates infinite looping.
        class AnimationControl < Structured
            define 'acTL',
                   num_frames: 'N',
                   num_plays: 'N'
        end

        #  0    sequence_number       (unsigned int)   Sequence number of the animation chunk, starting from 0
        #  4    width                 (unsigned int)   Width of the following frame
        #  8    height                (unsigned int)   Height of the following frame
        # 12    x_offset              (unsigned int)   X position at which to render the following frame
        # 16    y_offset              (unsigned int)   Y position at which to render the following frame
        # 20    delay_num             (unsigned short) Frame delay fraction numerator
        # 22    delay_den             (unsigned short) Frame delay fraction denominator
        # 24    dispose_op            (byte)           Type of frame area disposal to be done after rendering this frame
        # 25    blend_op              (byte)           Type of frame area rendering for this frame
        class FrameControl < Structured
            define 'fcTL',
                   sequence_number: 'N',
                   width: 'N', height: 'N',
                   x_offset: 'N', y_offset: 'N',
                   delay_num: 'n', delay_den: 'n',
                   dispose_op: 'C', blend_op: 'C'
        end

        class FrameData < ImageData
            attr_accessor :sequence_number

            def self.read(type, content)
                sequence_number, content = content.unpack('Na*')
                chunk = super(type, content)
                chunk.sequence_number = sequence_number
                chunk
            end

            def content
                [sequence_number, super].pack('Na*')
            end

            CHUNK_TYPES['fdAT'] = self
        end
    end

    class Frame < Image
        attr_accessor :delay, :offset

        def initialize(width, height, bg_color = ChunkyPNG::Color::TRANSPARENT, metadata = {})
            super(width, height, bg_color)
            @metadata = metadata
        end
    end

    class Animation
        attr_accessor :frames, :num_plays

        def initialize(frames: [], num_plays: 0)
            @frames = frames
            @num_plays = num_plays
        end

        def to_datastream
            ds = frames[0].to_datastream

            actl = Chunk::AnimationControl.new(num_frames: frames.size, num_plays: num_plays)
            ds.other_chunks = [actl, *ds.other_chunks]

            dc = []
            frames.each_with_index do |frame, n|
                fctl = Chunk::FrameControl.new(
                    sequence_number: n,
                    width: frame.width, height: frame.height,
                    x_offset: 0, y_offset: 0,

                )
            end

            ds
        end
    end
end

if defined? IRuby::Display
    IRuby::Display::Registry.class_eval do
        type { ChunkyPNG::Image }
        format('text/html') do |img|
            %{<img width="#{(img.width/2).to_i}" height="#{(img.height/2).to_i}" src="data:image/png;base64,#{Base64.strict_encode64(img.to_blob)}"/>}
            # img.to_blob
        end
        # format('image/png') do |img|
        #     img.to_blob
        # end
    end
end
