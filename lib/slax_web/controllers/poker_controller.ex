defmodule SlaxWeb.PokerController do
  use SlaxWeb, :controller

  plug(Slax.Plugs.VerifySlackToken, token: :poker)
  plug(Slax.Plugs.VerifyUser)

  alias Slax.Poker

  def start(conn, %{"text" => ""}) do
    text(conn, """
    *Poker commands:*
    /poker start [repo/123] -- _Start a new round of planning poker for issue
    123 of the repo repo_.

    /poker next  -- _Start a new round of planning poker for the next issue
    with the SCORE label._

    /poker check -- _Remind yourself what round is being played._

    /poker estimate [1|2|3|5|8|13] (reason) -- _Provide your complexity points for the
    current issue_.

    /poker reveal -- _Reveal the estimates for the current issue_.

    /poker decide [1|2|3|5|8|13] -- _Finalize the points for the current issue._
    """)
  end

  def start(conn, %{
        "text" => "start " <> repo_and_issue,
        "channel_name" => channel_name,
        "response_url" => response_url
      }) do
    access_token = conn.assigns.current_user.github_access_token

    with {:ok, issue} <- load_issue(access_token, repo_and_issue),
         {:ok , _} <- Poker.end_current_round_for_channel(channel_name),
         {:ok, response} <- Poker.start_round(channel_name, repo_and_issue, issue, response_url) do
        json(conn, %{
          response_type: "in_channel",
          text: response
        })
    else
      {:error, error_message} ->
        IO.puts "Error fetching issue from github"
        text(conn, error_message)
      x ->
        IO.inspect x
        text(conn, "Invalid parameters, repo/issue number is required")
    end
  end

  defp load_issue(access_token, repo_and_issue) do
    [org, repo, issue] =
      case String.split(repo_and_issue, "/") do
        [org, repo, issue] -> [org, repo, issue]
        [repo, issue] -> ["revelrylabs", repo, issue]
      end

    client = Tentacat.Client.new(%{access_token: access_token})

    case Tentacat.Issues.find(client, org, repo, issue) do
      {200, issue, _http_response} -> {:ok, issue}
      {_response_code, %{"message" => error_message}, _http_response} -> {:error, error_message}
    end
  end

  # def start(conn, %{"channel_name" => channel_name, "text" => "next"}) do
  #   next_issue = Poker.next_issue(channel_name)
  #   |> Poker.start
  #   case Poker.start(repo) do
  #     {:ok, response} ->
  #       json(conn, %{
  #         response_type: "in_channel",
  #         text: response
  #       })

  #     _ ->
  #       text(conn, "Invalid parameters, repo/issue number is required")
  #   end
  # end

  def start(conn, _) do
    text(conn, "Unknown command, try again")
  end
end