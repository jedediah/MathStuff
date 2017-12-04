require 'active_support'

require_relative 'latex'
require_relative 'proc'
require_relative 'coercible'

module Sett
    class Error < Exception
        class << self
            def infinite(size)
                new "Cannot do this to a set of infinite size #{size}"
            end

            def uncountable(size)
                new "Cannot do this to a set of uncountable size #{size}"
            end
        end
    end

    class << self
        def empty
            Empty.new
        end

        def generated(size=nil, &generator)
            Generated.new(size, &generator)
        end

        def union(sets)
            Union.new(sets)
        end

        def product(sets)
            Product.new(sets)
        end
        forward :direct_product, :product
        forward :cartesian_product, :product
    end

    module Base
        include Latex::Inspectable

        def inspect_latex
            if countable?
                els = if finite?
                    map{|x| Latex.render(x) }
                else
                    [*take(3).map(&:inspect_latex), '...']
                end
                Latex.set(els)
            else
                super
            end
        end

        def to_set
            self
        end

        def include?(x)
            raise NotImplementedError
        end
        forward :member?, :include?

        def size
            raise NotImplementedError
        end
        forward :count, :size

        def empty?
            size.zero?
        end

        def countable?
            size.finite? || size.cardinal_index.zero?
        end

        def finite?
            size.finite?
        end

        def infinite?
            size.infinite?
        end

        def transform(f=nil, &b)
            Mapped.new(self, Proc.unary(f, &b))
        end

        # def flat_map(f=nil, &b)
        #     Sett.union(map(f, &b))
        # end

        def filter(p=nil, &b)
            Filtered.new(self, Proc.predicate(p, &b))
        end

        # def reject(p=nil, &b)
        #     Filtered.new(self, ~Function.predicate(p, &b))
        # end

        # def grep(pattern)
        #     select{|x| x === pattern }
        # end

        def product(x)
            Sett.product([self, x])
        end
        forward :direct_product, :product
        forward :cartesian_product, :product
        forward :*, :product
    end

    module Countable
        include Base
        include Enumerable

        def to_a
            size.finite? or raise Error.infinite(size)

            a = []
            i = 0
            each do |x|
                a << x
                i += 1
            end
            a
        end

        def find(p=nil, &b)
            p = Proc.predicate(p, &b)
            each do |x|
                return x if p[x]
            end
            nil
        end

        def any?(p=nil, &b)
            p = Proc.predicate(p, &b)
            each do |x|
                return true if p[x]
            end
            false
        end

        def all?(p=nil, &b)
            p = Proc.predicate(p, &b)
            each do |x|
                return false unless p[x]
            end
            true
        end

        def none?(p=nil, &b)
            p = Proc.predicate(p, &b)
            each do |x|
                return false if p[x]
            end
            true
        end

        def take(n)
            s = self
            Generated.new(n) do |&y|
                i = 0
                s.each do |x|
                    break unless i < n
                    y[x]
                    i += 1
                end
            end
        end

        def take_while(predicate=nil, &block)
            predicate ||= block
            s = self
            Generated.new(size) do |&y|
                s.each do |x|
                    break unless predicate[x]
                    y[x]
                end
            end
        end

        def drop(n)
            s = self
            Generated.new(size - n) do |&y|
                i = 0
                s.each do |x|
                    y[x] if i >= n
                    i += 1
                end
            end
        end

        def drop_while(predicate=nil, &block)
            predicate ||= block
            s = self
            Generated.new(size) do |&y|
                dropping = true
                s.each do |x|
                    dropping &&= predicate[x]
                    y[x] unless dropping
                end
            end
        end

        def head
            each do |x|
                return x
            end
        end
        forward :first, :head

        def tail
            drop(1)
        end

        def enumerator
            Enumerator.new do |y|
                each do |x|
                    y << x
                end
            end
        end

        def zip(*seqs)
            seqs = [self, *seqs]
            Generated.new(seqs.map(&:size).min) do |&y|
                ens = seqs.map(&:enumerator)
                begin
                    loop do
                        y[ens.map(&:next)]
                    end
                rescue StopIteration
                    # ignored
                end
            end
        end
    end

    class Generated
        include Countable

        attr :size

        def initialize(size=nil, &generator)
            @generator = generator
            @size = size || Cardinal[0]
        end

        def each(&block)
            if block
                @generator.call(&block)
            else
                enum_for :each
            end
        end

        def include?(x)
            any?{|y| x == y }
        end
    end

    class Empty
        include Base

        class << self
            def new
                @instance ||= super
            end
        end

        def include?
            false
        end

        def size
            0
        end

        def each
        end

        def empty?
            true
        end

        def finite?
            true
        end

        def ==(x)
            x.to_set.empty?
        end
    end

    class Mapped
        include Base

        attr :unmapped, :function

        def initialize(unmapped, function)
            @unmapped = unmapped
            @function = function

            if unmapped.is_a? Countable
                extend Countable
            end
        end

        def inspect_latex
            Latex.set_builder(function.inspect_latex, "#{function.inspect_domain_latex} \\in #{unmapped.inspect_latex}")
        end

        def size
            unmapped.size
        end

        def include?(x)
            if function.invertible?
                unmapped.include?(function.inverse[x])
            else
                find{|y| x == y }
            end
        end

        def each
            unmapped.each do |x|
                yield function[x]
            end
        end
    end

    class Filtered
        include Base

        attr :unfiltered, :predicate

        def initialize(unfiltered, predicate)
            @unfiltered = unfiltered
            @predicate = predicate

            if unfiltered.is_a? Countable
                extend Countable
            end
        end

        def inspect_latex
            Latex.set_builder("#{predicate.inspect_domain_latex} \\in #{unfiltered.inspect_latex}", predicate.inspect_latex)
        end

        def size
            # TODO: can we do better?
            unfiltered.size
        end

        def include?(x)
            unfiltered.include?(x) && predicate[x]
        end

        def each
            unfiltered.each do |x|
                yield x if predicate[x]
            end
        end
    end

    class Aggregate
        include Base

        class << self
            def new(sets)
                case sets.size
                    when 0
                        Empty.new
                    when 1
                        sets[0]
                    else
                        super
                end
            end
        end

        def initialize(sets)
            @sets = sets
        end
    end

    class Union < Aggregate
        def include?(x)
            @sets.any?{|s| s.include? x }
        end

        def size
            @sets.sum(&:size)
        end

        def empty?
            @sets.all?(&:empty?)
        end

        def countable?
            @sets.all?(&:countable?)
        end

        def finite?
            @sets.all?(&:finite?)
        end
    end

    class Product
        include Base

        class << self
            def new(sets)
                if sets.empty?
                    Empty.new
                else
                    super
                end
            end
        end

        attr :sets

        def initialize(sets)
            @sets = sets
        end

        def inspect
            sets.map(&:inspect).join('×')
        end

        def inspect_latex
            sets.map(&:inspect_latex).join(' \\times ')
        end

        def size
            sets.pro(&:size)
        end

        def include?(x)
            sets.lazy.zip(x).all?{|set, el| set.include? el }
        end

        def each
            size.countable? or raise Error.uncountable(size)

            if block_given?
                first, rest = sets.partition
                rest = sets
                ens = self.sets.lazy.map(&:memoize).memoize



                ens = []
                loop do
                    ens.each do |en|
                        begin
                            yield en.next
                        rescue StopIteration

                        end
                    end
                    ens << s.next.each
                end
            end
        end
    end
