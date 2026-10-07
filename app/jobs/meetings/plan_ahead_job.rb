module Meetings
  # Nightly: each repeating meeting plans its coming week.
  class PlanAheadJob < ::ApplicationJob
    def perform
      Series.plan_all_ahead! if Runwell::Plugins.enabled?(:meetings)
    end
  end
end
