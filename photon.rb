require 'rubyvis'

require_relative 'iruby'
make_reloadable __FILE__

require_relative 'ext'
require_relative 'typeset'
require_relative 'unicode'
require_relative 'float'
require_relative 'math'
require_relative 'modular'
require_relative 'ring'
require_relative 'plot'
require_relative 'expr'
require_relative 'relation'
require_relative 'logic'
require_relative 'arith'
require_relative 'set'
require_relative 'transfinite'
require_relative 'ordinal'
require_relative 'constants'
require_relative 'word'
require_relative 'group'
require_relative 'polynomial'
require_relative 'hyperop'
require_relative 'continued_fraction'
require_relative 'padic'
require_relative 'real'
require_relative 'eisenstein'

require_relative 'gosu'

class Body
    attr_accessor :pos
    attr_accessor :mo

    def initialize(pos: Vector[0, 0], mo: Vector[0, 0, 0])
        self.pos = pos
        self.mo = mo
    end

    def update(dt)
        self.pos += dt*vel
    end

    def vel
        mo.spacelike / mo[0]
    end

    def energy
        mo[0]
    end
end

class MassiveBody < Body
    attr_accessor :mass

    def initialize(pos: Vector[0, 0], mo: Vector[0, 0, 0])
        super(pos: pos, mo: mo)
        self.mass = mo.lorentz_magnitude
    end

    # def initialize(pos: Vector[0, 0], vel: Vector[0, 0], mass: Float::INFINITY)
    #     super(pos: pos, mo: Vector.lorentz_momentum(mass: mass, velocity: vel))
    #     self.mass = mass
    # end
end

class Photon < Body
    RADIUS = 0.05

    # def initialize(pos: Vector[0, 0], mo: Vector[1, 0])
    #     super(pos: pos, mo: mo)
    #     # super(pos: pos, mo: Vector[(mo[0]**2 + mo[1]**2).sqrt, *mo])
    # end

    def vel=(v)
        self.mo = Vector[mo[0], *(mo[0]*v.normalize)]
    end

    def wavelength
        510.0 / mo[0] # TODO
    end

    def draw(view)
        view.circle(center: pos.map(&:to_f),
                    radius: RADIUS,
                    # color: Gosu::Color::YELLOW,
                    color: Gosu::Color.wavelength(wavelength),
                    segments: 48)
    end
end

class CenterOfMomentumTransform
    def initialize(p)
        psn2 = p.spacelike.norm2
        pn = p.lorentz_inner_product(p).sqrt
        @l00 = p[0] / pn
        @l01 = p[1] / pn
        @l02 = p[2] / pn
        gm1 = @l00 - 1
        @l11 = gm1*p[1]*p[1]/psn2 + 1
        @l22 = gm1*p[2]*p[2]/psn2 + 1
        @l12 = gm1*p[1]*p[2]/psn2

        # @p = p
        # @psn2 = @p.spacelike.norm2
        # @pn = (@p[0]*@p[0] - @psn2).sqrt
        # @p0mpn = @p[0] - @pn
    end

    def inspect
        "{[#{@l00} #{@l01} #{@l02}] [#{@l01} #{@l11} #{@l12}] [#{@l02} #{@l12} #{@l22}]"
    end

    def transform(d, u)
        # Vector[
        #     (@p[0]*u[0] + d*@p[1]*u[1] + d*@p[2]*u[2]) / @pn,
        #     u[1] + d*@p[1]*u[0]/@pn + (@p[1]*@p[1]*u[1] + @p[1]*@p[2]*u[2])*@p0mpn/@pn/@psn2,
        #     u[2] + d*@p[2]*u[0]/@pn + (@p[1]*@p[2]*u[1] + @p[2]*@p[2]*u[2])*@p0mpn/@pn/@psn2
        # ]
        Vector[
            @l00*u[0] + d*@l01*u[1] + d*@l02*u[2],
            d*@l01*u[0] + @l11*u[1] + @l12*u[2],
            d*@l02*u[0] + @l12*u[1] + @l22*u[2]
        ]
    end

    def transform_in(u)
        transform(-1, u)
    end

    def transform_out(u)
        transform(1, u)
    end
end

