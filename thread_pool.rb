
require 'thread'

require 'rubygems'

require 'metaid'

#TODO(.5) require 'blocking_queue'

#Caution!
# Avoid thread pool deadlocking by carefully designing the threading model
# (the above applies to the blocking usage model)
#Caution!
# Avoid unreasonably large queue limits or provide means of saving
# the thread pool state in data collecting applications (including GUI apps)
#TODO(.5)
module ThreadPooling
# invariants: (TODO should I do DSL for this matter? like instrumenting each method entry-return with invariants assertion, or is there rspec for this matter?)
# (@__threads_working + @__threads_idle) <= 'threads_max'
# (@__threads_working + @__threads_idle) >= 'threads_min'
# __thread_pool_queue.empty? || @__threads_working == 'threads_max'

  DEF_THREADS_MIN = 0
  DEF_THREADS_IDLE4WORKING = 1
  DEF_THREADS_MAX = 8
  DEF_THREADS_QUEUE_MAX = 1 #TODO Change it to 0 (fix queue behaviour first)

  #def threads_min; DEF_THREADS_MIN; end
  #def threads_idle4working; DEF_THREADS_IDLE4WORKING; end
  #def threads_max; DEF_THREADS_MAX; end
  #def threads_queue_max; DEF_THREADS_QUEUE_MAX; end

  class QueueFullError < Exception
  end

  def thread_pool(obj)
    obj.extend(ThreadPooling)
    me = self #WTF?
    obj.meta_def(:threader) { me }
    obj
  end

  #TODO the default may be patched for a specific architecture
  # to suggest the optimal performance for a typical application,
  # plus some helper heuristically parameterized methods may be supplied
  # (such as new_cpu_intensive)

  def thread(*args, &block)
    puts "#{__thread_pool_state}: A new task pooshed for"
    __thread_pool_sync {
      raise QueueFullError if
        __thread_pool_queue.size == __thread_pool_queue.max
      __thread_pool_queue.push [block, args]
      @__threads_working ||= 0
      @__threads_idle ||= 0
      __thread_worker_new if @__threads_idle == 0 &&
        @__threads_working < __thread_pool_opt_size(@__threads_working+1)
    }
  end

  def included(mod)
    mod.alias_method(:__thread__b4_ThreadPooling, :thread) \
      if mod.method_defined? :thread
  end

  def extended(obj)
    class << obj
      alias __thread__b4_ThreadPooling thread if obj.respond_to? thread
    end
  end

protected
  def __thread_pool_sync(&block)
    (@__thread_pool_mon ||= Monitor.new).synchronize(&block)
  end

  def __thread_pool_queue
    __thread_pool_sync {
      max = if respond_to? :threads_queue_max; threads_queue_max;
            else; DEF_THREADS_QUEUE_MAX; end
      @__thread_pool_queue.max = max if
        defined?(@__thread_pool_queue) && @__thread_pool_queue.max != max
      @__thread_pool_queue ||= SizedQueue.new(max)
    }
  end

  def __thread_pool_work
    loop do
      blk, args = *(__thread_pool_queue.pop)
      puts "#{__thread_pool_state}: Going to work"
      __thread_pool_sync { @__threads_working+=1; @__threads_idle-=1 }
      begin
        blk.call(*args)
      rescue
        puts "#{$!.to_s}!!! What TODO?!"
        __thread_pool_sync {
          @__threads_working-=1
          __thread_worker_new unless __thread_pool_queue.empty? &&
            (@__threads_working + @__threads_idle+1) >
              __thread_pool_opt_size(@__threads_working)
        }
        raise
      end
      puts "#{__thread_pool_state}: Work done for"
      __thread_pool_sync {
        @__threads_working-=1
        return if __thread_pool_queue.empty? &&
          (@__threads_working + @__threads_idle+1) >
            __thread_pool_opt_size(@__threads_working)
        @__threads_idle+=1
        puts "#{__thread_pool_state}: Another work loop for"
      }
    end
  end

  def __thread_pool_opt_size(running)
    [if respond_to? :threads_max; threads_max; else; DEF_THREADS_MAX; end,
     [if respond_to? :threads_min; threads_min else; DEF_THREADS_MIN; end,
      running*(1+
               if respond_to? :threads_idle4working; threads_idle4working
               else; DEF_THREADS_IDLE4WORKING; end)].max].min
  end

  def __thread_pool_state
    __thread_pool_sync {
      "TP:#{to_s}:#{Thread.current.to_s}:#{if defined? @__threads_working; @__threads_working; else; 0; end}w:#{if defined? @__threads_idle; @__threads_idle; else; 0; end}i:#{if defined? @__thread_pool_queue; @__thread_pool_queue.size; else; 0; end}q"
    }
  end

  def __thread_worker_new
    puts "#{__thread_pool_state}: A new thread emerging for"
    @__threads_idle+=1
    if respond_to? :threader
      threader.thread { __thread_pool_work }
    elsif respond_to? :__thread__b4_ThreadPooling
      __thread__b4_ThreadPooling { __thread_pool_work }
    else
      Thread.start { __thread_pool_work }
    end
  end
end
