defmodule ElGitServer.Mediators.Dummy do
  def channel_up(%{mediator_data: data} = _state) do
    {:ok, data}
  end

  def decide_git_repo(_git_cmd, git_args, %{mediator_data: %{git_dir: git_dir}} = _state) do
    repo_path = git_args |> List.first

    if repo_path == "user/denied.git" do
      {:error, :unauthorized}
    else
      abs_repo_path = Path.join(git_dir, repo_path)
      {:ok, abs_repo_path}
    end
  end

  def terminate(reason, state) do
    IO.inspect(method: "terminate", reason: reason, state: state)
  end
end
