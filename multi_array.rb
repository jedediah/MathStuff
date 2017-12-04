

class MultiArray
    include Enumerable

    def initialize(arg=nil, default=nil)
        if arg.is_a? Integer
            @b = [default]
            @e = [arg]
        elsif arg.is_a? MultiArray
            @b = arg._b.dup
            @e = arg._e.dup
        else
            @b = []
            @e = []
            if arg.respond_to? :to_hash
                arg.to_hash.each do |b, e|
                    if e > 0
                        @b << b
                        @e << (@e[-1] || 0) + e
                    end
                end
            elsif arg.is_a? Enumerable
                arg.each{|x| self << x}
            end
        end
    end

    class << self
        forward :[], :new

        def _create(b, e)
            x = allocate
            x._set(b, e)
            x
        end
    end

    def inspect
        "[#{each_run.map{|b, e| "#{b.inspect}#{" × #{e.inspect}" if e > 1}"}.join(', ')}]"
    end
    forward :to_s, :inspect

    def _b
        @b
    end

    def _e
        @e
    end

    def _idx(i)
        @e.bsearch_index{|s| i < s }
    end

    def _set(b, e)
        @b = b
        @e = e
    end

    def hash
        [@b, @e].hash
    end

    def eql?(x)
        x.is_a?(MultiArray) && @b.eql?(x._b) && @e.eql?(x._e)
    end
    forward :==, :eql?

    def matches?(seq)
        if seq.is_a?(MultiArray)
            @b.eql?(seq._b) && @e.eql?(seq._e)
        else
            en = seq.each
            all? do |x|
                y = begin en.next
                rescue StopIteration
                    return false
                end
                x.eql?(y)
            end
        end
    end

    def empty?
        @e.empty?
    end

    def size
        if @e.empty?
            0
        else
            @e[-1]
        end
    end

    def first
        @b[0]
    end

    def last
        @b[-1]
    end

    def to_a
        each.to_a
    end
    forward :to_ary, :to_a

    def each_factor
        e0 = 0
        @b.size.times do |i|
            e1 = @e[i]
            yield @b[i], e1-e0
            e0 = e1
        end
    end
    enum_method :each_run

    def each
        e0 = 0
        @b.size.times do |i|
            b = @b[i]
            e1 = @e[i]
            (e1-e0).times do
                yield b
            end
            e0 = e1
        end
    end
    enum_method :each

    def map_factors(&block)
        bs = []
        es = []
        each_factor do |b, e|
            b, e = block[b, e]
            if e > 0
                if !bs.empty? && bs[-1].eql?(b)
                    es[-1] += e
                else
                    bs << b
                    es << (es[-1] || 0) + e
                end
            end
        end
        self.class._create(bs, es)
    end
    enum_method :map_factors

    def map(&block)
        self.class._create(@b.map(&block), @e.dup)
    end
    enum_method :map

    def select(&block)
        bs = []
        es = []
        each_factor do |b, e|
            if block[b]
                bs << b
                es << (es[-1] || 0) + e
            end
        end
        self.class._create(bs, es)
    end

    def reject(&block)
        bs = []
        es = []
        each_factor do |b, e|
            unless block[b]
                bs << b
                es << (es[-1] || 0) + e
            end
        end
        self.class._create(bs, es)
    end

    def zip(*seqs, &block)
        case seqs.size
            when 0
                each(&block)
            when 1
                en = seqs[0].enum_for(:each)
                each do |a|
                    block[a, en.try_next]
                end
            else
                ens = seqs.map{|seq| seq.enum_for(:each) }
                each do |a|
                    block[a, *ens.map(&:try_next)]
                end
        end
    end
    enum_method :zip

    def _sub(a, z)
        z = z.min(size)
        if a == z
            self.class._create([], [])
        elsif ia = _idx(a)
            iz = _idx(z-1) || @b.size-1
            r = ia..iz
            b = @b[r]
            e = r.map{|k| @e[k] - a }
            e[-1] = z-a
            self.class._create(b, e)
        end
    end

    def take(n)
        n >= 0 or raise ArgumentError, "attempt to take negative size"
        _sub(0, n)
    end

    def drop(n)
        n >= 0 or raise ArgumentError, "attempt to drop negative size"
        _sub(n, size)
    end

    def [](i, j=nil)
        if !j.nil?
            if j > 0
                _sub(i, i+j)
            elsif j == 0
                self.class._create([], [])
            end
        elsif i.is_a? Range
            z = i.end
            z += size if z < 0
            if i.exclude_end?
                _sub(i.begin, z)
            else
                _sub(i.begin, z+1)
            end
        elsif i < 0
            self[size + i]
        else
            j = _idx(i) and @b[j]
        end
    end
    forward :slice, :[]

    def <<(x)
        if !@b.empty? && @b[-1].eql?(x)
            @e[-1] += 1
        else
            @b << x
            @e << (@e[-1] || 0) + 1
        end
        self
    end

    def push(*xs)
        xs.each{|x| self << x }
    end

    def pushn(x, n)
        if n > 0
            if !@b.empty? && @b[-1].eql?(x)
                @e[-1] += n
            else
                @b << x
                @e << n
            end
        end
        self
    end

    def concat(a)
        if a.respond_to? :to_hash
            a.to_hash.each do |x, n|
                pushn(x, n)
            end
        elsif a.is_a? MultiArray
            if empty?
                @b = a._b.dup
                @e = a._e.dup
            elsif !a.empty?
                s = size
                if @b[-1].eql? a._b[0]
                    @e[-1] += a._e[0]
                    @b.concat(a._b[1..-1])
                    @e.concat(a._e[1..-1].map{|k| s + k })
                else
                    @b.concat(a._b)
                    @e.concat(a._e.map{|k| s + k })
                end
            end
        elsif a.respond_to? :to_ary
            a.to_ary.each do |x|
                self << x
            end
        else
            raise TypeError, "no implicit conversion of #{a.class} into Array"
        end
        self
    end
end
