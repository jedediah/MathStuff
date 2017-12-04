require 'active_support/concern'
require 'active_support/core_ext/module/concerning'
require 'multiset'

require_relative 'tuple'
require_relative 'latex'

module Expr
    extend ActiveSupport::Concern
    include Latex::Inspectable

    UNARY_OPS = %i[
        ! ~ +@ -@
    ]

    BINARY_OPS = %i[
        **
        * / %
        + -
        >> <<
        & ^ |
        <= < > >=
        <=> == != =~ !~
    ]

    ARITHMETIC_OPS = %i[
        +@ -@
        **
        * / %
        + -
    ]

    LOGICAL_OPS = %i[
        ~ & ^ |
    ]

    # NARY_OPS = %i{
    #     [] []=
    # }

    OPERATORS = {}
    UNARY_OPS.each{|op| OPERATORS[op] = 1 }
    BINARY_OPS.each{|op| OPERATORS[op] = 2 }
    # NARY_OPS.each{|op| OPERATORS[op] = -1 }

    HANDLERS = {}

    UNARY_OPS.each do |op|
        define_method op do
            if handlers = HANDLERS[op]
                handlers.each do |(pa), handler|
                    if pa === self
                        return Expr.wrap_after_op(handler[self])
                    end
                end
            end
            super
            # raise TypeError, "Undefined operation '#{op} #{inspect}'"
        end
    end

    BINARY_OPS.each do |op|
        define_method op do |b|
            if handlers = HANDLERS[op]
                b = Expr[b]
                handlers.each do |(pa, pb), handler|
                    if pa === self && pb === b
                        return Expr.wrap_after_op(handler[self, b])
                    end
                end
            end
            super(b)
            # raise TypeError, "Undefined operation '#{inspect} #{op} #{b.inspect}'"
        end
    end

    module ObjectExt
        def defop(op, *params, &handler)
            op = op.to_sym
            if UNARY_OPS.include?(op)
                params.size == 1 or raise ArgumentError, "Unary operator '#{op}' has one parameter"
            elsif BINARY_OPS.include?(op)
                params.size == 2 or raise ArgumentError, "Binary operator '#{op}' has two parameters"
            else
                raise ArgumentError, "Unknown operator '#{op}'"
            end

            (HANDLERS[op] ||= {})[params.map{|p| Expr.matcher(p)}] = handler
        end
    end

    extend ObjectExt
    ::Object.__send__(:include, ObjectExt)

    attr_const precedence: 0

    def inspect_child(expr, *args)
        if expr.is_a?(Expr) && expr.precedence < precedence
            "(#{expr.inspect(*args)})"
        else
            expr.inspect(*args)
        end
    end

    def inspect_child_latex(expr, *args)
        if expr.is_a?(Expr) && expr.precedence < precedence
            "(#{expr.inspect_latex(*args)})"
        else
            expr.inspect_latex(*args)
        end
    end

    forward :to_s, :inspect

    def zero?
        false
    end

    def one?
        false
    end

    def free_variables
        Set.empty
    end

    def coerce(x)
        if ex = Expr.wrap_or_nil(x)
            return ex, self
        elsif x.respond_to?(:to_f) && respond_to?(:to_f)
            return x.to_f, to_f
        else
            raise Expr.coercion_error(x)
        end
    end

    def args
        Tuple[]
    end

    def syntax
        if args.empty?
            self
        else
            [self.class, *args.map(&:syntax)]
        end
    end

    def create
        self
    end

    class << self
        def coercion_error(x)
            TypeError.new("#{x.class} can't be coerced into an expression")
        end

        def wrap_or_nil(x)
            if x.is_a? Expr
                x
            elsif x.is_a? Literal::Wrappable
                Literal.new(x)
            end
        end

        def wrap_or_x(x)
            wrap_or_nil(x) or x
        end

        def wrap_after_op(x)
            if x.is_a? Expr
                x.simplify
            elsif x.is_a? Literal::Wrappable
                Literal.new(x)
            else
                x
            end
        end

        def [](x)
            wrap_or_nil(x) or raise coercion_error(x)
        end

        def matcher(p)
            if p.is_a? Module
                p
            else
                Expr[p]
            end
        end

        def _nosimp?
            @nosimp
        end

        def rules(&block)
            @nosimp = true
            class_eval(&block)
        ensure
            @nosimp = nil
        end
    end

    def compare_weight(expr)
        case precedence <=> expr.precedence
            when -1
                args.any? do |arg|
                    arg.compare_weight(expr) >= 0
                end ? 1 : -1
            when 1
                expr.args.all? do |arg|
                    compare_weight(arg) > 0
                end ? 1 : -1
            else
                a = Multiset.new(args)
                b = Multiset.new(expr.args)
                if a.proper_superset?(b)
                    1
                elsif a.proper_subset?(b)
                    -1
                else
                    c = a - b
                    d = b - a
                    if c.size == 1 && d.all?{|arg| arg.compare_weight(c.first) < 0}
                        1
                    elsif d.size == 1 && c.all?{|arg| arg.compare_weight(d.first) < 0}
                        -1
                    else
                        0
                    end
                end
        end
    end

    def matches?(expr, vars={})
        vars if eql?(expr)
    end

    def rewrite(rules)
        rules.fetch(self, self)
    end

    def simplify
        return self if Expr._nosimp?

        expr = create(*args.map(&:simplify))
        REDUCTIONS.each do |pat, trans|
            vars = pat.free_variables.map_to{Expr}
            if m = pat.matches?(expr, vars)
                expr = Expr[trans[m]].simplify
                break
            end
        end
        expr
    end

    REDUCTIONS = {}

    class << self
        def rewrite(rels={})
            rels.each do |pat, result|
                REDUCTIONS[Expr[pat]] = Expr[result].method(:rewrite)

                # case a.compare_weight(b)
                #     when -1
                #         equate(b, a)
                #     when 1
                #         REDUCTIONS[[a, a.free_variables.map_to{Expr}]] = b
                #     else
                #         raise ArgumentError, "Expressions have equal weight: #{a} and #{b}"
                # end
            end
        end

        def process(pat, &block)
            vars = block.map_params do |name|
                pat.free_variables.find{|var| var.name == name } or raise ArgumentError, "Pattern has no variable named '#{name}'"
            end
            REDUCTIONS[pat] = proc do |m|
                block[*vars.map{|var| m[var] }]
            end
        end

        # def rewrite(*types, &block)
        #     expr, *vars = Variable.call_with_vars(&block)
        #     types.size == vars.size or raise ArgumentError, "Expected #{vars.size} variable constraints"
        #     REDUCTIONS[[expr, vars.zip(types).mash]] = expr
        # end
    end
