
require 'rational'
require 'mathn'

require 'test/unit'

require 'events'


# TODO Well this is moleshit of course, must be made real
class TestEvents < Test::Unit::TestCase
  include ThreadPooling

  class Kreature
    include EventPooling

    attr_reader :name, :born, :died, :mommy

    fires :alive, :dead, :hungry, :thirsty, :naughty

    def initialize(n, m)
      @name, @mommy = n, m
      @born, @died = nil, nil
    end

    def alive?
      born? && !dead?
    end

    alias born? born
    alias dead? died

    def live(chance)
      if !born?
        if rand <= chance
          puts self.to_s + ' is born by ' + mommy.to_s
          @born = Time.now
        end
      elsif !dead?
        if rand > chance
          dead! { }
        end
      end
      if alive?
        alive! { }
      else
        puts 'Dead ' + self.to_s + ' cannot live'
      end
    end

    def die
      if !born?
        puts 'Unborn ' + self.to_s + ' cannot die'
      elsif dead?
        puts 'Dead ' + self.to_s + ' cannot die again'
      elsif
        @died = Time.now
      end
    end

    def fuck(*others)
      puts self.to_s + " fucks " + others.to_s
      for k in [self, *others]
        k.extend(Mommy)
      end
      feel
    end

    def kill(*others)
      puts self.to_s + " kills " + others.to_s
      case rand(2)
      when 0
        die
      when 1
        others.each { |k| k.die }
      end
    end

    def eat(*others)
      puts self.to_s + " eats " + others.to_s
      for k in others
        kill k if k.alive?
      end
    end

    def drink
    end

    def feel
      puts "#{to_s} is feeling..."
      case rand(100)
      when 0
        alive! { }
      when (1..10)
        hungry! { }
      when (11..33)
        thirsty! { }
      when (34..98)
        naughty! { }
      when 99
        dead! { }
      end
    end

    def naughty?
      (born.to_i - Time.now.to_i) % 6 == 0
    end

    def to_s
      name
    end

###############################################################################

    def alive(src, *args) #event
      if (src == self and rand < 5/6) or rand > 1/2
        feel
      end
    end

    def naughty(src, *args)
      if alive?
        if naughty?
          fuck(src)
        elsif rand > 1/2
          feel
        end
      end
    end
  end

  module Mommy
    class << self
      def extended(obj)
        unless obj.respond_to? :proto_kreature
          class << obj
            def proto_kreature
              mommy.proto_kreature
            end
          end
        end
        obj.notify!(:expecting, obj.proto_kreature, :expecting) unless
          obj.notifies?(:expecting, obj.proto_kreature, :expecting)
        obj.proto_kreature.notify!(:bear, obj, :bear) unless
          obj.proto_kreature.notifies?(:bear, obj, :bear)
        obj.expecting! { }
      end
    end

    attr_reader :kidz

    fires :expecting

    def bear(src, unborn, *args) #event
      if unborn.mommy == self
        (@kidz ||= []) << unborn
        unborn.live 5/6
      end
    end
  end

  def test_simple

    #TODO test by preseeding random for each kreature and then checking the world
    srand(Time.now.to_i)

    earth = Kreature.new('Earth', nil)

    thread_pool earth

    class << earth
      fires :bear

      def threads_min; 1; end

      define_method :proto_kreature do
        self
      end

      def expecting(src, *args) #event
        @children ||= []
        #TODO names = [[Ivan, Maria, ...], [John, Betty, ...], ...]
        k = Kreature.new(@children.size.to_s, src)
        @children << k
        threader.thread_pool k

        k.party!(self)
        k.party!(*@children)

        bear!(k) { }
      end

      def alive?
        if @children
          for k in @children
            return true if k.alive?
          end
        end
      end

      def dead(src, *args)
        @world.run if !alive?
      end

      def world_run
        @world = Thread.current
        Thread.stop
      end
    end

    earth.extend Mommy
    earth.world_run
  end
end
