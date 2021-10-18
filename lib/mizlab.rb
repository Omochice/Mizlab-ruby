# frozen_string_literal: true

require_relative "mizlab/version"

module Mizlab
  class Error < StandardError; end

  def local_patterns(x_coordinates, y_coordinates)
  end

  def bresenham(x0, y0, x1, y1)
    if !x0.is_a?(Integer) || !y0.is_a?(Integer) || !x1.is_a?(Integer) || !y1.is_a?(Integer)
      raise TypeError, 'All of arguments must be Integer'
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

  module_function :bresenham
end