end

class Literal < SimpleDelegator
    include Expr

    attr_const precedence: 100

    WRAPPED_TYPES = [Integer, Float, Rational, Complex]
    module Wrappable
        WRAPPED_TYPES.each{|t| t.__send__(:include, self) }
    end

    class << self
        def new(x)
            if x.is_a? Literal
                x
            elsif x.is_a? Wrappable
                super
            else
                raise TypeError, "#{x.class} is not a literal value"
            end
        end
        forward :[], :new
    end

    forward :value, :__getobj__

    def is_a?(type)
        super(type) || value.is_a?(type)
    end

    defop(:==, Literal, Literal) {|x, y| x.value == y.value }

    module EqlFix
        def eql?(x)
            if x.is_a?(Literal)
                eql?(x.value)
            else
                super
            end
        end

        WRAPPED_TYPES.each{|t| t.prepend(self) }
    end
end

module Operation
    extend ActiveSupport::Concern
    include Expr

    attr :args

    def initialize(*args)
        @args = args.frozen_copy
    end

    class_methods do
        def create(*args)
            ex = allocate
            ex.__send__(:initialize, *args)
            ex
        end

        def new(*args)
            Expr[create(*args.map{|arg| Expr[arg] })].simplify
        end
        forward :[], :new

        def handleop(op, *params)
            Expr.defop(op, *params, &method(:create))
        end
    end

    def create(*args)
        if args == self.args
            self
        else
            self.class.create(*args)
        end
    end

    def rewrite(rules)
        rules.fetch(self) do
            create(*args.map do |arg|
                arg.rewrite(rules)
            end)
        end
    end

    def name
        self.class.name
    end

    def name_latex
        name
    end

    def eql?(x)
        self.class == x.class && args == x.args
    end

    def hash
        [self.class, *args].hash
    end

    def inspect
        if args.empty?
            name
        else
            "#{name}(#{args.map(&:inspect).join(', ')})"
        end
    end

    def inspect_latex
        if args.empty?
            name_latex
        else
            "#{name_latex}(#{args.map{|x| x.inspect_latex }.join(', ')})"
        end
    end

    def free_variables
        args.map(&:free_variables).reduce(&:union)
    end

    def matches?(expr, vars={})
        if self.class == expr.class && args.size == expr.args.size
            args.zip(expr.args) do |x, y|
                vars = x.matches?(y, vars) or break
            end
            vars
        end
    end
