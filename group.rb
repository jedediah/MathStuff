require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/enumerable'
require 'set'

require_relative 'coercible'
require_relative 'math'
require_relative 'transfinite'
require_relative 'set'
require_relative 'permutation'
require_relative 'transform'
require_relative 'word'

module Algebra
    class Error < Exception
        class << self
            def closure(a, b, ab)
                new "Closure violation: #{a} * #{b} = #{ab} which is not in the group"
            end

            def identity_unknown
                new "Cannot search infinite group for identity element"
            end

            def identity_missing
                new "Cannot find an identity element"
            end

            def identity_broken(e, a, b, ab)
                new "Identity element #{e} is broken: #{a} * #{b} = #{ab}"
            end

            def inverse_missing(a)
                new "Cannot find an inverse for #{a}"
            end

            def inverse_doesnt_commute(e, a, b, ba)
                new "#{a} does not commute with its inverse #{b}: #{a} * #{b} = #{e} but #{b} * #{a} = #{ba}"
            end

            def multiple_inverses(a, i1, i2)
                new "Found multiple inverses for #{a}: #{i1} and #{i2}"
            end

            def associativity(a, b, c, ab_c, a_bc)
                new "Associativity violation: (#{a} * #{b}) * #{c} = #{ab_c} but #{a} * (#{b} * #{c}) = #{a_bc}"
            end
        end
    end

    class Element
        include Multiplicable
        include Latex::Inspectable

        attr :group, :value

        def initialize(group, value)
            @group = group
            @value = value
        end

        delegate :inspect, :inspect_latex, to: :value

        def hash
            [group, value].hash
        end

        def ==(x)
            if x.is_a?(Element)
                value == x.value
            else
                value == x
            end
        end
        alias_method :eql?, :==

        def <=>(x)
            if x.is_a?(Element)
                value <=> x.value
            else
                value <=> x
            end
        end

        def sort_key
            value.send_or(:sort_key) do
                [Element.hash, group.hash, group.index_of(self)]
            end
        end

        def one?
            self == group.identity
        end

        def reciprocal
            group.invert(self)
        end

        def can_mul?(x)
            if x.is_a? Element
                group == x.group
            elsif x.is_a? ElementSet
                group == x
            end
        end

        def _wrap(x)
            self.class.new(group, x)
        end

        def mul(b)
            if b.is_a? Element
                _wrap(group.mul(self, b))
            elsif b.is_a? ElementSet
                b._subset(b.elements.map{|b| mul(b) })
            end
        end

        def pow(n)
            _wrap(group.pow(self, n))
        end
    end

    module Structure
        extend ActiveSupport::Concern

        include Coercible
        extend Coercible::Macros
        include Latex::Inspectable

        def structure_name
            ''
        end

        def inspect
            "#{structure_name}{#{elements.map(&:inspect).join(', ')}}"
        end

        def inspect_latex
            "#{structure_name}\\{#{elements.map(&:inspect_latex).join(', ')}\\}"
        end

        def hash
            elements.hash
        end

        def ==(h)
            h.is_a?(Structure) && elements == h.elements &&
                elements.all?{|a| elements.all?{|b| op(a, b) == h.op(a, b) } }
        end
        forward :eql?, :==

        def order
            elements.size
        end

        def op(a, b)
            a * b
        end

        def operation
            method :op
        end

        def exp(a, n)
            binary_pow(a, n, identity, &operation)
        end

        def map(&f)
            Explicit.new(elements.map(&f), &operation)
        end

        def *(b)
            map{|a| op(a, b) }
        end

        right :* do |a|
            map{|b| op(a, b) }
        end

        def _find_identity
            if @has_identity.nil?
                size.finite? or raise Error.identity_unknown
                @identity = find do |a|
                    all? do |b|
                        op(a, b) == b && op(b, a) == b
                    end
                end
                @has_identity = !@identity.nil?
                extend Magma if @has_identity
            end
            @identity
        end

        def identity
            _find_identity or raise Error.identity_missing
        end

        def has_identity?
            if @has_identity.nil?
                _find_identity if size.finite?
            else
                @has_identity
            end
        end

        def group?
            false # TODO
        end
    end

    module Magma
        extend ActiveSupport::Concern
        include Structure

        attr :identity

        # def structure_name
        #     'Magma'
        # end
    end

    module Group
        extend ActiveSupport::Concern
        include Magma
        extend Coercible::Macros

        def group?
            true
        end

        # def structure_name
        #     'Group'
        # end

        def conjugate(a, g)
            op(g, op(a, invert(g)))
        end

        def *(b)
            if b.is_a?(Structure) && b.group?
                Product.new(self, b)
            else
                super
            end
        end

        right :* do |a|
            if a.is_a?(Structure) && a.group?
                Product.new(a, self)
            else
                super(a)
            end
        end

        def product(*groups)
            Product.new(self, *groups)
        end

        def index_of(el)
            if el == identity
                0
            else
                1 #TODO
            end
        end

        def commutative?
            elements.to_a.combination.all? do |a, b|
                operation[a, b] == operation[b, a]
            end
        end
        cache_method :commutative?
        forward :abelian?, :commutative?

        def inverses
            Hash.new do |m, a|
                e = identity
                elements.find do |b|
                    ab = op(a, b)
                    if ab == e
                        m[a] = b
                        m[b] = a
                        b
                    end
                end or raise Error.inverse_missing(a)
            end
        end
        cache_method :inverses

        def invert(el)
            inverses[el]
        end

        def orders
            Hash.new do |m, el|
                if include? el
                    a = el
                    n = 1
                    until a == identity
                        a = op(a, el)
                        n += 1
                    end
                    m[el] = n
                end
            end
        end
        cache_method :orders

        def verify
            e = identity
            inverses = {e => e}
            commutative = true

            elements.to_a.combination(2) do |a, b|
                ab = operation[a, b]
                ba = operation[b, a]

                if ab == ba
                    if ab == e
                        inverses.key?(a) and raise Error.multiple_inverses(a, inverses[a], b)
                        inverses.key?(b) and raise Error.multiple_inverses(b, inverses[b], a)
                        inverses[a] = b
                        inverses[b] = a
                    end
                else
                    commutative = false
                    ab == e and raise Error.inverse_doesnt_commute(e, a, b, ba)
                    ba == e and raise Error.inverse_doesnt_commute(e, b, a, ab)
                end

                [[a, b, ab], [b, a, ba]].each do |x, y, xy|
                    include? xy or raise Error.closure(x, y, xy)

                    elements.each do |z|
                        xy_z = operation[xy, z]
                        x_yz = operation[x, operation[y, z]]
                        xy_z == x_yz or raise Error.associativity(x, y, z, xy_z, x_yz)
                    end
                end
            end

            (elements - inverses.keys).each do |a|
                if operation[a, a] == e
                    inverses[a] = a
                end
            end

            unless inverses.size == elements.size
                raise Error.inverse_missing(elements.find{|el| !inverses.key? el })
            end

            __set_inverses(inverses.freeze)
            __set_commutative?(commutative)
            nil
        end

        def cycles
            e = identity
            cycles = {}
            elements.without(e).each do |gen|
                x = gen
                cycle = [e]
                until x == e
                    cycle << x
                    x = operation[x, gen]
                end
                cycles.each do |old_gen, old_cycle|
                    if old_cycle.all?{|y| cycle.include? y }
                        # New cycle is superset of old cycle
                        if cycle.size > old_cycle.size || (gen <=> old_gen) < 0
                            # New cycle is longer than old cycle OR has a generator with a lower sort_key
                            cycles.delete(old_gen)
                        else
                            # Old cycle is same size as new cycle AND has a generator with a lower sort_key
                            cycle = nil
                            break
                        end
                    elsif cycle.all?{|y| old_cycle.include? y }
                        # Old cycle is proper superset of new cycle
                        cycle = nil
                        break
                    end
                end
                cycles[gen] = cycle unless cycle.nil?
            end
            SortedSet.new(cycles.values)
        end
        cache_method :cycles

        def homomorphism?(g, &f)
            elements.all? do |a|
                elements.all? do |b|
                    f[operation[a, b]] == g.operation[f[a], f[b]]
                end
            end
        end

        def cayley_table(max_size=16)
            max_size.finite? or raise ArgumentError, "Cannot generate table with infinite size #{max_size}"

            group = self
            els = []
            if max_size > 0
                els << identity
                if max_size > 1
                    elements.each do |el|
                        unless el == identity
                            els << el
                            break if els.size >= max_size
                        end
                    end
                end
            end

            max_size = max_size.min(els.size)

            Latex::Inspectable.create do
                Latex.table(max_size, max_size) do |i, j|
                    group.operation[els[i], els[j]].inspect_latex
                end
            end
        end

        def conjugacy_classes
            elements.divide do |a, b|
                elements.any? do |g|
                    conjugate(a, g) == b
                end
            end
        end

        def minimal_generating_sets
            gsets = Set[]
            (1..order).each do |n|
                elements.without(identity).combination(n) do |generators|
                    els = Set[identity]
                    gens = generators.dup
                    until gens.empty?
                        generated = []
                        gens.each do |a|
                            els.each do |b|
                                ab = op(a, b)
                                generated << ab unless els.include?(ab)
                            end
                        end
                        els.merge(generated)
                        gens = generated
                    end

                    if els.size == elements.size
                        gsets << Set.new(generators)
                    end
                end
                return gsets unless gsets.empty?
            end
        end

        def subgroup?(g)
            g.is_a?(Structure) && g.group? && elements.subset?(g.elements) && order.divides?(g.order) &&
                elements.all?{|a| elements.all?{|b| op(a, b) == g.op(a, b) } }
        end

        def _assert_subgroup(g)
            subgroup?(g) or raise "#{inspect} is not a subgroup of #{g.inspect}"
        end

        def _normal_in?(g)
            (g.elements - elements).all? do |a|
                l = Set[]
                r = Set[]
                elements.each do |b|
                    l << g.op(a, b)
                    r << op(b, a)
                end
                l == r
            end
        end

        def normal_subgroup?(g)
            subgroup?(g) and _normal_in?(g)
        end

        def _make_subgroup(els)
            Explicit.group(els, identity: identity, &operation)
        end

        def subgroups
            oo = order
            sgs = Set[_make_subgroup(Set[identity]), self]

            if respond_to? :generators
                generators.each do |g|
                    sgs << Generated.new(g, identity: identity, &operation)
                end
            end

            subels = Set[]
            elements.each do |x|
                subels << x unless x == identity || subels.include?(invert(x))
            end

            (1...subels.size).each do |suborder|
                if suborder.divides?(oo)
                    subels.combination(suborder) do |els|
                        sg = Set[identity, *els, *els.map{|x| invert(x) }]
                        if sg.product(sg).all?{|a, b| sg.include? op(a, b) }
                            sgs << _make_subgroup(sg)
                        end
                    end
                end
            end

            sgs
        end

        def normal_subgroups
            subgroups.select{|h| h._normal_in? self }
        end

        def left_cosets(g)
            [self, *(g.elements - elements).map{|x| x*self }].to_set
        end

        def /(h)
            h._assert_subgroup(self)

            reps = {h => identity}
            cosets = {identity => h}
            (elements - h.elements).each do |a|
                coset = a*h
                unless reps.key? coset
                    reps[coset] = a
                    cosets[a] = coset
                end
            end
            Explicit.group(reps.keys, identity: h) do |a, b|
                cosets[op(reps[a], reps[b])]
            end
        end

        GRAPH_COLORS = ['#049', '#094', '#096', '#906']

        def cayley_graph(gens=nil, size: Vector[200, 200])
            group = self
            elements = self.elements.to_a
            dx = size[0]/2
            dy = size[1]/2
            o = order
            gens ||= generators

            nodes = elements.zip_index.mash do |(el, i)|
                [el, Vector[dx * 0.8 * cos(TAU * i / o),
                            dy * 0.8 * sin(TAU * i / o)]]
            end

            links = {}
            gens.each do |gen|
                l = links[gen] = {uni: {}, bi: {}}
                elements.each do |a|
                    b = group.op(a, gen)
                    if l[:uni][b] == a
                        l[:uni].delete(b)
                        l[:bi][b] = a
                    else
                        l[:uni][a] = b
                    end
                end
            end

            Rubyvis::Panel.new do
                width dx
                height dy
                left dx
                bottom dy

                links.each_with_index do |(gen, l), i|
                    [:uni, :bi].each do |type|
                        l[type].each do |a, b|
                            line do
                                va = nodes[a]
                                vb = nodes[b]
                                color = GRAPH_COLORS[i % GRAPH_COLORS.size]

                                data [va, vb]
                                stroke_style color
                                left{|v| v[0] }
                                bottom{|v| v[1] }

                                if type == :uni
                                    dot do
                                        vc = (va + vb) / 2
                                        left vc[0]
                                        bottom vc[1]
                                        shape 'triangle'
                                        shape_angle vc.angle_with(-Vector[1,0])
                                        shape_radius 3.5
                                        fill_style color
                                        stroke_style nil

                                        # anchor('center').label do
                                        #     text gen.inspect
                                        #     text_style 'white'
                                        #     font_size '7px'
                                        # end
                                    end
                                end
                            end
                        end
                    end
                end

                dot do
                    data elements
                    left{|el| nodes[el][0] }
                    bottom{|el| nodes[el][1] }
                    shape 'circle'
                    shape_radius 10
                    fill_style{|el| el.one? ? '#999' : '#555' }
                    stroke_style nil

                    anchor('center').label do
                        text{|el| el.inspect }
                        text_style 'white'
                    end
                end
            end
        end
    end

    class Explicit
        include Structure

        attr :elements, :operation

        def initialize(elements, identity: nil, &operation)
            @elements = elements.to_set.freeze
            @operation = operation || proc{|a, b| a * b }

            if identity
                @identity = identity
                extend Magma
            end
        end

        def self.group(els, identity: nil, &op)
            g = new(els, identity: identity, &op)
            g.extend Group
            g
        end

        def op(a, b)
            operation[a, b]
        end
    end

    class Trivial < Explicit
        include Group

        def initialize
            super(Set[Word.one], identity: Word.one) {|a, b| a * b }
        end

        class << self
            def new
                @instance ||= super
            end
        end
    end

    class Product < Explicit
        attr :factors

        def initialize(*factors)
            @factors = factors

            els = Set.product(*factors.map(&:elements)) do |*t|
                Element.new(self, t)
            end

            id = Element.new(self, factors.map(&:identity))

            super(els, identity: id) do |a, b|
                Element.new(self, factors.map_with_index{|f, i| f.op(a[i], b[i]) })
            end
        end


        def inspect
            factors.map(&:inspect).join('×')
        end

        def inspect_latex
            factors.map(&:inspect_latex).join(' \\times ')
        end

        class << self
            def new(*factors)
                case factors.size
                    when 0
                        Trivial.new
                    when 1
                        factors[0]
                    else
                        super
                end
            end
        end

        class Element < Algebra::Element
            include Enumerable

            def initialize(group, tuple)
                super(group, tuple)
                @tuple = tuple
            end

            def each(&b)
                @tuple.each(&b)
            end

            def [](i)
                @tuple[i]
            end

            def <=>(x)
                zip(x).each do |a, b|
                    n = (a <=> b)
                    return n unless n == 0
                end
                0
            end

            forward :to_s, :inspect

            def inspect
                "(#{@tuple.map(&:inspect).join(', ')})"
            end

            def inspect_latex
                Latex.tuple(@tuple.map{|x| Latex.render(x) })
            end

            def sort_key
                [Element.hash, group.hash, @tuple.map(&:sort_key)]
            end

            def reciprocal
                _wrap(group.factors.map_with_index{|f, i| f.invert(self[i]) })
            end
        end
    end

    class Generated < Explicit
        include Group

        attr :generators

        def initialize(*generators, identity: nil, &operation)
            @generators = SortedSet.new(generators)
            elements = SortedSet.new(generators)

            until generators.empty?
                generated = []
                generators.each do |a|
                    elements.each do |b|
                        ab = operation[a, b]
                        if elements.include?(ab)
                            if a == ab
                                identity = b
                            elsif b == ab
                                identity = a
                            end
                        else
                            generated << ab
                        end
                    end
                end
                elements.merge(generated)
                generators = generated
            end

            super(elements, identity: identity, &operation)
        end

        def inspect_latex
            "\\langle #{generators.map(&:inspect_latex).join(', ')} \\rangle"
        end
    end

    class Presented < Explicit
        include Group

        attr :generators, :relations, :rewrite_system

        def initialize(generators, *relations)
            @rewrite_system = Word::RewriteSystem.new(*relations)
            @relations = @rewrite_system.relations

            orders = {}
            generators.each do |g|
                # puts "Calculating order of generator #{g}"
                x = g
                o = 1
                until x.one?
                    x = @rewrite_system[x * g]
                    o += 1
                    raise "FUCK" if o >= 20
                end
                orders[g] = o
            end

            @rewrite_system = @rewrite_system.merge(generators.mash{|g| [g**-1, g**(orders[g]-1)] })

            @generators = SortedSet.new(generators)
            elements = SortedSet.new([Word.one, *generators])

            # return

            bail = 0
            until generators.empty?
                generated = []
                generators.each do |a|
                    # puts "Generating elements from #{a}"
                    elements.each do |b|
                        bail += 1
                        bail >= 10000 and raise "FUCK"

                        ab = @rewrite_system[a * b]
                        # puts "  #{a} * #{b} = #{ab}"
                        unless elements.include?(ab)
                            # puts "Adding #{ab.inspect}"
                            generated << ab
                        end
                    end
                end
                elements.merge(generated)
                generators = generated
            end

            super(elements, identity: Word.one) {|a, b| rewrite_system[a * b] }
        end

        def inspect_latex
            "\\langle #{generators.map(&:inspect_latex).join(', ')} \\mid #{relations.map{|a, b| b.one? ? a.inspect_latex : "#{a.inspect_latex} = #{b.inspect_latex}" }.join(', ')} \\rangle"
        end
    end

    class Standard < Explicit
        include Group

        attr :symbol, :index

        def initialize(symbol, index, identity, elements, &operation)
            super(elements, identity: identity, &operation)
            @symbol = symbol
            @index = index
        end

        def inspect
            "#{symbol}[#{index}]"
        end

        def inspect_latex
            "#{symbol}_#{index}"
        end
    end

    class Cyclic < Standard
        def initialize(n)
            n >= 1 or raise ArgumentError, "Cyclic group order must be >= 1"

            super('C', n, 0, 0...n) {|a, b| (a + b) % n }
        end
    end

    class Symmetric < Standard
        def initialize(n)
            n >= 1 or raise ArgumentError, "Symmetric group index must be >= 1"

            els = (1..n).to_a.permutation.map do |ii|
                Permutation.preimage(*ii)
            end
            super('S', n, Permutation.one, els) {|a, b| a * b }
        end
    end

    class Dihedral < Standard
        def initialize(n)
            n >= 1 or raise ArgumentError, "Dihedral group index must be >= 1"

            r = Transform.rotation(1/n)
            f = Transform.reflection(0)
            super('D', n, Transform.identity, [*n.times.map{|k| r**k }, *n.times.map{|k| f * r**k }])
        end
    end

    class << self
        def cyclic(n)
            Cyclic.new(n)
        end

        def symmetric(n)
            Symmetric.new(n)
        end

        def dihedral(n)
            Dihedral.new(n)
        end

        def generate(*generators, identity: nil, &operation)
            Generated.new(*generators, identity: identity, &operation)
        end

        def present(generators, *relations)
            Presented.new(generators, *relations)
        end

        def const_missing(name)
            if name =~ /^(C|S|D)(\d+)$/
                n = $2.to_i
                case $1
                    when 'C'
                        Cyclic.new(n)
                    when 'S'
                        Symmetric.new(n)
                    when 'D'
                        Dihedral.new(n)
                end
            else
                super
            end
        end
    end
end

