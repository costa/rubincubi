# Events-based configuration mechanism

#TODO(0) Defaults + validity properties
module AsyncConfModule
  def conf_reader(*attrs)
    for attr in attrs
      module_eval <<-"end;"
        def #{attr.to_s}
          if defined?(@#{attr.to_s}) && @#{attr.to_s}
            @#{attr.to_s}
          else
            configure! :#{attr.to_s}
            nil
          end
        end
      end;
    end
  end

  def conf_writer(*attrs)
    for attr in attrs
      module_eval <<-"end;"
        def #{attr.to_s}=(val)
          @#{attr.to_s} = val
          configured! :#{attr.to_s}
        end
      end;
    end
  end

  def conf_accessor(*attrs)
    conf_reader(*attrs)
    conf_writer(*attrs)
  end

  protected :conf_reader, :conf_writer, :conf_accessor
end

#TODO(1) Separate!
module ConfAttributes
  include EventPooling

  fires :configure, :configured

# This is the valid signature for :configured event handler
#   def configured(src, *args) #event(target, *properties)
##E.g.     refresh
#   end
end
