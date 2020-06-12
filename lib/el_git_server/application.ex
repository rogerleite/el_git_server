defmodule ElGitServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  alias ElGitServer.Options

  use Application

  def start(_type, _args) do
    children = [
      {ElGitServer.SSH, Options.ssh_supervisor()}
    ]
    IO.inspect(children: children)

    # See https://hexdocs.pm/elixir/Supervisor.html for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElGitServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
