class ScriptedFailer
  attr_accessor :fails, :result, :successes

  def initialize(num_fails = 2, intended_result = 2)
    @fails = num_fails
    @result = intended_result
    @successes = 0
  end

  def fail(error_class, msg)
    if @fails > 0
      @fails -= 1
      raise error_class.new(msg)
    end
    @successes += 1
    @result
  end
end
