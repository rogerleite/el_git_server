defmodule ElGitServer.Options do
  def ssh_supervisor do
    [
      system_dir: get!(:system_dir),
      port: get!(:port),
      mediator: get!(:mediator),
      mediator_data: get!(:mediator_data)
    ]
  end

  defp get!(key) do
    Application.fetch_env!(:el_git_server, key)
  end
end
