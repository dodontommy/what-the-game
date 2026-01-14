require "test_helper"

class UserGamesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get user_games_index_url
    assert_response :success
  end
end
