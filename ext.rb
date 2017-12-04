
module Kernel
    def load_relative(path)
        ctx = caller[0].partition(':')[0]
        if File.exist?(ctx)
            ctx = File.dirname(ctx)
        else
            ctx = Dir.pwd
        end
        load(File.join(ctx, path))
    end
end

class Object
    class << self
        def new_singleton(&decl)
            o = new
            o.singleton_class.class_eval(&decl)
            o
        end
    end

    def frozen_copy
        if frozen?
            self
        else
            dup.freeze
        end
    end

    def send_or(meth, *args, &fallback)
        if respond_to? meth
            __send__(meth, *args)
        else
            fallback[*args]
        end
    end

    def send_if(cond, meth, *args)
        if cond
            __send__(meth, *args)
        else
            self
        end
    end
end

class Module
    def __send_proc__(name, file=nil, line=nil)
        eval(%[proc{|*a, &b| self.#{name}(*a, &b) }], nil, file, line)
    end

    def forward(from, to)
        if m = caller[0].match(/^([^:]+):(\d+)/) and m.captures
            file = m[1]
            line = m[2].to_i
        else
            file = line = nil
        end
        define_method(from, &__send_proc__(to, file, line))
        # eval %{ def #{from}(*args); self.#{to}(*args); end }
    end

    def cache_method(*names)
        names.each do |name|
            cache_name = :"@__cache_#{name.to_s.gsub(/[?!]/, '')}"
            uncached_name = :"__uncached_#{name}"
            fresh_name = :"__fresh_#{name}"
            set_name = :"__set_#{name}"
            invalidate_name = :"__invalidate_#{name}"

            meth = instance_method(name)
            unless meth.original_name == fresh_name
                unless meth.arity == 0
                    raise ArgumentError, "Cannot cache method `#{name}` that takes arguments"
                end

                alias_method uncached_name, name
            end

            define_method set_name do |v|
                instance_variable_set(cache_name, v)
            end

            define_method invalidate_name do
                remove_instance_variable(cache_name)
            end

            define_method fresh_name do
                instance_variable_set(cache_name, __send__(uncached_name))
            end

            define_method name do
                if instance_variable_defined?(cache_name)
                    instance_variable_get(cache_name)
                else
                    instance_variable_set(cache_name, __send__(uncached_name))
                end
            end
        end
    end

    def abstract_method(*names)
        names.each do |name|
            define_method name do |*_|
                raise NotImplementedError, "#{self.class} does not implement ##{name}"
            end
        end
    end

    def attr_const(**attrs)
        attrs.each do |name, value|
            define_method(name){ value }
        end
    end

    def assert_instance(a)
        a.is_a?(self) or raise TypeError, "#{a.inspect} is not a #{name}"
        a
    end

    def assert_instances(*aa)
        aa.each do |a|
            assert_instance(a)
        end
        aa
    end

    def prepending(name, &block)
        prepend(const_set(name, Module.new(&block)))
    end

    prepending :DelegateAwareness do
        def ===(x)
            x.is_a?(self) || super
        end
    end
end

module EnumMethods
    class EnumeratedMethod < ::Enumerator
        def initialize(method, *args)
            @method = method
            @args = args
            super() do |yielder|
                method.call(*args) do |*yielded|
                    yielder.yield(*yielded)
                end
            end
        end

        def inspect
            if @args.empty?
                "<#{::Enumerator}: #{@method.receiver.inspect}:#{@method.name}>"
            else
                "<#{::Enumerator}: #{@method.receiver.inspect}:#{@method.name}(#{@args.map(&:inspect).join(', ')})>"
            end
        end
    end

    def method_added(name)
        enum_name = :"__enum_#{name}"
        if method_defined?(enum_name)
            _link_enum_method(name, enum_name)
        end
        super
    end

    def _link_enum_method(name, enum_name)
        meth = instance_method(name)

        unless meth.original_name == enum_name
            define_method enum_name do |*args, &block|
                bmeth = meth.bind(self)
                if block
                    bmeth.call(*args, &block)
                else
                    EnumeratedMethod.new(bmeth, *args)
                end
            end

            alias_method name, enum_name
        end
    end

    def enum_method(*names)
        names.each do |name|
            enum_name = :"__enum_#{name}"
            if method_defined?(name)
                _link_enum_method(name, enum_name)
            else
                define_method enum_name do |*args, &block|
                    __send__(name, *args, &block)
                end
            end
        end
    end

    class GeneratorMethod
        include Enumerable

        def initialize(obj, meth, args, block=nil)
            @obj = obj
            @meth = meth.bind(obj)
            @args = args
            @block = block
        end

        def inspect
            "#{@obj.inspect}##{@meth.name}(#{[*@args, @block].compact.map(&:inspect).join(', ')})"
        end

        def each(&block)
            if block
                @meth[Enumerator::Yielder.new(&block), *@args, &@block]
            else
                enum_for(:each)
            end
        end
    end

    def generator(*names)
        names.each do |name|
            meth = instance_method(name)
            define_method name do |*args, &block|
                GeneratorMethod.new(self, meth, args, block)
            end
        end
    end

    ::Module.prepend(self)
end

class Object
    def enum_method(*names)
        singleton_class.enum_method(*names)
    end

    def generator(*names)
        singleton_class.generator(*names)
    end
end

class Range
    class << self
        def from(start, length=nil)
            if length.nil?
                if start.is_a? Range
                    return start
                else
                    length = ALEPH0
                end
            end
            new(start, start + length, true)
        end
    end
end

module RangeExt
    def end_open
        if exclude_end? || size.infinite?
            self.end
        else
            self.end.succ
        end
    end

    def to_closed_open
        if exclude_end? || size.infinite?
            self
        else
            self.begin ... self.end.succ
        end
    end

    def subseq(from, length=nil)
        if length.nil? || length.infinite?
            if from.is_a?(Range)
                Range.new(self.begin + from.begin, (self.begin + from.end_open).min(self.end_open), true)
            elsif from.zero?
                self
            else
                Range.new(self.begin + from, self.end_open, true)
            end
        elsif from.zero? && length > cardinality
            self
        else
            Range.new(self.begin + from, (self.begin + from + length).min(self.end_open), true)
        end
    end

    Range.prepend(self)
end


module ArrayExt
    def [](*args)
        i, j = args
        if i.is_a?(Range) && i.end.infinite?
            super(i.begin, size)
        elsif j && j.infinite?
            super(i, size)
        else
            super
        end
    end

    def sort_desc(&block)
        if block
            sort{|a, b| block[b, a] }
        else
            sort{|a, b| b <=> a }
        end
    end

    def sort_desc!(&block)
        if block
            sort!{|a, b| block[b, a] }
        else
            sort!{|a, b| b <=> a }
        end
    end

    def concat(*seqs)
        if seqs.all?{|seq| seq.respond_to? :to_ary }
            super
        else
            Enumerable.concat(self, *seqs)
        end
    end

    Array.prepend(self)
end

class Hash
    def default_for(k)
        if default_proc
            default_proc.call(self, k)
        else
            default
        end
    end

    def copy_default_from(h)
        if h.default_proc
            self.default_proc = h.default_proc
        elsif h.default
            self.default = h.default
        end
        self
    end

    def dup_empty
        self.class.new.copy_default_from(self)
    end

    class << self
        def normalized(default=nil, &block)
            NormalizedHash.new(default, &block)
        end

        def mapping(h={})
            NormalizedHash.new{|k| k}.merge!(h)
        end
    end
end

class NormalizedHash < Hash
    def initialize(default=nil, &block)
        if default.nil?
            super() do |_, k|
                block.call(k)
            end
        else
            super
        end
    end

    def []=(k, v)
        if default_for(k) == v
            delete(k)
        else
            super
        end
    end

    def merge!(h, &block)
        if block
            h.each do |k, v|
                v = block.call(k, self[k], v) if key?(k)
                self[k] = v
            end
        else
            h.each do |k, v|
                self[k] = v
            end
        end
        self
    end
    alias_method :update, :merge!

    def merge(h, &block)
        dup.merge!(h, &block)
    end

    def mash(&block)
        if block && !empty?
            h = dup_empty
            each do |k, v|
                k, v = block.call([k, v])
                h[k] = v
            end
            h
        else
            self
        end
    end

    def sort_hash_by(&block)
        if empty?
            self
        else
            h = dup_empty
            sort_by(&block).each{|k, v| h[k] = v }
            h
        end
    end

    def sort_by_key
        sort_hash_by{|h, _| h }
    end

    def invert_mapping
        h = dup_empty
        each do |k,v|
            h[v] = k
        end
        h
    end
end

class Symbol
    def blank?
        self =~ /^\s*$/
    end
end

class String
    def blank?
        self =~ /^\s*$/
    end

    def search(pat)
        m = match(pat) and m[0]
    end

    def capture(pat)
        m = match(pat) and m.captures
    end
end

class Proc
    def map_params(&block)
        parameters.map do |type, name|
            type == :opt or raise ArgumentError, "Wildcard parameter '#{name}' is not allowed here"
            block[name]
        end
    end

    def call_with_mapped_params(&block)
        params = map_params(&block)
        [call(*params), *params]
    end
end

require_relative 'enumerable'