class Box < MassiveBody
    attr_accessor :size

    def initialize(pos: Vector[0, 0], mo: Vector[0, 0, 0], size: Vector[1, 1])
        super(pos: pos, mo: mo)
        self.size = size
    end

    # def initialize(pos: Vector[0, 0], vel: Vector[0, 0], size: Vector[1, 1], mass: Float::INFINITY)
    #     super(pos: pos, vel: vel, mass: mass)
    #     self.size = size
    # end

    alias_method :minimum, :pos

    def maximum
        pos + size
    end

    def draw(view)
        margin = Vector[Photon::RADIUS, Photon::RADIUS]
        p = pos - margin
        s = size + 2*margin
        Gosu.draw_rect(p[0].to_f, p[1].to_f, s[0].to_f, s[1].to_f, Gosu::Color::argb(32,255,255,255))
    end

    def collide_photons(collisions:, colliders:, normal:)
        # energy_before = photons.reduce{|e, p| e + p[0] }
        normal_momentum = Vector[0, 0]
        collisions.each do |photon, normal|
            if normal
                normal_momentum += normal.dot(photon.mo.spacelike)
            end
        end

        colliders.each do |collider|
            p = collider.mo.spacelike
            collider.mo = Vector[
                collider.mo[0],
                *(p - 2 * p.dot(normal))
            ]
        end
    end

    def collide_photon6(photon:, normal:)
        com = CenterOfMomentumTransform.new(photon.mo + self.mo)

        u0 = com.transform_in(photon.mo)
        r0 = com.transform_in(self.mo)

        puts "Colliding in CoM frame #{com.inspect}: box=#{r0} photon=#{u0}"

        if normal[0] != 0
            u1 = Vector[u0[0], -u0[1], u0[2]]
            r1 = Vector[r0[0], -r0[1], r0[2]]
        else
            u1 = Vector[u0[0], u0[1], -u0[2]]
            r1 = Vector[r0[0], r0[1], -r0[2]]
        end

        photon.mo = com.transform_out(u1)
        self.mo = com.transform_out(r1)

        puts "Post-collision momenta: box=#{self.mo} photon=#{photon.mo}"
    end

    def collide_photon5(photon:, normal:)
        m = self.mass
        m2 = m**2
        v = self.vel
        v2 = v.norm2
        a = sqrt(1.0 - v2)
        gm = m/a

        uE = photon.mo[0]
        u = photon.mo.spacelike

        v0 = (m*v + a*u) / (m + a*uE)
        g0 = (uE + gm) / sqrt(m2 + 2.0*gm*(uE - u.dot(v)))

        l = Matrix.lorentz_transform_in(v0, g0)
        u0 = (l * photon.mo).spacelike
        r0 = (l * self.mo).spacelike

        pt = 2*normal.dot(u0)
        u1 = u0 - pt*normal
        r1 = r0 + pt*normal

        l = Matrix.lorentz_transform_out(v0, g0)
        photon.mo = l * Vector[u1.norm, *u1]
        self.mo = l * Vector[sqrt(r1.norm2 + m2), *r1]

        # puts "v0=#{v0} g0=#{g0} pt=#{pt}\n  u0=#{u0} u1=#{u1}\n  r0=#{r0} r1=#{r1}\n  box.mo=#{self.mo} photon.mo=#{photon.mo}"
    end

    def collide_photon4(photon:, normal:)
        v = self.vel
        v2 = v.norm**2
        g = sqrt(1-v2)
        m = self.mass
        m2 = m**2
        p = photon.mo.spacelike
        p2 = p**2

        p_ = (p2 - m2 + m2*v2/(1-v2)) / 2*(p + m*v/g)
        p_2 = p_**2
        v_ = sqrt(m2/p_2 + 1)

        a = Matrix.lorentz_transform_in(v_)
        p = (a*photon.mo).spacelike
        q = (a*self.mo).spacelike

        pt = normal.inner_product(p)
        qt = normal.inner_product(q)
        p += (qt - pt)
        q += (pt - qt)

        a = Matrix.lorentz_transform_out(v_)
        photon.mo = a*Vector[p.norm, *p]
        self.mo = a*Vector[q.norm, *q]
    end

    def collide_photon3(photon:, normal:)
        r = self.vel
        # r2 = r.norm2
        u = Matrix.lorentz_transform_in(r) * photon.mo

        # if r2 > 0
        #     g = 1.0/sqrt(1.0 - r2)
        #     gr = g*r
        #     l = ((g-1.0)/r2)*r.outer_product
        #
        #     u = u + l*u - gr*u.norm
        # end

        ut = normal.dot(u.spacelike)
        mu = mass+u[0]
        # st = (2.0*mu) / (mu**2 + ut**2)
        st = ut*mu / (ut**2 + mu)
        vt = ut - (mass*st) / sqrt(1 - st**2)
        v = u.spacelike + (ut - vt)*normal
        v = Vector[v.norm, *v]
        s = st*normal

        puts "r=#{r} n=#{normal} u=#{u} ut=#{ut} st=#{st} s=#{s} v=#{v} vt=#{vt}"

        # if r2 > 0
        #     v = v - l*v + gr*v.norm
        # end

        photon.mo = Matrix.lorentz_transform_out(r) * v
        self.vel = r.add_velocity(s)
    end

    def collide_photon2(photon:, normal:)
        u = normal.dot(photon.mo)
        r = normal.dot(self.vel)
        a = -1
        b = 1
        s = a - b*sqrt((2.0/mass)*(u.abs - a*u) + (r - a)**2)
        # s = -sqrt((4.0/mass)*u.abs + (r+1.0)**2.0) - 1.0
        v = u + mass*(r - s)

        photon.mo += (v - u)*normal
        self.vel += (s - r)*normal
    end

    def collide_photon(photon:, normal:)
        u = photon.vel
        v = self.vel
        v2 = v.norm2

        if v2 > 0
            a = sqrt(1.0 - v2)
            j = (1 - a) / v2

            uv = v.dot(u)
            up = (a*u + (j*uv - 1)*v) / (1 - uv)

            urp = up.reflect(normal)

            urpv = v.dot(urp)
            ur = (a*urp + (j*urpv + 1)*v) / (1 + urpv)
        else
            ur = u.reflect(normal)
        end

        puts "v=#{v} n=#{normal} a=#{a} j=#{j} v2=#{v2} u=#{u} uv=#{uv} up=#{up} urp=#{urp} urpv=#{urpv} ur=#{ur}"

        photon.vel = ur
    end
