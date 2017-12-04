
require_relative 'ext'
require_relative 'transfinite'

module EnumerablePrepend
    def take(n)
        if n.infinite?
            self
        else
            super
        end
    end
end

module Enumerable
    prepend EnumerablePrepend

    class Empty
        include Enumerable

        class << self
            def new
                @instance ||= super
            end
        end

        def each
            if block_given?
                self
            else
                enum_for :each
            end
        end
    end

    class Generated
        include Enumerable

        attr :yielder

        def initialize(&yielder)
            @yielder = yielder
        end

        def each(&block)
            if block
                each.each(&block)
            else
                Enumerator.new(&@yielder)
            end
        end
    end

    class Concatenation
        include Enumerable

        class << self
            def new(*seqs)
                case seqs.size
                    when 0
                        Empty.new
                    when 1
                        seqs[0]
                    else
                        super(*seqs)
                end
            end
        end

        def initialize(*seqs)
            @seqs = seqs
        end

        def each
            @seqs.each do |seq|
                seq.each do |el|
                    yield el
                end
            end
            self
        end
        enum_method :each

        def size
            @seqs.sum(&:size)
        end
    end

    class Transformed
        include Enumerable

        def initialize(seq, &func)
            @seq = seq
            @func = func
        end

        class << self
            def new(seq, &func)
                if func
                    super
                else
                    seq
                end
            end
        end

        def each
            @seq.each do |x|
                yield @func[x]
            end
            self
        end
        enum_method :each

        def size
            @seq.size
        end
    end

    class Filtered
        include Enumerable

        def initialize(seq, &pred)
            @seq = seq
            @pred = pred
        end

        def each
            @seq.each do |x|
                yield x if @pred[x]
            end
            self
        end
        enum_method :each

        def inspect
            "#{@seq.inspect} : #{@pred.inspect}"
        end
    end

    class Unique
        include Enumerable

        def initialize(seq, &key)
            @seq = seq
            @key = key
        end

        def each
            seen = Set[]
            if @key
                @seq.each do |x|
                    seen.add?(@key[x]) and yield x
                end
            else
                @seq.each do |x|
                    seen.add?(x) and yield x
                end
            end
        end
        enum_method :each
    end

    class Repeated
        include Enumerable

        def initialize(seq, count=ALEPH0)
            @seq = seq
            @count = count
        end

        def each
            @count.times do
                @seq.each do |x|
                    yield x
                end
            end
            self
        end
        enum_method :each

        def size
            @seq.size * @count
        end

        def inspect
            "#{@seq.inspect} × #{@count}"
        end
    end

    class Subsequence
        include Enumerable

        class << self
            def new(seq, from, length=nil)
                if length.nil?
                    from.is_a?(Range) and return new(seq, from.begin, from.size)
                    length = ALEPH0
                elsif length.zero?
                    Empty.new
                end

                if from.zero? && length >= seq.size
                    seq
                elsif from.infinite?
                    raise ArgumentError, "Subsequence cannot start at infinite offset #{from}"
                else
                    super(seq, from, length.min(seq.size - from))
                end
            end
        end

        def initialize(seq, from, length)
            @seq = seq
            @from = from
            @to = if length.finite?
                from + length
            else
                Ordinal::OMEGA
            end
        end

        def inspect
            "#{@seq.inspect}[#{@from.inspect}...#{@to.inspect if @to.finite?}]"
        end

        def each
            i = 0
            @seq.each do |x|
                break if i >= @to
                yield x if i >= @from
                i = i.succ
            end
            self
        end
        enum_method :each

        def size
            if @to.finite?
                @to - @from
            else
                ALEPH0
            end
        end
    end

    class Memoization
        include Enumerable

        def initialize(source=nil, &block)
            @source = Enumerable.create(source, &block)
            @elements = []
        end

        def each
            @elements.each do |e|
                yield e
            end
            en = @source.each.skip(@elements.size)
            loop do
                e = en.next
                @elements << e
                yield e
            end
            self
        rescue StopIteration
            # ignored
        end
        enum_method :each

        def [](i)
            n = i - @elements.size + 1
            if n > 0
                en = @source.each.skip(@elements.size)
                n.times{ @elements << en.next }
            end
            @elements[i]
        end
    end

    class << self
        def empty
            Empty.new
        end

        def cycle(*els)
            els.repeat
        end

        def concat(*seqs)
            Concatenation.new(*seqs)
        end

        def memoize(seq=nil, &block)
            Memoization.new(seq, &block)
        end

        def generate(&block)
            Generated.new(&block)
        end

        def create(seq=nil, &block)
            unless seq.nil?
                seq.is_a?(Enumerable) or raise TypeError, "#{seq.class} is not enumerable"
            end

            if block
                if seq.nil?
                    generate(&block)
                else
                    seq.transform(&block)
                end
            else
                seq
            end
        end

        def zip(*seqs, &block)
            if block
                case count = seqs.size
                    when 0
                    when 1
                        seqs[0].each(&block)
                    when 2
                        en0 = seqs[0].each
                        en1 = seqs[1].each
                        loop do
                            x0 = begin
                                en0.next
                            rescue StopIteration
                                loop do
                                    x1 = begin
                                        en1.next
                                    rescue StopIteration
                                        return
                                    end
                                    block[nil, x1]
                                end
                            end

                            x1 = begin
                                en1.next
                            rescue StopIteration
                                block[x0, nil]
                                loop do
                                    x0 = begin
                                        en0.next
                                    rescue StopIteration
                                        return
                                    end
                                    block[x0, nil]
                                end
                            end

                            block[x0, x1]
                        end
                    else
                        ens = seqs.map(&:each)
                        while count > 0
                            t = ens.map_with_index do |en, i|
                                if en.nil?
                                    nil
                                else
                                    begin
                                        en.next
                                    rescue StopIteration
                                        count -= 1
                                        ens[i] = nil
                                    end
                                end
                            end
                            break unless count > 0
                            block[*t]
                        end
                end
                nil
            else
                enum_for(:zip, *seqs)
            end
        end

        def product(*seqs, &block)
            if block
                unless seqs.empty?
                    seq, *seqs = seqs
                    if seqs.empty?
                        seq.each do |x|
                            block[x]
                        end
                    else
                        seq.each do |x|
                            product(*seqs) do |*ys|
                                block[x, *ys]
                            end
                        end
                    end
                end
                nil
            else
                enum_for(:product, *seqs)
            end
        end

        def power(seq, n)
            if n.negative?
                raise ArgumentError, "Exponent cannot be negative"
            elsif n.zero?
                Empty.new
            elsif n.one?
                seq.each do |x|
                    yield [x]
                end
            else
                seq.each do |x|
                    power(seq, n-1) do |ys|
                        yield [x, *ys]
                    end
                end
            end
        end
        enum_method :power

        def filter(seq, &pred)
            Filtered.new(seq, &pred)
        end

        def unique(seq, &key)
            Unique.new(seq, &key)
        end

        def interpolate(n, a, b)
            (0..n).each do |i|
                yield a.lerp(b, i/n)
            end
        end
        enum_method(:interpolate)
    end

    def subseq(from, length=nil)
        Subsequence.new(self, from, length)
    end
    forward :[], :subseq

    def prefix(to)
        subseq(0, to)
    end

    def suffix(from)
        subseq(from, ALEPH0)
    end

    def while(yy, &pred)
        pred or raise ArgumentError, "Predicate block required"
        each do |x|
            break unless pred[x]
            yy << x
        end
    end
    generator :while

    def until(yy, &pred)
        pred or raise ArgumentError, "Predicate block required"
        each do |x|
            break if pred[x]
            yy << x
        end
    end
    generator :until

    # "prepend" conflicts with Module#prepend
    def prep(el)
        Concatenation.new([el], self)
    end

    def append(el)
        Concatenation.new(self, [el])
    end

    def concat(*seqs)
        Concatenation.new(self, *seqs)
    end

    def memoize
        Memoization.new(self)
    end

    def transform(&func)
        Transformed.new(self, &func)
    end
    forward :tf, :transform

    def filter(&pred)
        Filtered.new(self, &pred)
    end

    def exclude(yy, &pred)
        pred or raise ArgumentError, "Predicate block required"
        each do |x|
            yy << x unless pred[x]
        end
    end
    generator :exclude

    def unique(&key)
        Unique.new(self, &key)
    end

    def repeat(count=ALEPH0)
        Repeated.new(self, count)
    end

    def product(*ens, &block)
        Enumerable.product(self, *ens, &block)
    end

    def power(n, &block)
        Enumerable.power(self, n, &block)
    end

    def to_sorted_set
        SortedSet.new(self)
    end

    def reverse(&block)
        if block
            to_a.reverse_each{|x| block[x] }
        else
            enum_for(:reverse)
        end
    end

    def mash(&block)
        if block
            h = {}
            each do |*x|
                k, v = block.call(*x)
                h[k] = v
            end
            h
        else
            to_h
        end
    end

    def map_to(&block)
        if block
            h = {}
            each do |x|
                h[x] = block[x]
            end
            h
        else
            to_enum(:map_to) { size if respond_to? :size }
        end
    end

    def unique_counts
        h = Hash.new(0)
        each do |x|
            h[x] += 1
        end
        h
    end

    def reduce_with_count(*args, &block)
        if args.empty?
            a = nil
            n = 0
        else
            a, = args
            n = 1
        end
        each do |x|
            a = if n.zero?
                x
            else
                block[a, x]
            end
            n += 1
        end
        return a, n
    end

    def partial_sums
        a = nil
        each do |x|
            a = a.nil? ? x : a + x
            yield a
        end
    end
    enum_method :partial_sums

    def pro(initial=1, &block)
        if block
            reduce(initial) do |a, x|
                a * block[x]
            end
        else
            reduce(initial, &:*)
        end
    end

    def flimit(e=Float::EPSILON*2)
        y = nil
        each do |x|
            x = x.to_f
            break if y && (x-y).abs <= e
            y = x
        end
        y
    end

    def flimit_with_count(e=Float::EPSILON*2)
        y = nil
        n = 0
        each do |x|
            x = x.to_f
            break if y && (x-y).abs <= e
            y = x
            n += 1
        end
        return y, n
    end

    def mean
        s, n = if block_given?
            reduce_with_count do |a, x|
                a + (yield x)
            end
        else
            reduce_with_count do |a, x|
                a + x
            end
        end
        s / n if n > 0
    end

    def zip_index
        i = 0
        each do |x|
            yield [x, i]
            i += 1
        end
    end
    enum_method :zip_index

    def map_with_index(&block)
        if block
            i = -1
            map do |x|
                i += 1
                block[x, i]
            end
        else
            enum_for :map_with_index
        end
    end

    def reduce_with_index(init, &block)
        if block
            i = -1
            reduce(init) do |agg, x|
                i += 1
                block[agg, x, i]
            end
        else
            enum_for(:reduce_with_index, init)
        end
    end

    def min_with_index
        m = nil
        i = nil
        each_with_index do |x, j|
            if m.nil? || (m <=> x) > 0
                m = x
                i = j
            end
        end
        [m, i]
    end

    def max_with_index
        m = nil
        i = nil
        each_with_index do |x, j|
            if m.nil? || (m <=> x) < 0
                m = x
                i = j
            end
        end
        [m, i]
    end

    def all_with_index?
        each_with_index do |x, i|
            return nil unless yield x, i
        end
        true
    end
    enum_method :all_with_index?

    def any_with_index?
        each_with_index do |x, i|
            return true if yield x, i
        end
        false
    end
    enum_method :any_with_index?

    def none_with_index?
        each_with_index do |x, i|
            return false if yield x, i
        end
        true
    end
    enum_method :none_with_index?

    forward :head, :first

    def head
        if block_given?
            each do |x|
                yield x
                break
            end
            tail
        else
            first
        end
    end

    def tail(&block)
        if block
            b = false
            each do |x|
                if b
                    block[x]
                else
                    b = true
                end
            end
        else
            enum_for :tail
        end
    end

    def head_tail(&block)
        t = each
        if block
            begin
                h = t.next
            rescue StopIteration
                return
            end
            block[h, t]
        else
            [t.next, t]
        end
    end

    def _combination(n, limit, &block)
        return if n < 1
        each_with_index do |x, i|
            break if i == limit
            if n > 1
                _combination(n-1, i) do |y|
                    block[[*y, x]]
                end
            else
                block[[x]]
            end
        end
    end

    def combination(n, &block)
        if block
            _combination(n, nil, &block)
        else
            enum_for(:combination, n)
        end
    end

    def _multisets(n, limit, &block)
        if n == 1
            each_with_index do |x, i|
                break if i == limit
                block[[x]]
            end
        elsif n > 1
            each_with_index do |x, i|
                break if i == limit
                _multisets(n-1, i+1) do |y|
                    block[[*y, x]]
                end
            end
        end
    end

    def multisets(n, &block)
        if block
            _multisets(n, nil, &block)
        else
            enum_for(:multisets, n)
        end
    end

    def bailout(n, &block)
        if block
            i = 0
            each do |x|
                if (i += 1) >= n
                    raise "Bailing out after #{n} iterations"
                end
                block[x]
            end
        else
            enum_for(:bailout, n)
        end
    end

    def find_last(&block)
        reduce(nil) do |r, x|
            block[x] ? x : r
        end
    end
    enum_method :find_last
