require 'active_support/concern'

module Interned
    extend ActiveSupport::Concern

    module ClassMethods
        def new(*args)
            (@instances ||= {})[[self, *args]] ||= super
        end
    end
end

class Monad
    class << self
        forward :unit, :new
    end

    def method_missing(meth, *args)
        bind do |x|
            self.class.unit(x.__send__(meth, *args))
        end
    end
end

class Maybe < Monad
    class << self
        def unit(x)
            Just.new(x)
        end
    end
end

class Nothing < Maybe
    include Interned

    def inspect
        'Nothing'
    end

    def bind(&f)
        self
    end
end

class Just < Maybe
    def initialize(value)
        @value = value
    end

    def inspect
        "Just[#{@value.inspect}]"
    end

    def bind(&f)
        f[@value]
    end
end

class List < Monad
    include Enumerable

    class << self
        def unit(x)
            Elements.new([x])
        end

        def empty
            @empty ||= Elements.new([])
        end
    end

    def bind(&f)
        Mapped.new(self, &f)
    end

    class Elements < List
        def initialize(els)
            @els = els.freeze
        end

        def inspect
            "Elements#{@els.inspect}"
        end

        def each(&block)
            @els.each(&block)
        end
    end

    class Mapped < List
        def initialize(list, &func)
            @list = list
            @func = func
        end

        def inspect
            "Mapped{#{@func.inspect} #{@list.inspect}}"
        end

        def each
            @list.each do |x|
                @func[x].each do |y|
                    yield y
                end
            end
        end
    end
end
