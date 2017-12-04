require_relative 'ext'
require_relative 'expr'
require_relative 'set'

module Logic
    class << self
        def quantify(op, &block)
            formula, *vars = Variable.call_with_vars(&block)
            vars.reverse_each do |var|
                formula = op.new(var, formula)
            end
            formula
        end

        def any?(&block)
            quantify(ThereExists, &block)
        end

        def all?(&block)
            quantify(ForAll, &block)
        end
    end

    module Formula
        include Expr

        class << self
            def coerce(*xs)
                xs.map do |x|
                    if x.is_a? Formula
                        x
                    else
                        raise TypeError, "#{x} is not a logical formula"
                    end
                end
            end
        end

        def ~
            Not.new(self)
        end

        def &(x)
            And.new(self, x)
        end

        def |(x)
            Or.new(self, x)
        end

        def ^(x)
            Xor.new(self, x)
        end

        def >>(x)
            Implies.new(self, x)
        end

        def <<(x)
            Implies.new(x, self)
        end

        def ==(x)
            Equivalent.new(self, x)
        end
    end

    module Predicate
        include Formula
        # include Operation
        #
        # attr :name, :args
        #
        # def initialize(name, *args)
        #     @name = name.to_sym
        #     @args = args.freeze
        # end
        #
        # def eql?(x)
        #     x.is_a?(Predicate) && name == x.name && args == x.args
        # end
    end

    class Quantifier
        include Operation
        include Formula

        attr :variable

        def initialize(variable, arg)
            @variable = variable
            super(arg)
        end

        def inspect
            "#{name} #{variable.inspect} | #{args[0].inspect}"
        end

        def inspect_latex
            "#{name_latex} #{variable.inspect_latex} \\mid #{args[0].inspect_latex}"
        end

        def eql?(x)
            x.is_a?(Quantifier) && name == x.name && variable == x.variable && args[0] == x.args[0]
        end

        def free_variables
            args[0].free_variables.without(variable)
        end
    end

    class ThereExists < Quantifier
        attr_const name: '∃',
                   name_latex: '\\exists'
    end

    class ForAll < Quantifier
        attr_const name: '∀',
                   name_latex: '\\forall'
    end

    class Not
        include PrefixOp
        include Formula

        attr_const name: '¬',
                   name_latex: '\\neg'

        handleop :~, Formula
    end

    class And
        include InfixOp
        include Formula

        attr_const name: '∧',
                   name_latex: '\\wedge'

        handleop :&, Formula, Formula
    end

    class Or
        include InfixOp
        include Formula
        attr_const name: '∨',
                   name_latex: '\\vee'
    end

    class Xor
        include InfixOp
        include Formula
        attr_const name: '⊕',
                   name_latex: '\\oplus'
    end

    class Implies
        include InfixOp
        include Formula
        attr_const name: '⇒',
                   name_latex: '\\Rightarrow'
    end

    class Equivalent
        include InfixOp
        include Formula
        attr_const name: '⇔',
                   name_latex: '\\Leftrightarrow'
    end
end
