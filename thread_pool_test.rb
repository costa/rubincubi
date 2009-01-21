
require 'test/unit'

require 'thread_pool'

# TODO Well this is moleshit of course, must be made real
class TestThreadPooling < Test::Unit::TestCase
  include ThreadPooling

  def test_simple
    seeds_of_love = ['sympathy', 'luck', 'humour', 'sex', 'touch']
    earth = []
    for seed in seeds_of_love
      thread(seed) { |s| earth << s }
    end
    assert_equal(seeds_of_love.sort, earth.sort)
  end
end
