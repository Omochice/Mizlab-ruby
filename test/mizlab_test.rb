# frozen_string_literal: true

require "test_helper"
require_relative "../lib/mizlab.rb"

class MizlabTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Mizlab::VERSION
  end

  def test_local_pattern
    # This function can accept coordinates as Integer.
    x_coo = [0, 2, 0, 2, 0, 2]
    y_coo = [0, 0, 1, 1, 2, 2]
    assert_equal 512, Mizlab.local_patterns(x_coo, y_coo).length

    # Float is OK too.
    x_coo = [0.5, 2.4]
    y_coo = [0.5, 2.4]
    assert_equal 512, Mizlab.local_patterns(x_coo, y_coo).length
  end

  def test_get_patterns
    # The argument must be Set
    assert_raises(TypeError, "The argument must be Set") do
      filleds = [[0, 0]]
      Mizlab.send(:get_patterns, filleds)
    end

    # simple case
    filleds = Set.new(["2#0", "2#1", "2#2",
                       "1#0", "1#1", "1#2",
                       "0#0", "0#1", "0#2"])
    actual = [0] * 512
    Mizlab.send(:get_patterns, filleds) do |pat|
      actual[pat] += 1
    end
    expecteds = [1, 3, 7, 6, 4,
                 9, 27, 63, 54, 36,
                 73, 219, 511, 438, 292,
                 72, 216, 504, 432, 288,
                 64, 192, 448, 384, 256]
    expecteds.each do |idx|
      assert_equal 1, actual[idx]
    end
  end

  def test_get_centers
    expecteds = Set.new(["2#0", "2#1", "2#2",
                       "1#0", "1#1", "1#2",
                       "0#0", "0#1", "0#2"])
    actuals = Set.new()
    Mizlab.send(:get_centers, 1, 1) do |c|
      actuals.add(c)
    end
    assert expecteds == actuals
  end

  def test_bresenham
    # The simple case.
    assert_equal [[0, 0], [1, 1], [2, 2], [3, 3]], Mizlab.send(:bresenham, 0, 0, 3, 3)

    # It is OK start < end also.
    assert Mizlab.send(:bresenham, 0, 0, 3, 3).to_set == Mizlab.send(:bresenham, 3, 3, 0, 0).to_set

    # If arguments have float value(s), the function must raise error.
    1.upto(4) do |n|
      [0, 1, 2, 3].combination(n) do |comb|
        args = [0, 0, 10, 10]
        comb.each do |idx|
          args[idx] = args[idx].to_f
        end
        assert_raises(TypeError, "All of arguments must be Integer") do
          Mizlab.send(:bresenham, *args)
        end
      end
    end
  end

  # def test_get # FIXME it is too defficult for me to write test for this method
  #     # p = MiniTest::Mock.ne
  #     # p.expect(:call, "hi", [])
  #     mock = ->_ { Bio::GenBank.new("") }
  #     mock_yield = ->t { t.times {} }
  #     Mizlab.stub(:parse, mock) do
  #       # If give an argument, return a value
  #       Mizlab.stub(:fetch_nucleotide, "") do
  #         # Because of stub, arg is meanless
  #         # assert_equal(Bio::GenBank.new(""), Mizlab.getobj("NC_012920")) # this would be failed
  #         assert(Mizlab.getobj("NC_012920").is_a?(Bio::GenBank))
  #       end
  #     end
  #     # p e.entry_id
  #     Mizlab.stub(:parse, mock_yield) do
  #       Mizlab.stub(:fetch_nucleotide, mock_yield[3]) do
  #         # If give 2 or than arguments, need block
  #         # assert_raises(LocalJumpError) do
  #         #    p Mizlab.getobj("NC_012920")
  #         # end
  #         Mizlab.getobj([nil] * 3) do |actual|
  #           # assert_equal(Bio::GenBank.new(""), actual) # This would be failed
  #           p actual
  #           assert(actual.is_a?(Bio::GenBank))
  #         end
  #       end
  #     end
  #   end

  def test_calculate_coordinates
    # minimal use
    seq = Bio::Sequence.auto("ATGC")
    mappings = { "a" => [1, 1], "t" => [-1, 1], "g" => [-1, -1], "c" => [1, -1] }
    assert_equal([[0.0, 1.0, 0.0, -1.0, 0.0], [0.0, 1.0, 2.0, 1.0, 0.0]],
                 Mizlab.calculate_coordinates(seq, mappings))

    # function should be able to use weigths
    # weights = { "a" => 0.5, "t" => 0.5, "g" => 0.5, "c" => 0.5 }
    weights = {}
    "atgc".split("").permutation(3) do |comb|
      weights[comb.join("")] = 0.5
    end
    assert_equal([[0.0, 1.0, 0.0, -0.5, 0.0], [0.0, 1.0, 2.0, 1.5, 1.0]],
                 Mizlab.calculate_coordinates(seq, mappings, weights = weights))

    # If mapping have different size array, must raise error
    assert_raises(TypeError, "All of `mappings`.values must have same size") do
      invalid_mappings = mappings.dup
      invalid_mappings["b"] = [1, 1, 1]
      Mizlab.calculate_coordinates(seq, invalid_mappings)
    end
    # If specify weights that have different length key, you need to give window_size
    weights_have_diff_len_key = weights.dup
    weights_have_diff_len_key["a"] = 2.0
    assert_raises(TypeError, "When not give `window_size`, `weights` must have same length keys") do
      Mizlab.calculate_coordinates(seq, mappings, weights = weights_have_diff_len_key)
    end
    assert_equal([[0.0, 2.0, 1.0, 0.5, 1.0], [0.0, 2.0, 3.0, 2.5, 2.0]],
                 Mizlab.calculate_coordinates(seq, mappings,
                                              weights = weights_have_diff_len_key, window_size = 3))
  end
end
