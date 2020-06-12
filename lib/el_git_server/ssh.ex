defmodule ElGitServer.SSH do
  @moduledoc """
  Documentation for ElGitServer.SSH
  """

  # SSH services are implemented as channels that are multiplexed over an
  # SSH connection and communicates over the SSH Connection Protocol.
  # See https://erlang.org/doc/man/ssh_server_channel.html
  @behaviour :ssh_server_channel

  # Behaviour describing the API for public key handling of an SSH server.
  # See https://erlang.org/doc/man/ssh_server_key_api.html
  @behaviour :ssh_server_key_api

  defstruct [:conn, :chan, :user, :git_port, :git_repo, :mediator, :mediator_data]

  @doc """
  Initialize SSH daemon as part of a supervision tree.

  system_dir - String, this is the directory holding the server's files. See https://erlang.org/doc/man/ssh_file.html#SYSDIR.
  port - Integer, the port number to listen SSH commands.
  mediator - Module, that implements a mediator behaviour.
  mediator_data - Map, to be manipulated by mediator behaviour.
  """
  def child_spec(
        system_dir: system_dir,
        port: port,
        mediator: mediator,
        mediator_data: mediator_data
      ) do
    daemon_opts = [
      key_cb: {__MODULE__, []},
      ssh_cli: {__MODULE__, [mediator: mediator, mediator_data: mediator_data]},
      parallel_login: true,
      max_sessions: 8,
      pwdfun: &check_credentials/2,
      system_dir: to_charlist(system_dir)
    ]

    %{
      id: __MODULE__,
      start: {:ssh, :daemon, [port, daemon_opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  defp check_credentials(_username, _password) do
    # to_string(username), to_string(password)
    # IO.inspect(method: "check_credentials", username: username, password: password)
    true
  end

  # Fetches the private key of the host.
  @impl :ssh_server_key_api
  def host_key(algo, opts) do
    :ssh_file.host_key(algo, opts)
  end

  # Checks if the user key is authorized.
  @impl :ssh_server_key_api
  def is_auth_key(_key, _username, _opts) do
    # user = to_string(username)
    # ^key = :public_key.ssh_decode(user_auth_key, :public_key)
    true
  end

  # Makes necessary initializations and returns the initial channel state if the initializations succeed.
  @impl :ssh_server_channel
  def init(mediator: mediator, mediator_data: data) do
    {:ok, %__MODULE__{mediator: mediator, mediator_data: data}}
  end

  # This is the first message that the channel receives.
  # This is especially useful if the server wants to send a message to the client without first receiving a message from it.
  @impl :ssh_server_channel
  def handle_msg(
        {:ssh_channel_up, chan, conn},
        %__MODULE__{mediator: mediator} = state
      ) do
    [user: username] = :ssh.connection_info(conn, [:user])
    new_state = struct(state, conn: conn, chan: chan, user: username)
    {:ok, data} = mediator.channel_up(new_state)

    {:ok, struct(new_state, mediator_data: data)}
  end

  @impl :ssh_server_channel
  def handle_msg(
        {git_port, {:data, data}},
        %__MODULE__{conn: conn, chan: chan, git_port: git_port} = state
      )
      when is_port(git_port) do
    :ssh_connection.send(conn, chan, data)
    {:ok, state}
  end

  @impl :ssh_server_channel
  def handle_msg(
        {git_port, {:exit_status, status}},
        %__MODULE__{conn: conn, chan: chan, git_port: git_port} = state
      )
      when is_port(git_port) do
    :ssh_connection.send_eof(conn, chan)
    :ssh_connection.exit_status(conn, chan, status)
    :ssh_connection.close(conn, chan)

    {:stop, chan, state}
  end

  # Data has arrived on the channel. This event is sent as result of calling ssh_connection:send/[3,4,5]
  @impl :ssh_server_channel
  def handle_ssh_msg(
        {:ssh_cm, conn, {:data, chan, _type, data}},
        %__MODULE__{conn: conn, chan: chan, git_port: git_port} = state
      )
      when is_port(git_port) do
    Port.command(git_port, data)
    {:ok, state}
  end

  # This message will request that the server starts execution of the given command.
  # This event is sent as result of calling ssh_connection:exec/4
  @impl :ssh_server_channel
  def handle_ssh_msg(
        {:ssh_cm, conn, {:exec, chan, _reply, cmd}},
        %__MODULE__{
          mediator: mediator,
          conn: conn,
          chan: chan
        } = state
      ) do
    # TODO: check if exists the case of "--" in cmd
    # 'git-receive-pack \'user/tst.git\'' => ["git-receive-pack", ["user/tst.git"]]
    [git_cmd | git_args] =
      to_string(cmd)
      |> String.split()
      |> Enum.map(&String.trim(&1, "'"))

    IO.inspect(method: "handle_ssh_msg-exec", cmd: cmd, git_cmd: git_cmd, git_args: git_args)

    repo_decision = mediator.decide_git_repo(git_cmd, git_args, state)

    case repo_decision do
      {:ok, absolute_repo_path} ->
        git_port =
          Port.open(
            {:spawn_executable, System.find_executable(git_cmd)},
            [:stream, :binary, :exit_status, args: [absolute_repo_path]]
          )

        updated_state = struct(state, git_port: git_port, git_repo: absolute_repo_path)
        {:ok, updated_state}

      {:error, :unauthorized} ->
        :ssh_connection.send_eof(conn, chan)
        :ssh_connection.exit_status(conn, chan, 401)
        {:stop, chan, state}
    end
  end

  @impl :ssh_server_channel
  def handle_ssh_msg(
        {:ssh_cm, conn, {:shell, chan, _reply}},
        %__MODULE__{conn: conn, chan: chan} = state
      ) do
    :ssh_connection.send(conn, chan, "You are not allowed to start a shell.\r\n")
    :ssh_connection.send_eof(conn, chan)
    {:stop, chan, state}
  end

  @impl :ssh_server_channel
  def handle_ssh_msg(
        {:ssh_cm, conn, _msg},
        %__MODULE__{conn: conn} = state
      ) do
    # handle :eof message
    {:ok, state}
  end

  @impl :ssh_server_channel
  def terminate(reason, %__MODULE__{mediator: mediator} = state) do
    mediator.terminate(reason, state)
    :ok
  end
end
