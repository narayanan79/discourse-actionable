# frozen_string_literal: true
require "rails_helper"

RSpec.describe ActionableController, type: :controller do
  fab!(:user)
  fab!(:admin)
  fab!(:post)

  before do
    SiteSetting.actionable_enabled = true
    # Ensure actionable post action type exists
    PostActionType.find_or_create_by!(name_key: "actionable") do |pat|
      pat.is_flag = false
      pat.icon = "check"
      pat.position = 50
    end
  end

  describe "POST #create" do
    context "when user is signed in" do
      before { sign_in(user) }

      it "creates actionable action successfully" do
        post :create, params: { post_id: post.id }

        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        expect(json["success"]).to be(true)
        expect(json["acted"]).to be(true)
        expect(json["actionable_count"]).to eq(1)
        expect(json["can_undo_actionable"]).to be(true)
      end

      context "when user already actioned the post" do
        before { ActionableActionCreator.call(guardian: Guardian.new(user), post: post) }

        it "returns error for duplicate action" do
          post :create, params: { post_id: post.id }

          # No timeout now; duplicate create still fails but not due to timeout
          expect(response.status).to eq(422)
          json = JSON.parse(response.body)
          expect(json["success"]).to be(false)
          expect(json["errors"]).to be_present
        end
      end

      context "when actionable is disabled" do
        before { SiteSetting.actionable_enabled = false }

        it "returns error when feature is disabled" do
          post :create, params: { post_id: post.id }

          expect(response.status).to eq(422)
          json = JSON.parse(response.body)
          expect(json["success"]).to be(false)
        end
      end
    end

    context "when user is not signed in" do
      it "returns 403 forbidden" do
        post :create, params: { post_id: post.id }

        expect(response.status).to eq(403)
      end
    end
  end

  describe "DELETE #destroy" do
    context "when user is signed in and has actioned the post" do
      before do
        sign_in(user)
        ActionableActionCreator.call(guardian: Guardian.new(user), post: post)
      end

      it "destroys actionable action successfully" do
        delete :destroy, params: { post_id: post.id }

        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        expect(json["success"]).to be(true)
        expect(json["acted"]).to be(false)
        expect(json["actionable_count"]).to eq(0)
        expect(json["can_undo_actionable"]).to be(false)
      end

      # No timeout: user can always undo like Like
    end

    context "when user has not actioned the post" do
      before { sign_in(user) }

      it "returns error for non-existent action" do
        delete :destroy, params: { post_id: post.id }

        expect(response.status).to eq(422)
        json = JSON.parse(response.body)
        expect(json["success"]).to be(false)
        expect(json["errors"]).to be_present
      end
    end

    context "when user is not signed in" do
      it "returns 403 forbidden" do
        delete :destroy, params: { post_id: post.id }

        expect(response.status).to eq(403)
      end
    end
  end
end
