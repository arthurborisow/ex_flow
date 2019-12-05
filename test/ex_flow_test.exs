defmodule ExFlowTest do
  use ExUnit.Case
  doctest ExFlow

  test "greets the world" do
    assert ExFlow.hello() == :world
  end
end
