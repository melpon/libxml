defmodule Libxml.Mixfile do
  use Mix.Project

  def project do
    [
      app: :libxml,
      compilers: [:make_libxml] ++ Mix.compilers,
      version: "1.0.0",
      elixir: "~> 1.4",
      description: "Thin wrapper for Libxml2 using NIF",
      package: [maintainers: ["melpon"],
                licenses: ["MIT"],
                links: %{"GitHub" => "https://github.com/melpon/libxml"}],
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end
end

defmodule Mix.Tasks.Compile.MakeLibxml do
  def run(_args) do
    {_, result_code} = System.cmd("make", [], into: IO.stream(:stdio, :line))
    if result_code != 0 do
      Mix.raise "exit code #{result_code}"
    end
  end
end
