
module Threading
  def thread(*args, &block)
    if respond_to? :threader
      threader.thread(*args, &block)
    else
      Thread.start(*args, &block)
    end
  end
end
