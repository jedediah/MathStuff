require_relative 'expr'

# Combine a and b using op{k}, the kth "hyperization" of op i.e.
#   a                           if b = 1
#   a op b                      if k = 0
#   a op{k-1} (a op{k} (b-1))   if k > 0
#
# If k is omitted, then k = b, giving the "limit" of op i.e.
#   a op{b} b
def successor(a, b, k=b, n=1, &op)
    if b == 1
        a
    elsif k == 1
        op[a, b]
    elsif n == 1
        successor(a, successor(a, b-1, k, 1, &op), k-1, 1, &op)
    else
        successor(a, b, b, n-1) do |x, y|
            successor(x, y, k-1, n, &op)
        end
    end
end

# Combine a and b using the kth hyperoperation e.g.
#   a + b           if k = 0
#   a * b           if k = 1
#   a ^{k-1} b      if k > 1 (see https://en.wikipedia.org/wiki/Knuth%27s_up-arrow_notation)
#
# If k is omitted, then k = b, giving
#   a ^{b-1} b
#
# a *{k} b
def hyper_k(a, b, k=b)
    successor(a, b, k) do |x, y|
        x + y
    end
end

# a *{n} b
def hyper_n(a, b)
    hyper_k(a, b, b)
end

# a *{n+k} b
def hyper_n_plus_k(a, b, k=b)
    successor(a, b, k) do |x, y|
        hyper_n(x, y)
    end
end

# a *{kn} b
def hyper_kn(a, b, k=b)
    successor(a, b, k, 2) do |x, y|
        hyper_n(x, y)
    end
end

# a *{n^k} b
def hyper_n_up_k(a, b, k)
    successor(a, b, k, 3) do |x, y|
        hyper_n(x, y)
    end
end

def hyper_n_up_n(a, b)
    hyper_n_up_k(a, b, b)
end

def hyper_n_up2_k(a, b, k)
    successor(a, b, k, 4) do |x, y|
        hyper_n(x, y)
    end
end



# a *{2n} b
def hyper_2n(a, b)
    hyper_n_plus_k(a, b, b)
end

# a *{2n+k} b
def hyper_2n_plus_k(a, b, k=b)
    successor(a, b, k) do |x, y|
        hyper_2n(x, y)
    end
end

# a *{3n} b
def hyper_3n(a, b)
    hyper_2n_plus_k(a, b, b)
end

def hyper_3n_plus_k(a, b, k)
    successor(a, b, k) do |x, y|
        hyper_2n_plus_k(x, y, y)
    end
end

# a *{4n+k} b
def hyper_4n_plus_k(a, b, k)
    successor(a, b, k) do |x, y|
        hyper_3n_plus_k(x, y, y)
    end
end

# a *{5n+k} b
def hyper_5n_plus_k(a, b, k)
    successor(a, b, k) do |x, y|
        hyper_4n_plus_k(x, y, y)
    end
end

def hyper_6n(a, b)
    hyper_5n_plus_k(a, b, b)
end

# a *{6n+k} b
def hyper_6n_plus_k(a, b, k)
    successor(a, b, k) do |x, y|
        hyper_5n_plus_k(x, y, y)
    end
end

def hyper_n2(a, b)
    hyper_kn(a, b, b)
end

def hyper_n2_k(a, b, k)
    successor(a, b, k) do |x, y|
        hyper_n2(x, y)
    end
end

def hyper_2n2(a, b)
    hyper_n2_k(a, b, b)
end

def hyper_2n2_k(a, b, k)
    successor(a, b, k) do |x, y|
        hyper_2n2(x, y)
    end
end

def hyper_3n2(a, b)
    hyper_2n2_k(a, b, b)
end

def hyper_3n2_k(a, b, k)
    successor(a, b, k) do |x, y|
        hyper_3n2(x, y)
    end
end

def hyper_kn2(a, b, k)
    successor(a, b, k, 2) do |x, y|
        hyper_n2(x, y)
    end
end

def hyper_n3(a, b)
    hyper_kn2(a, b, b)
end

def hyper_kn3(a, b, k)
    successor(a, b, k, 2) do |x, y|
        hyper_n3(x, y)
    end
end

def hyper_n4(a, b)
    hyper_kn3(a, b, b)
end



def limit_kn(a, b)
    limit(a, b) do |x, y|
        limit_k(x, y)
    end
end

def succop(a, k, b, &op)
    if b.one?
        a
    elsif k.zero?
        op[a, b]
    else
        binary_pow(a, b) do |x, y|
            succop(x, k-1, y, &op)
        end
    end
end

def limitop(a, b, &op)
    if b.one?
        a
    else
        succop(a, b, b, &op)
    end
end

def succop_k(a, k, b)
    succop(a, k, b) do |x, y|
        x + y
    end
end

def limitop_k(a, b)
    limitop(a, b) do |x, y|
        x + y
    end
end

def succop_kn(a, k, b)
    succop(a, k, b) do |x, y|
        limitop_k(x, y)
    end
end

def limitop_kn(a, b)
    limitop(a, b) do |x, y|
        limitop_k(x, y)
    end
end

def succop_n_k(a, k, b)
    succop(a, k, b) do |x, y|
        limitop_kn(x, y)
    end
end

def limitop_n_k(a, b)
    limitop(a, b) do |x, y|
        limitop_kn(x, y)
    end
end


class Integer
    def hyperop(x, y)
        case self
            when 0
                x + y
            when 1
                x * y
            else
                negative? and raise ArgumentError, "Hyperoperation is undefined for negative index #{self}"

                if x.one?
                    y
                elsif y.one?
                    x
                else
                    binary_pow(x, y, 1) do |a, b|
                        (self-1).hyperop(a, b)
                    end
                end
        end
    end
end

module Hyperop
    class Base
        include Latex::Inspectable

        def inspect_latex
            "\\circ_{#{subscript}}"
        end

        def render(a, b)
            "#{Latex.render(a)} + #{Latex.render(b)}"
        end

        def successor
            Successor.new(self)
        end

        def limit
            Limit.new(self)
        end
    end

    class Primitive < Base
        def subscript
            '0'
        end

        def apply(a, b)
            a + b
        end

        def limit
            self
        end
    end

    class Limit < Base
        attr :op

        def initialize(op)
            @op = op
        end

        def subscript
            op.successor('n').subscript
        end

        def apply(a, b)
            op.successor(b).apply(a, b)
        end

        def limit
            self
        end

        def successor(n=1)
            Successor.new(self, n)
        end
    end

    class Successor < Base
        attr :op, :index

        def initialize(op, index)
            @op = op
            @index = index
        end

        def subscript
            "#{op.subscript} + #{index}"
        end

        def _apply(n, a, b)
            if a.zero? || b.zero?
                0
            elsif b.one?
                a
            elsif n.zero?
                op.apply(a, b)
            else
                _apply(n-1, a, _apply(n, a, b-1))
            end
        end

        def apply(a, b)
            _apply(index, a, b)
        end

        def successor(n=1)
            if n.zero?
                self
            else
                n = index + n
                if n.zero?
                    op
                else
                    Successor.new(op, index + n)
                end
            end
        end
    end

    P = Primitive.new
end
