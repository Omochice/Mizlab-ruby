# frozen_string_literal: true

require_relative "mizlab/version"
require "set"
require "bio"
require "stringio"
require "open3"
require "rexml/document"

module Mizlab
  class << self
    # Get entry as String. You can also give a block.
    # @param  [String/Array] accessions Accession numbers like ["NC_012920", ...].
    # @return [String] Entry as string.
    # @yield  [String] Entry as string.
    def getent(accessions, is_protein = false)
      accessions = accessions.is_a?(String) ? [accessions] : accessions
      accessions.each do |acc|
        ret = is_protein ? fetch_protein(acc) : fetch_nucleotide(acc)
        if block_given?
          yield ret
        else
          return ret
        end
        sleep(0.37) # Using 0.333... seconds, sometimes hit the NCBI rate limit
      end
    end

    # Fetch data via genbank. You can also give a block.
    # @param  [String/Array] accessions Accession numbers Like ["NC_012920", ...].
    # @param  [Bool] is_protein wheather the accession is protein. Default to true.
    # @return [Bio::GenBank] GenBank object.
    # @yield  [Bio::GenBank] GenBank object.
    def getobj(accessions, is_protein = false)
      getent(accessions, is_protein) do |entry|
        parse(entry) do |o|
          if block_given?
            yield o
          else
            return o
          end
        end
      end
    end

    # Save object.
    # @param  [String] filename Filepath from executed source.
    # @param  [Bio::DB] obj Object which inherits from `Bio::DB`.
    # @return [nil]
    def savefile(filename, obj)
      if File.exists?(filename)
        yes = Set.new(["N", "n", "no"])
        no = Set.new(["Y", "y", "yes"])
        loop do
          print("#{filename} exists already. Overwrite? [y/n] ")
          inputed = gets.rstrip
          if yes.include?(inputed)
            return
          elsif no.include?(inputed)
            break
          end
          puts("You should input 'y' or 'n'")
        end
      end
      File.open(filename, "w") do |f|
        obj.tags.each do |t|
          f.puts(obj.get(t))
        end
      end
    end

    # Calculate coordinates from sequence
    # @param  [Bio::Sequence] sequence sequence
    # @param  [Hash] mappings Hash formated {String => [Float...]}. All of [Float...] must be have same dimention.
    # @param  [Hash] weights Weights for some base combination.
    # @param  [Integer] window_size Size of window when scanning sequence. If not give this, will use `mappings.keys[0].length -1`.
    # @return [Array] coordinates like [[dim1...], [dim2...]...].
    def calculate_coordinates(sequence, mappings,
                              weights = nil, window_size = nil)
      # error detections
      if weights.is_a?(Hash) && window_size.nil?
        keys = weights.keys
        expect_window_size = keys[0].length
        if keys.any? { |k| k.length != expect_window_size }
          raise TypeError, "When not give `window_size`, `weights` must have same length keys"
        end
      end
      n_dimention = mappings.values[0].length
      if mappings.values.any? { |v| v.length != n_dimention }
        raise TypeError, "All of `mappings`.values must have same size"
      end

      mappings.each do |k, v|
        mappings[k] = v.map(&:to_f)
      end

      window_size = (if window_size.nil?
        unless weights.nil?
          weights.keys[0].length
        else
          3 # default
        end
      else
        window_size
      end)
      window_size -= 1
      weights = weights.nil? ? {} : weights
      weights.default = 1.0
      coordinates = Array.new(n_dimention) { [0.0] }
      sequence.length.times do |idx|
        start = idx < window_size ? 0 : idx - window_size
        vector = mappings[sequence[idx]].map { |v| v * weights[sequence[start..idx]] }
        vector.each_with_index do |v, j|
          coordinates[j].append(coordinates[j][-1] + v)
        end
      end
      return coordinates
    end

    # Compute local patterns from coordinates.
    # @param  [Array] x_coordinates Coordinates on x dimention.
    # @param  [Array] y_coordinates Coordinates on y dimention.
    # @return [Array] Local pattern histgram (unnormalized).
    def local_patterns(x_coordinates, y_coordinates)
      length = x_coordinates.length
      if length != y_coordinates.length
        raise TypeError, "The arguments must have same length."
      end

      filled_pixs = Set.new
      x_coordinates[...-1].zip(y_coordinates[...-1],
                               x_coordinates[1...],
                               y_coordinates[1...]) do |x_start, y_start, x_end, y_end|
        bresenham(x_start.truncate, y_start.truncate,
                  x_end.truncate, y_end.truncate).each do |pix|
          filled_pixs.add("#{pix[0]}##{pix[1]}")
          # NOTE:
          # In set or hash, if including array make it so slow.
          # Prevend it by converting array into symbol or freezed string.
        end
      end

      local_pattern_list = [0] * 512
      get_patterns(filled_pixs) do |pattern|
        local_pattern_list[pattern] += 1
      end
      return local_pattern_list
    end

    # Fetch Taxonomy information from Taxonomy ID. can be give block too.
    # @param  [String/Integer] taxonid Taxonomy ID, or Array of its.
    # @return [Hash] Taxonomy informations.
    # @yield  [Hash] Taxonomy informations.
    def fetch_taxon(taxonid)
      taxonid = taxonid.is_a?(Array) ? taxonid : [taxonid]
      taxonid.each do |id|
        obj = Bio::NCBI::REST::EFetch.taxonomy(id, "xml")
        hashed = xml_to_hash(REXML::Document.new(obj).root)
        if block_given?
          yield hashed[:TaxaSet][:Taxon][:LineageEx][:Taxon]
        else
          return hashed[:TaxaSet][:Taxon][:LineageEx][:Taxon]
        end
      end
    end

    private

    def fetch_protein(accession)
      return Bio::NCBI::REST::EFetch.protein(accession)
    end

    def fetch_nucleotide(accession)
      return Bio::NCBI::REST::EFetch.nucleotide(accession)
    end

    # get patterns from filled pixs.
    # @param [Set] filleds Filled pix's coordinates.
    # @yield [Integer] Pattern that shown as binary
    def get_patterns(filleds)
      unless filleds.is_a?(Set)
        raise TypeError, "The argument must be Set"
      end

      centers = Set.new
      filleds.each do |focused|
        x, y = focused.split("#").map(&:to_i)
        get_centers(x, y) do |center|
          if centers.include?(center)
            next
          end
          centers.add(center)
          binary = ""
          x, y = center.split("#").map(&:to_i)
          -1.upto(1) do |dy|
            1.downto(-1) do |dx|
              binary += filleds.include?("#{x + dx}##{y + dy}") ? "1" : "0"
            end
          end
          yield binary.to_i(2)
        end
      end
    end

    # get center coordinates of all window that include focused pixel
    # @param [Integer] focused_x Coordinate of focused pixel on x dimention
    # @param [Integer] focused_y Coordinate of focused pixel on y dimention
    # @yield [String] Center coordinates of all window as string
    def get_centers(focused_x, focused_y)
      -1.upto(1) do |dy|
        1.downto(-1) do |dx|
          yield "#{focused_x + dx}##{focused_y + dy}"
        end
      end
    end

    # Compute fill pixels by bresenham algorithm
    # @param  [Interger] x0 the start point on x.
    # @param  [Interger] y0 the start point on y.
    # @param  [Interger] x1 the end point on x.
    # @param  [Interger] x1 the end point on y.
    # @return [Array] Filled pixels
    # ref https://aidiary.hatenablog.com/entry/20050402/1251514618 (japanese)
    def bresenham(x0, y0, x1, y1)
      if ![x0, y0, x1, y1].all? { |v| v.is_a?(Integer) }
        raise TypeError, "All of arguments must be Integer"
      end

      dx = x1 - x0
      dy = y1 - y0
      step_x = dx.positive? ? 1 : -1
      step_y = dy.positive? ? 1 : -1
      dx, dy = [dx, dy].map { |x| (x * 2).abs }

      lines = [[x0, y0]]

      if dx > dy
        fraction = dy - dx / 2
        while x0 != x1
          if fraction >= 0
            y0 += step_y
            fraction -= dx
          end
          x0 += step_x
          fraction += dy
          lines << [x0, y0]
        end
      else
        fraction = dx - dy / 2
        while y0 != y1
          if fraction >= 0
            x0 += step_x
            fraction -= dx
          end
          y0 += step_y
          fraction += dx
          lines << [x0, y0]
        end
      end
      return lines
    end

    # Parse fetched data.
    # @param  [String] entries Entries as string
    # @yield  [Object] Object that match entry format.
    def parse(entries)
      Bio::FlatFile.auto(StringIO.new(entries)).each_entry do |e|
        yield e
      end
    end

    # Convert XML to Hash.
    # @param  [REXML::Document] element XML object.
    # @return [Hash] Hash that converted from xml.
    def xml_to_hash(element)
      value = (if element.has_elements?
        children = {}
        element.each_element do |e|
          children.merge!(xml_to_hash(e)) { |k, v1, v2| v1.is_a?(Array) ? v1 << v2 : [v1, v2] }
        end
        children
      else
        element.text
      end)
      return { element.name.to_sym => value }
    end
  end

  class Blast < Bio::Blast
    # Execute blast+
    # @param  [Bio::Sequence, Bio::Sequence::NA, Bio::Sequence::AA] q Query sequence
    # @param  [Hash] opts commandline arguments optionaly
    # @return [Bio::Blast::Report] Result for blast+
    def query(q, opts = {})
      # NOTE: I dont use **kwargs for compatibility
      case q
      when Bio::Sequence
        q = q.output(:fasta)
      when Bio::Sequence::NA, Bio::Sequence::AA, Bio::Sequence::Generic
        q = q.to_fasta("query", 70)
      else
        q = q.to_s
      end
      stdout, _ = exec_local(q, opts)
      return parse_result(stdout)
    end

    private

    # Execute blast on local
    # @param  [string] query_string Query string, fasta etc
    # @param  [Hash] opts commandline arguments optionaly
    # @return [Array] Array [stdout, stderr] as string
    # TODO: compatibility with original
    def exec_local(query_string, opts = {})
      # NOTE: I dont use **kwargs for compatibility
      cmd = []
      cmd << @program if @program
      cmd += ["-db", @db] if @program
      cmd += ["-outfmt", "5"]
      opts.each do |kv|
        cmd += kv.map(&:to_s)
      end
      return execute_command(cmd, stdin: query_string)
    end

    # Execute command on shell
    # @param  [Array] cmd Array of command strings that splited by white space
    # @param  [String] stdin String of stdin
    # @return [Array] String of stdout and stderr
    # @raise  [IOError] Command finished without status 0
    def execute_command(cmd, stdin)
      stdout, stderr, status = Open3.capture3(cmd.join(" "), stdin_data: stdin)
      raise IOError, stderr unless status == 0
      return [stdout, stderr]
    end
  end
end
