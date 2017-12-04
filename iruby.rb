
$RELOADABLE ||= []

if defined?(IRB) || defined?(IRuby)
    def interactive?
        true
    end

    def make_reloadable(file)
        $RELOADABLE << File.absolute_path(file)
    end

    def reload!
        $VERBOSE_OLD = $VERBOSE
        $VERBOSE = nil

        $RELOADABLE.each do |file|
            dir = File.dirname(file)
            $LOADED_FEATURES.delete_if do |path|
                path.start_with? dir
            end
        end

        $RELOADABLE.each do |file|
            require file
        end
        nil
    ensure
        $VERBOSE = $VERBOSE_OLD
    end

    def show(*things)
        things.each do |thing|
            IRuby.display(Latex.show(thing))
        end
        nil
    end
else
    def interactive?
        false
    end
end
