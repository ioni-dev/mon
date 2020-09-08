defmodule MonWeb.PageController do
  use MonWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
