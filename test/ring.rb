require 'minitest/autorun'
require_relative '../ring'
require_relative '../eisenstein'

describe Ring do
    [Integer, Eisenstein].each do |ring|
        ring.prefix(5).each do |g|
            # fak this
            c = a*x + b*y
            it "#{a}*#{x} + #{b}*#{y} = #{c}" do
                c0, a0, b0, u, v = ring.gcd_ex(x, y)
                assert_equal a, a0
                assert_equal b, b0
                assert_equal c, c0
                assert ring.associated?(x, u*c)
                assert ring.associated?(y, v*c)
            end
        end
    end

    # {
    #     Integer => [
    #         [240, 46],
    #         [46, 240],
    #         [-240, 46],
    #         [240, -46],
    #         [-240, -46],
    #         [0, 0],
    #         [0, 1],
    #         [1, 0],
    #         [1, 1],
    #         [-1, 0],
    #         [0, -1],
    #         [-1, 1],
    #         [65537, 1001],
    #     ],
    #     Eisenstein => [
    #         [Eisenstein[240, 1], Eisenstein[46, 1]]
    #     ]
    # }.each do |ring, cases|
    #     cases.each do |x, y|
    #         it "#{ring}.gcd_ex(#{x}, #{y})" do
    #             c, a, b, u, v = ring.gcd_ex(x, y)
    #             c == a*x + b*y or fail "#{a}*#{x} + #{b}*#{y} == #{a*x + b*y} != #{c}"
    #             [[x,u], [y,v]].each do |p,q|
    #                 ring.associated?(p, q*c) or fail "|#{q}*#{c}| == |#{(q*c).abs}| != |#{p}|"
    #             end
    #         end
    #     end
    # end
end
