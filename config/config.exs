use Mix.Config

config :el_git_server,
  system_dir: "/path/to/system_dir",
  port: 4242,
  mediator: ElGitServer.Mediators.Dummy,
  mediator_data: %{
    git_dir: "/path/to/git-data"
  }

import_config "#{Mix.env()}.exs"
