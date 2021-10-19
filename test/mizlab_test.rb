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
    filleds = Set.new([[2, 0], [2, 1], [2, 2],
                       [1, 0], [1, 1], [1, 2],
                       [0, 0], [0, 1], [0, 2]])
    actual = [0] * 512
    Mizlab.send(:get_patterns, filleds) do |pat|
      actual[Mizlab.send(:convert, pat)] += 1
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
    expecteds = Set.new([[0, 2], [1, 2], [2, 2],
                         [0, 1], [1, 1], [2, 1],
                         [0, 0], [1, 0], [2, 0]])
    actuals = Set.new()
    Mizlab.send(:get_centers, [1, 1]) do |c|
      actuals.add(c)
    end
    assert expecteds == actuals
  end

  def test_convert
    0.upto(511) do |i| # Does not consider number over 511
      org = i
      # make bit array
      r = []
      while i.nonzero?
        r.append(!(i % 2).zero?)
        i /= 2
      end
      assert_equal org, Mizlab.send(:convert, r.reverse)
    end

    # If array has non Boolean, the function should raise error.
    assert_raises(TypeError, "The argument must be Boolean") do
      arr = [true, true, 1]
      Mizlab.send(:convert, arr)
    end
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
end
