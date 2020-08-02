defmodule Libxml.Mixfile do
  use Mix.Project

  def project do
    [
      app: :libxml,
      compilers: [:make_libxml] ++ Mix.compilers(),
      version: "1.1.5",
      elixir: "~> 1.4",
      description: "Thin wrapper for Libxml2 using NIF",
      package: [
        maintainers: ["melpon"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/melpon/libxml"},
        files: [
          "mix.exs",
          "LICENSE",
          "Makefile",
          "README.md",
          "config",
          "lib",
          "priv/.gitkeep",
          "src"
        ]
      ],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [{:ex_doc, "~> 0.22.2", only: :dev, runtime: false}]
  end
end

defmodule Mix.Tasks.Compile.MakeLibxml do
  def run(_args) do
    File.mkdir("priv")
    {_, result_code} = System.cmd("make", [], into: IO.stream(:stdio, :line))

    if result_code != 0 do
      Mix.raise("exit code #{result_code}")
    end

    Mix.Project.build_structure()
    :ok
  end
end
