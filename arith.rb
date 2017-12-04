require_relative 'ext'
require_relative 'expr'

module Arithmetic
    class Add
        include Operation

        attr_const precedence: 10

        # defop(:+, 0, Expr) {|_, x| x }
        # defop(:+, Expr, 0) {|x, _| x }
        #
        # defop(:+, Literal, Literal) {|x, y| x.value + y.value }

        # donk((a + b) + c, a + (b + c))
        #
        # donk([Expr + Literal] + Literal) do |(a, b), c|
        #     a + (b + c)
        # end

        # defop(:+, Add, Add)  {|x, y| [*x.args, *y.args].reduce(&:+) }
        # defop(:+, Add, Expr) {|x, y| Add[*x.args, y] }
        # defop(:+, Expr, Add) {|x, y| Add[x, *y.args] }

        handleop(:+, Expr, Expr)

        defop(:-, Expr, Expr) {|x, y| x + -y }

        Expr.rules do
            x, y, z = vars('x y z')
            a, b = vars(a: Literal, b: Literal)

            rewrite(
                x + 0 => x,
                0 + x => x,
                (x + y) + z => x + (y + z),
            )

            process(a + b) {|a, b| a.value + b.value }
            process(a + (b + x)) {|a, b, x| (a.value + b.value) + x }
        end

        # class << self
        #     def create(*args)
        #         terms = []
        #         args.flat_map do |arg|
        #             if arg.is_a? Add
        #                 arg.args
        #             else
        #                 [arg]
        #             end
        #         end.each do |x|
        #             if x.zero?
        #                 next
        #             elsif x.is_a?(Literal) && terms[-1].is_a?(Literal)
        #                 terms[-1] = Expr[terms[-1].value + x.value]
        #             else
        #                 terms << x
        #             end
        #         end
        #         case terms.size
        #             when 0
        #                 0
        #             when 1
        #                 terms[0]
        #             else
        #                 super(*terms)
        #         end
        #     end
        # end

        # def create(*args)
        #     args.reduce(&:+)
        # end

        def inspect
            h, *t = args
            s = h.inspect
            t.each do |x|
                if x.is_a?(Literal) && x.negative?
                    s << " - #{-x}"
                elsif x.is_a?(Mul) && x.args[0] == -1
                    s << " - #{inspect_child(x, start: 1)}"
                else
                    s << " + #{inspect_child(x)}"
                end
            end
            s
        end
    end

    class Mul
        include Operation

        attr_const precedence: 20

        # defop(:*, 0, Expr) { 0 }
        # defop(:*, Expr, 0) { 0 }
        # defop(:*, 1, Expr) {|_, x| x }
        # defop(:*, Expr, 1) {|x, _| x }
        #
        # defop(:*, Literal, Literal) {|x, y| x.value * y.value }
        #
        # defop(:*, Mul, Expr) {|x, y| Mul[*x.args, y] }
        # defop(:*, Expr, Mul) {|x, y| Mul[x, *y.args] }

        handleop :*, Expr, Expr

        defop(:+@, Expr) {|x| x }
        defop(:-@, Expr) {|x| -1 * x }

        Expr.rules do
            x, y, z = vars('x y z')
            a, b = vars(a: Literal, b: Literal)

            rewrite(
                # 0/1 identities
                0 * x => 0,
                x * 0 => 0,
                x * 1 => x,
                1 * x => x,

                # normalize tree
                (x * y) * z => x * (y * z),

                # distribute over addition
                x * (y + z) => (x * y) + (x * z),
                (x + y) * z => (x * z) + (y * z),
            )

            # collapse literals
            process(a * b) {|a, b| a.value * b.value }
            process(a * (b * x)) {|a, b, x| (a.value * b.value) * x }
        end

        # def create(*args)
        #     args.reduce(&:*)
        # end

        def inspect(start: 0)
            if args[start] == -1
                "-#{inspect(start: start+1)}"
            else
                args[start..-1].map{|x| inspect_child(x) }.join(' × ')
            end
        end
    end
end
