module Pester
  module Behaviors
    module Sleep
      Linear = ->(attempt_num, delay_interval) { sleep(attempt_num * delay_interval) }

      Exponential = ->(attempt_num, delay_interval) { sleep((2**attempt_num - 1) * delay_interval) }
    end
  end
end
