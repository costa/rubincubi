#TODO(0) review & update !

=begin
1. Events (Object Level)
  - objects may fire events:
    - 'fires *event_id_symbols' module statements
  - objects may handle events:
    - 'def event_id(src, *args)' handler methods
  - objects may have customized event sending mechanism:
    - 'def event_send(event_id_symbol, *args, &block)'
2. Multi-Threading
  - objects may define their threading method:
    - 'def thread(*args, &block)'
    - or include a default one with module Threading
      - def thread; if respond_to? :threader; threader.thread(*args, &block)
        else; Thread.start(*args, &block); end; end
  - thread pooling objects (including module ThreadPooling) get a special thread
    method which manages both the pool and optionally a task queue of a certain
    size
    - chaining or otherwise structuring thread pools is possible
      via threader method injection (that special thread calls the original,
      which calls threader, in case the above Threading module is included)
    - both maximum sizes (>= 0) are settable via 'def max_threads' and
      'def max_threads_queued' (defaults 8, 64) respectively
      'def min_threads_sleeping' 'def running_sleeping_threads_ratio'
release_sleeping_thread? which is executed repeatedly (until the first false result) in the __running_thread_cleanup method (which is in turn is synchronously executed when a client thread ends)
    - they may also inject their special thread method via 'obj.extend(Thre...' (along
      with obj.extend(Thre...' and obj.thread_pool(self)
  - thread pools may be chained or otherwise connected functionally
    via injecting the threader method
  - thread
3. Asynchronous Events
  - including module ThreadedEvents defines event_send method to call thread
  - a convenience method thread_events(obj) will do: ThreadEvents,
  - events may be queued internally with a special version of event_send method
    which adds a synchronized event_queue attribute and some instrumentation
    around the method call to manage it (include module EventQueue)
    - maximum numbers of both currently allowed concurrent
      "object worker threads" and the "events waiting for delivery":
      'def max_worker_threads' and 'def max_queued_events' (defaults 1, 128)
=end

#Caution! A rather concept asynchronous event dispatching mechanism with barely
#         viable performance considerations. For use in low-performance
#         interaction-based modules only!
#NB A sort of a protocol or a contract is required
#   (let alone a sane notification architecture) for event load balancing.
#Caution! Otherwise, the events usage will bring pain alone

require 'async_events'
require 'thread_pool'

class Module
  include EventsModule
end

module EventPooling
  include Events
  include ThreadPooling

  DEF_THREADS_QUEUE_MAX = 64 #8? #2048?
  def threads_min; 0; end
  def threads_idle4working; 0; end
  def threads_max; 1; end
  def threads_queue_max; DEF_THREADS_QUEUE_MAX; end

  def event_send(e, *args, &blk)
    thread(blk, e, *args) { |b, e, *a| send(e, *a, &b) }
  end
end
