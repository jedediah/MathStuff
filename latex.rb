require 'iruby/formatter'
require 'set'

module Latex
    extend self

    def test(tex)
        Object.new_singleton do
            define_method :to_latex do
                "$$ #{tex} $$"
            end
        end
    end

    def show(obj)
        if obj.respond_to? :to_latex
            obj
        else
            test(render(obj))
        end
    end

    def render(x)
        if x.respond_to? :inspect_latex
            x.inspect_latex
        elsif x.respond_to? :to_latex
            x.to_latex.sub(/^\$\$?/, '').sub(/\$?\$$/, '')
        elsif x.respond_to? :to_hash
            mapping(x.to_hash.mash{|k, v| [render(k), render(v)] })
        elsif x.respond_to? :each
            list(x.map{|y| render(y) })
        elsif x.is_a? Symbol
            quote(x.to_s)
        else
            verbatim(x.inspect)
        end
    end

    def quote(x)
        x.to_s
            .gsub(/\\/, '\\backslash ')
            .gsub(/([_{}$])/) {|m| "\\#{m}" }
    end

    def verbatim(x)
        "\\verb\u0000#{x.gsub(/\u0000/, '').gsub(/\$/, "\uff04")}\u0000"
    end

    def paren(x)
        "\\left(#{x}\\right)"
    end

    def root(n, x)
        if n == 2
            "\\sqrt{#{x}}"
        else
            "\\sqrt[#{n}]{#{x}}"
        end
    end

    def sequence(elements, wrap: nil, join: '')
        elements = elements.to_a
        cols = 'c' * elements.size
        row = elements.to_a.join("#{join} & ")
        s = ''
        s << "\\left#{wrap[0]}" if wrap
        s << "\\begin{array}{#{cols}} #{row} \\end{array}"
        s << "\\right#{wrap[1]}" if wrap
    end

    def set(elements, join: ',')
        sequence(elements, wrap: ['\\{','\\}'], join: join)
    end

    def set_builder(expr, pred)
        "\\left\\{ #{expr} \\mid #{pred} \\right\\}"
    end

    def list(a)
        sequence(a, wrap: ['[',']'], join: ',')
    end

    def tuple(a)
        sequence(a, wrap: ['(',')'], join: ',')
    end

    def vector(v)
        sequence(v, wrap: ['(',')'])
    end

    def mapping(m)
        sequence(m.map{|k, v| "#{k} \\mapsto #{v}" }, wrap: ['\\{', '\\}'], join: ', ')
    end

    def table(rows=nil, cols=nil, wrap: ['',''], border: true, &block)
        s = "#{wrap[0]}\\begin{array}{#{"#{'|' if border}c" * cols}#{'|' if border}}\n"
        (0...rows).each do |i|
            s << "\\hline\n" if border
            s << '  ' << block[i,0].to_s
            (1...cols).each do |j|
                s << '&' << block[i,j].to_s
            end
            s << "\\\\\n"
        end
        s << "\\hline\n" if border
        s << "\\end{array}#{wrap[1]}"
    end

    def matrix(rows=nil, cols=nil, &block)
        table(rows, cols, wrap: ['\\left[', '\\right]'], border: false, &block)
    end

    module Inspectable
        def to_latex
            "$$#{inspect_latex}$$"
        end

        def inspect_latex
            inspect
        end

        def self.create(&block)
            o = Object.new
            o.extend Inspectable
            o.define_singleton_method(:inspect_latex, &block)
            o
        end
    end
end

