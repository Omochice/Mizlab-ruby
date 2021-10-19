# frozen_string_literal: true

require_relative "mizlab/version"
require "set"

module Mizlab
  class << self
    def local_patterns(x_coordinates, y_coordinates)
      length = x_coordinates.length
      if length != y_coordinates.length
        raise TypeError, "The arguments must have same length."
      end

      filled_pixs = Set.new
      0.upto(length - 2) do |idx|
        filled_pixs += bresenham(x_coordinates[idx].truncate, y_coordinates[idx].truncate,
                                 x_coordinates[idx + 1].truncate, y_coordinates[idx + 1].truncate)
      end

      local_pattern_list = [0] * 512
      get_patterns(filled_pixs) do |pix|
        local_pattern_list[convert(pix)] += 1
      end
      return local_pattern_list
    end

    private

    def get_patterns(filleds)
      unless filleds.is_a?(Set)
        raise TypeError, "The argument must be Set"
      end

      centers = Set.new()
      filleds.each do |focused|
        get_centers(focused) do |center|
          if centers.include?(center)
            next
          end
          centers.add(center)
          binaries = []
          -1.upto(1) do |dy|
            1.downto(-1) do |dx|
              binaries.append(filleds.include?([center[0] + dx, center[1] + dy]))
            end
          end
          yield binaries
        end
      end
    end
    def get_centers(focused)
      -1.upto(1) do |dy|
        1.downto(-1) do |dx|
          yield [focused[0] + dx, focused[1] + dy]
        end
      end
    end

    def convert(binaries)
      unless binaries.all? { |v| v.is_a?(TrueClass) || v.is_a?(FalseClass) }
        raise TypeError, "The argument must be Boolean"
      end
      rst = 0
      binaries.reverse.each_with_index do |b, i|
        if b
          rst += 2 ** i
        end
      end
      return rst
    end

    def bresenham(x0, y0, x1, y1)
      if !x0.is_a?(Integer) || !y0.is_a?(Integer) || !x1.is_a?(Integer) || !y1.is_a?(Integer)
        raise TypeError, "All of arguments must be Integer"
      end
      dx = (x1 - x0).abs
      dy = (y1 - y0).abs
      sx = x0 < x1 ? 1 : -1
      sy = y0 < y1 ? 1 : -1
      err = dx - dy
      lines = []
      while true
        lines.append([x0, y0])
        if (x0 == x1 && y0 == y1)
          break
        end
        e2 = 2 * err
        if e2 > -dy
          err = err - dy
          x0 = x0 + sx
        end
        if e2 < dx
          err = err + dx
          y0 = y0 + sy
        end
      end
      return lines
    end
  end
end
