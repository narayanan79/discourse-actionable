# frozen_string_literal: true

module Jobs
  # Keeps the actionable_daily reporting table bounded.
  class CleanupActionableDaily < ::Jobs::Scheduled
    every 1.day

    def execute(_args)
      return if !SiteSetting.actionable_enabled

      ::ActionableDaily.cleanup_old_records
    end
  end
end
