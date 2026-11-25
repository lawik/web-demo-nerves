defmodule WebDemoNervesTest do
  use ExUnit.Case
  doctest WebDemoNerves

  test "greets the world" do
    assert WebDemoNerves.hello() == :world
  end
end
