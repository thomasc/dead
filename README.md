dead - disposable erlang application deployment
===============================================

dead allows the disposable deployment of an erlang application
running on a given node to another node.

To deploy the myapp application on node@host:

    dead:deploy('node@host', myapp).

Optionally a list of modules to be loaded first on the remote node
may be specified:

    dead:deploy('node@host', elixir, ['Elixir-Enum', 'Elixir-Code']).