end

module EnumeratorPrepend
    def next
        if block_given?
            begin
                x = super
            rescue StopIteration
                @done = true
                return
            end
            yield x
        else
            begin
                super
            rescue StopIteration
                @done = true
                raise
            end
        end
    end

    def peek
        super
    rescue StopIteration
        @done = true
        raise
    end

    ::Enumerator.prepend(self)
end

class Enumerator
    def try_peek
        peek unless @done
    rescue StopIteration
        nil
    end

    def try_next
        self.next unless done?
    rescue StopIteration
        nil
    end

    def more?
        try_peek
        !@done
    end

    def done?
        try_peek
        @done || false
    end

    def rest(&block)
        if block
            loop do
                x = try_next
                break if @done
                block[x]
            end
        else
            self
        end
    end

    def skip(n)
        n.times{ self.next }
        self
    end

    def skip_while(&cond)
        n = 0
        while cond[peek]
            self.next
            n += 1
        end
        n
    rescue StopIteration
        n
    end

    def skip_until(&cond)
        n = 0
        until cond[peek]
            n += 1
            self.next
        end
        n
    rescue StopIteration
        n
    end

    def next_while(&cond)
        a = []
        a << self.next while cond[peek]
        a
    rescue StopIteration
        a
    end

    def next_until(&cond)
        a = []
        a << self.next until cond[peek]
        a
    rescue StopIteration
        a
    end
end