end

module PrefixOp
    extend ActiveSupport::Concern
    include Operation

    def initialize(arg)
        super
    end

    def arg
        args[0]
    end

    def inspect
        "#{name} #{inspect_child(arg)}"
    end

    def inspect_latex
        "#{name_latex} #{inspect_child_latex(arg)}"
    end
end

module InfixOp
    extend ActiveSupport::Concern
    include Operation

    def initialize(lhs, rhs)
        super
    end

    def lhs
        args[0]
    end

    def rhs
        args[1]
    end

    def inspect
        "#{inspect_child(lhs)} #{name} #{inspect_child(rhs)}"
    end

    def inspect_latex
        "#{inspect_child_latex(lhs)} #{name_latex} #{inspect_child_latex(rhs)}"
    end
end

class Variable
    include Expr

    attr_const precedence: 90

    class << self
        def [](*args)
            vars = []
            args.each do |arg|
                if arg.respond_to? :to_str
                    arg.to_str.split.each do |name|
                        vars << new(name)
                    end
                elsif arg.respond_to? :to_hash
                    arg.each do |name, con|
                        vars << new(name, con)
                    end
                else
                    raise ArgumentError, arg
                end
            end
            case vars.size
                when 0
                    nil
                when 1
                    vars[0]
                else
                    vars
            end
        end

        def call_with_vars(&block)
            block.call_with_mapped_params do |name|
                new(name)
            end
        end
    end

    attr :name, :constraint

    def initialize(name, constraint=Expr)
        @name = name.to_sym
        @constraint = constraint
    end

    def inspect
        if constraint == Expr
            name.to_s
        else
            "#{name} ∈ #{constraint.inspect}"
        end
    end

    def hash
        [name, constraint].hash
    end

    def eql?(x)
        x.is_a?(Variable) && name.eql?(x.name) && constraint.eql?(x.constraint)
    end

    def free_variables
        Set[self].freeze
    end

    def matches?(expr, vars={})
        if x = vars[self]
            # this variable has a constraint, expr must satisfy it
            if x.is_a? Expr
                x.matches?(expr, vars)
            else
                vars.merge(self => expr) if x === expr && constraint === expr
            end
        else
            # this is a free variable, so it must match exactly
            eql?(expr)
        end
    end
end

def vars(*names, &block)
    if block
        names.empty? or raise ArgumentError, "Cannot combine argument and block form of #vars"
        Variable.call_with_vars(&block)
    else
        Variable[*names]
    end
end

class Function
    include Expr

    attr :name, :params, :expr

    def initialize(name, params, expr)
        @name = (name || :λ).to_sym
        @params = params.to_a.freeze
        @expr = expr
        @params.empty? and raise ArgumentError, "Empty parameter list"
        @params.each{|p| p.is_a?(Variable) or raise ArgumentError, "#{p} is not a variable" }
    end

    class << self
        def [](x)
            if x.is_a? Function
                x
            elsif x.is_a? Expr
                vars = x.free_variables
                if vars.empty?
                    x
                elsif vars.size == 1
                    new(nil, vars, x)
                else
                    raise ArgumentError, "Multiple free variables in expression: #{vars.map(&:inspect).join(', ')}"
                end
            end
        end
    end

    def inspect
        "#{name}(#{params.map(&:inspect).join(', ')}) = #{expr.inspect}"
    end

    def inspect_latex
        "#{name}(#{params.map(&:inspect_latex).join(', ')}) = #{Latex.render(expr)}"
    end

    def hash
        [name, params, expr].hash
    end

    def eql?(x)
        x.is_a?(Function) && params.eql?(x.params) && expr.eql?(x.expr)
    end

    def free_variables
        expr.free_variables - params
    end

    def [](*args)
        if args.empty?
            self
        elsif args.size > params.size
            raise ArgumentError, "wrong number of arguments (given #{args.size}, expected #{params.size})"
        else
            args = args.map{|arg| Expr[arg] }
            ex = expr.rewrite(params.zip(args).mash).simplify
            if args.size < params.size
                self.class.new(nil, params[args.size..-1], ex)
            else
                ex
            end
        end
    end

    def to_proc
        proc do |*args|
            self[*args]
        end
    end
end

def func(name=nil, &block)
    params = block.map_params{|var| Variable.new(var) }
    if params.empty?
        block[]
    else
        Function.new(name, params, block[*params])
    end
end
