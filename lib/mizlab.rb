# frozen_string_literal: true

require_relative "mizlab/version"
require "set"
require "bio"

module Mizlab
  class << self
    # Fetch data via genbank
    # @param  [String] accession Accession number Like "NC_012920"
    # @param  [Bool] is_protein wheather the accession is protein. Default to true.
    # @return [Bio::GenBank] GenBank object
    def getobj(accession, is_protein = false)
      ret = is_protein ? fetch_protein(accession) : fetch_nucleotide(accession)
      parse(ret) do |o|
        return o
      end
    end

    # Fetch multiple data via genbank
    # @param  [Array] accessions Array of accession string
    # @param  [Bool] is_protein wheather the accession is protein. Default to true.
    # @yield  [Bio::GenBank] GenBank object
    def getobjs(accessions, is_protein = false)
      ret = is_protein ? fetch_protein(accessions) : fetch_nucleotide(accessions)
      parse(ret) do |o|
        yield o
      end
    end

    # Compute local patterns from coordinates.
    # @param  [Array] x_coordinates coordinates on x.
    # @param  [Array] y_coordinates coordinates on y.
    # @return [Array] Local pattern histgram (unnormalized).
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

    def fetch_protein(accession)
      return Bio::NCBI::REST::EFetch.protein(accession)
    end

    def fetch_nucleotide(accession)
      return Bio::NCBI::REST::EFetch.protein(accession)
    end

    # get patterns from filled pixs.
    # @param [Set] filleds filled pix's coordinates
    # @yield [binaries] Array like [t, f, t...]
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

    # get center coordinates of all window that include focused pixel
    # @param  [Array] focused coordinate of focused pixel
    # @yield [Array] center coordinates of all window
    def get_centers(focused)
      -1.upto(1) do |dy|
        1.downto(-1) do |dx|
          yield [focused[0] + dx, focused[1] + dy]
        end
      end
    end

    # Convert binary array to interger
    # @param  [Array] binaries Array of binaries
    # @return [Integer] converted integer
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

    # Compute fill pixels by bresenham algorithm
    # @param  [Interger] x0 the start point on x.
    # @param  [Interger] y0 the start point on y.
    # @param  [Interger] x1 the end point on x.
    # @param  [Interger] x1 the end point on y.
    # @return [Array] filled pixels
    def bresenham(x0, y0, x1, y1)
      if ![x0, y0, x1, y1].all? { |v| v.is_a?(Integer) }
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

    # Parse fetched data.
    # @param  [String] entries Entries as string
    # @yield  [Object] Object that match entry format.
    def parse(entries)
      tmp_file_name = ".mizlab_fetch_tmpfile"
      File.open(tmp_file_name, "w") do |f|
        f.puts entries
      end
      Bio::FlatFile.auto(tmp_file_name).each_entry do |e|
        yield e
      end
      File.delete(tmp_file_name)
    end
  end
end
