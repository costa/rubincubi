# This event notification library is inspired by and based on the code found
# in the "Signals & Slots in Ruby" article by Axel Plinge
# http://axel.plinge.de/dev/060116rbsigslot.html (c) Axel Plinge 2006

require 'monitor'

#TODO(0.5) Logging!
# you may or you may not want to freeze the @targets
# you may want to override Thread.start (to the point of not actually starting
# a thread, or for thread pooling, for instance, of course).
module EventsModule
  def fires(*events)
    for event in events
      module_eval <<-"end;"
        def __#{event.to_s}_event_targets
          @__#{event.object_id}__ ||=  []
        end
        protected :__#{event.to_s}_event_targets
        def #{event.to_s}!(*args, &block)
          fire(:#{event.to_s}, *args, &block)
        end
      end;
    end
  end
  protected :fires
end

module Events
  def fires
    methods.inject([]) { |res, m|
      res << $1 if /^__(.*)_event_targets$/ =~ m
      res
    }
  end

  def fires?(event)
    fires.find { |e| e == event.to_s }
  end

  # subscribe some target to some event notification (which will effectively be
  # an [asynchronous] method call with the optional default arguments
  #TODO Think of introducing the notification limit?
  def notify!(event, object, method, *args, &block)
    __event_sync {
      if object && object.method(method).arity <= -2 # (src, *args)
        puts "#{to_s} will notify #{object.to_s}::#{method.to_s}(#{args.join(',')}) on #{event.to_s}"
        __event_targets(event) << [object, method, [self] + args, block]
        self
      end
    }
  end

  # subscribe some target to some event notification (which will effectively be
  # an [asynchronous] method call with the optional default arguments
  def notify_not!(event, object, method)
    __event_sync {
      puts "#{to_s} will NOT notify #{object.to_s}::#{method.to_s}(#{args.join(',')}) on #{event.to_s}"
      __event_targets(event).delete_if  { |t| t[0..1] == [object, method] } if
        fires?(event)
    }
  end

  def notifies?(event, object, method)
    __event_targets(event).find { |t| t[0..1] == [object, method] }
  end

  def party!(*objects)
    for o in objects
      for m in o.methods #(true) + o.singleton_methods(true)
        notify!(m, o, m) if
          fires?(m) && !notifies?(m, o, m)
      end
      for m in self.methods #(true) + self.singleton_methods(true)
        o.notify!(m, self, m) if
          o.fires?(m) && !o.notifies?(m, self, m)
      end
    end
    self
  end

  def party_not!(*objects)
    for o in objects
      for m in o.methods #(true) + o.singleton_methods(true)
        notify_not!(m, o, m)
      end
      for m in self.methods #(true) + self.singleton_methods(true)
        o.notify_not!(m, self, m)
      end
    end
    self
  end

#TODO disconnect & disconnect(event

protected
  # call associated targets' methods with the
  # with the default args plus the given ones
  def fire(event, *args/*, &block*/)
    __event_sync {
      for t in __event_targets(event)
        begin
          puts "#{to_s} fires #{event.to_s}(#{args.join(',')}) at #{t[0].to_s}::#{t[1].to_s}(#{(t[2] + args).join(',')})"
          if t[0].respond_to? :event_send
            t[0].event_send(t[1], *(t[2] + args), &t[3])
          else
            t[0].send(t[1], *(t[2] + args), &t[3])
          end

        rescue ThreadPooling::QueueFullError
          if block_given?
            yield
          else
            raise
          end
        end
      end
    }
  end

  def __event_targets(e)
    method("__#{e.to_s}_event_targets").call
  end

  def __event_sync(&block)
    (@__event_mon ||= Monitor.new).synchronize(&block)
  end
end
