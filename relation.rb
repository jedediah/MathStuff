require_relative 'expr'
require_relative 'logic'

module Relation
    class Equals
        include InfixOp
        include Logic::Predicate

        # handleop :==, Object, Object
        # handleop :===, Object, Object
        handleop :=~, Object, Object

        def name
            '='
        end

        module ObjectExt
            def eq(a, b)
                Equals.new(a, b)
            end
        end

        Object.__send__(:include, ObjectExt)
    end
end