end

class Set
    include Sett::Countable

    class << self
        def empty
            @empty ||= Set.new.freeze
        end
    end

    def with(x)
        if include? x
            self
        else
            union([x])
        end
    end

    def without(x)
        if include? x
            difference([x])
        else
            self
        end
    end

    # Return the subset matching the given predicate
    def filter(&p)
        s = self.class.new
        each do |x|
            s << x if p[x]
        end
        s
    end

    # Return the subsets passing and failing the given predicate, respectively
    def bifurcate(&p)
        yes = self.class.new
        no = self.class.new
        each do |x|
            (p[x] ? yes : no) << x
        end
        [yes, no]
    end

    # Remove an element from the set and return it
    def remove_one!
        x = first
        delete(x)
        x
    end

    # Remove and return the subset matching the given predicate
    def remove_if!(&p)
        s = filter(&p)
        subtract(s)
        s
    end

    def to_sorted_set
        SortedSet.new(self)
    end

    class << self
        def product(*sets, &block)
            if block
                new(Enumerable.product(*sets).map(&block))
            else
                new(Enumerable.product(*sets))
            end
        end
    end
end

class SortedSet
    include Sett::Countable

    def to_sorted_set
        self
    end
end

class Numeric
    module Domain
        class Base
            include Sett::Base

            def initialize(name, unicode=name, &block)
                @name = name
                @unicode = unicode

                if block
                    singleton_class.class_eval(&block)
                end
            end

            def inspect
                @unicode
            end

            def inspect_latex
                "\\mathbb{#{@name}}"
            end
        end

        N = Base.new('N', 'ℕ') do
            include Sett::Countable

            def include?(x)
                x.is_a?(Numeric) && x.integer? && !x.negative?
            end

            def size
                ALEPH0
            end

            def each(&block)
                size.times(&block)
            end
        end

        Z = Base.new('Z', 'ℤ') do
            def include?(x)
                x.is_a?(Numeric) && x.integer?
            end

            def size
                ALEPH0
            end
        end

        Q = Base.new('Q', 'ℚ') do
            def include?(x)
                x.is_a?(Numeric) && x.rational?
            end

            def size
                ALEPH0
            end
        end

        R = Base.new('R', 'ℝ') do
            def include?(x)
                x.is_a?(Numeric) && x.real?
            end

            def size
                ALEPH1
            end
        end

        C = Base.new('C', 'ℂ') do
            def include?(x)
                x.is_a?(Numeric)
            end

            def size
                ALEPH1
            end
        end
    end
end

NN = Numeric::Domain::N
ZZ = Numeric::Domain::Z
QQ = Numeric::Domain::Q
RR = Numeric::Domain::R
CC = Numeric::Domain::C
