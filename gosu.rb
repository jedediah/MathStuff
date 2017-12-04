require 'gosu'

class Gosu::Color
    class << self
        def wavelength(wl)
            wl = wl.to_f
            if wl < 380 # ultraviolet
                r = 0
                g = 0
                b = 1
            elsif wl < 440 # blue - violet
                r = (440 - wl) / (440 - 380)
                g = 0
                b = 1
            elsif wl < 490 # cyan - blue
                r = 0
                g = (wl - 440) / (490 - 440)
                b = 1
            elsif wl < 510 # green - cyan
                r = 0
                g = 1
                b = (510 - wl) / (510 - 490)
            elsif wl < 580 # yellow - green
                r = (wl - 510) / (580 - 510)
                g = 1
                b = 0
            elsif wl < 645 # red - yellow
                r = 1
                g = (645 - wl) / (645 - 580)
                b = 0
            else # infrared
                r = 1
                g = 0
                b = 0
            end
            argb(255, r * 255, g * 255, b * 255)
        end
    end
end
