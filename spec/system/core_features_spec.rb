# frozen_string_literal: true

# Smoke test from discourse-plugin-skeleton: core features keep working with the
# plugin enabled (login, likes, profiles, topics, search).
RSpec.describe "Core features" do
  before { enable_current_plugin }

  it_behaves_like "having working core features"
end
