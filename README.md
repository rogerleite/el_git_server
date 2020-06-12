# ElGitServer - Elixir Git on the Server

Getting Git on a Server with Elixir.

This library supports the [SSH Protocol](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols), and depends on `git` to pipe ssh stream data to `git-upload-pack` and `git-receive-pack`.

WARNING: This project is work in progress (WIP) ALPHA stage.

## Setting Up the Server

- Ensures git is installed. Tested with `git version 2.24.0`.
- Configure options (TODO: improve this before oficial release)
- Generate host keys on `system_dir` configuration.

## Development

Follow the [Setting Up the Server](#setting-up-the-server) section, and put the configurations on `config/dev.exs` file.

### Some tips to run local

Configure your `~/.ssh/config`:

```
Host localhost.com
  HostName 127.0.0.1
  Port 4242
```

Start server:

`$ iex -S mix`

Initialize a sample repository:

```sh
# inside git-data (default: /tmp/git-data)
$ mkdir -p user/sample.git
$ cd user/sample.git/
$ git init --bare
Initialized empty Git repository in /tmp/git-data/user/sample.git/
```

To clone the empty repository:

`git clone git@localhost.com:user/sample.git`

To do a commit:

```sh
$ cd sample/
$ echo "hello" > lionel.txt
$ git add .
$ git commit -m "hello"
[master (root-commit) 950a366] hello
 1 file changed, 1 insertion(+)
 create mode 100644 lionel.txt

$ git push origin master
Enumerating objects: 3, done.
Counting objects: 100% (3/3), done.
Writing objects: 100% (3/3), 218 bytes | 218.00 KiB/s, done.
Total 3 (delta 0), reused 0 (delta 0)
channel 0: protocol error: close rcvd twice
To localhost.com:user/sample.git
 * [new branch]      master -> master
```

If this flow is working, your development environment is ok.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `el_git_server` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:el_git_server, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/el_git_server](https://hexdocs.pm/el_git_server).