end

class View < Gosu::Window

    def initialize
        super(1280, 960)
        self.caption = "Photon Box"

        @time = 0
        @box = Box.new(pos: Vector[-1, -1], size: Vector[2, 2], mo: Vector[10, 0, 0])
        # @box = Box.new(pos: Vector[-1, -1], size: Vector[2, 2], vel: Vector[0,0], mass: 10)
        # @box = Box.new(pos: Vector[-10, -8], size: Vector[2, 2], vel: Vector[0.5, 0.4].normalize*0.3, mass: 100)

        @photons = [
            Photon.new(pos: @box.minimum + @box.size/2, mo: Vector[5, 3, 4]),
            Photon.new(pos: @box.minimum + @box.size/2, mo: Vector[5, -3, -4]),
        ]

        # momenta = 24.times.map do |i|
        #     Vector.polar(rand * TAU, 1)
        # end
        #
        # bias = momenta.reduce(&:+) / momenta.size
        # momenta.map!{|m| m - bias }
        #
        # @photons = momenta.map do |m|
        #     Photon.new(pos: @box.minimum + @box.size.map{|x| rand * x }, mo: m)
        # end
    end

    def update
        later = @time + (1 / 60)

        100.times do
            step = later - @time
            collision = nil

            @photons.each do |photon|
                2.times do |axis|
                    dv = photon.vel[axis] - @box.vel[axis]
                    next if dv == 0
                    dx = (dv < 0 ? @box.minimum[axis] : @box.maximum[axis]) - photon.pos[axis]
                    dt = dx / dv
                    if dt < step
                        step = dt
                        collision = [photon, Vector.delta(2, axis) * (dv < 0 ? 1 : -1)]
                    end
                end
            end

            puts @photons.inspect

            if step > 0
                @time += step
                @box.update(step)
                @photons.each do |photon|
                    photon.update(step)
                end
            end

            break unless collision

            p_photons = @photons.map(&:mo).reduce(:+)
            p_box = @box.mo
            p_total = p_photons + p_box
            # puts "P=(%.03f %.03f %.03f) P_box=(%.03f %.03f %.03f) P_photons=(%.03f %.03f %.03f)" % [*p_total, *p_box, *p_photons]
            puts "P=#{p_total.inspect} P_box=#{p_box.inspect} P_photons=#{p_photons.inspect}"

            @box.collide_photon6(photon: collision[0], normal: collision[1])
        end
    end

    def draw
        translate(width / 2, height / 2) do
            scale([width, height].min / 16) do
                @box.draw(self)
                @photons.each{|p| p.draw(self) }
            end
        end
    end

    def triangle(vertices:, color:)
        draw_triangle(vertices[0][0], vertices[0][1], color,
                      vertices[1][0], vertices[1][1], color,
                      vertices[2][0], vertices[2][1], color)
    end

    def circle(center:, radius:, color:, segments: 360)
        segments.times do |n|
            triangle(vertices: [center,
                                center + Vector.polar(TAU * n / segments, radius),
                                center + Vector.polar(TAU * (n + 1) / segments, radius)],
                     color: color)
        end
    end
end

unless interactive?
    View.new.show
end
