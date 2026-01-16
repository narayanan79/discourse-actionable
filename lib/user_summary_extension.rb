# frozen_string_literal: true

module DiscourseActionable
  module UserSummaryExtension
    extend ActiveSupport::Concern

    def actionable_given
      @user.user_stat&.actionable_given || 0
    end

    def actionable_received
      @user.user_stat&.actionable_received || 0
    end
  end
end
