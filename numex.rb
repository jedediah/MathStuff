require 'active_support/concern'

require_relative 'math'

module Numex
    extend ActiveSupport::Concern

    module RightOperators
        def right_operator_name(op)
            :"__right_#{op}"
        end

        def right_operator(op, &body)
            define_method(right_operator_name(op), &body)
        end
    end

    class << self
        include RightOperators
    end

    class_methods do
        include RightOperators
    end

    right_operator :<=> do |a|
        -(self <=> a)
    end

    right_operator :+ do |a|
        self + a
    end

    right_operator :- do |a|
        (-self).__send__(:'__right_+', a)
    end

    right_operator :* do |a|
        self * a
    end

    right_operator :/ do |a|
        (self**(-1)).__send__(:'__right_/', a)
    end

    module NumericExt
        %i[<=> + - * / **].each do |op|
            rop = Numex.right_operator_name(op)
            define_method op do |b|
                if b.respond_to? rop
                    b.__send__(rop, self)
                else
                    super(b)
                end
            end
        end

        %i[< <= > >=].each do |op|
            define_method op do |b|
                if b.respond_to? :"__right_<=>"
                    b.__send__(:"__right_<=>", self).__send__(op, 0)
                else
                    super(b)
                end
            end
        end
    end
end

# [Fixnum, Bignum, Rational, Complex, Float].each do |cls|
#     cls.class_eval do
#         prepend Numex::NumericExt
#     end
# end
