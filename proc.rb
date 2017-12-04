
class Proc
    include Latex::Inspectable

    class << self
        def predicate(p=nil, &b)
            p ||= b #TODO
            p.nil? and raise "Predicate expected"
            p
        end

        def unary(f=nil, &b)
            f ||= b
            f.nil? and raise "Unary function expected"
            f
        end
    end

    def inspect_domain_latex
        p = parameters.map{|_, s| Latex.quote(s) }
        case p.size
            when 0
                '\\varnothing'
            when 1
                p[0]
            else
                "(#{p.join(', ')})"
        end
    end

    def inspect_latex
        "f(#{parameters.map{|_, s| Latex.quote(s) }.join(', ')})"
    end

    def invertible?
        false
    end

    def inverse
        raise NotImplementedError
    end

    def ~@
        proc{|x| !self[x] }
    end

    def &(p)
        proc{|x| self[x] && p[x] }
    end

    def |(p)
        proc{|x| self[x] || p[x] }
    end

    def ^(p)
        proc{|x| self[x] ^ p[x] }
    end
end
