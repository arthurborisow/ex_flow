defmodule ExFlowTest do
  use ExUnit.Case
  doctest ExFlow

  @some_reason {:error, :some_reason}

  describe "workflow" do
    test "passes error with each operation" do
      result = ExFlow.workflow(do: {:error, :my_reason} ~> error_operation)

      assert result == {:error, :my_reason}
    end

    test "calls function with success" do
      result = ExFlow.workflow(do: 42 ~> error_operation)

      assert result == {:error, :some_reason}
    end

    test "works with partial functions" do
      result = ExFlow.workflow(do: 40 ~> partial_operation(2))

      assert result == 42
    end

    test "allows to create local vars" do
      result =
        ExFlow.workflow do
          local_var = 2

          40 ~> partial_operation(local_var)
        end

      assert result == 42
    end

    test "allows multiple chaining" do
      result =
        ExFlow.workflow do
          local_var = 1

          38
          ~> partial_operation(local_var)
          ~> partial_operation(3)
        end

      assert result == 42
    end

    test "stops on first error" do
      result =
        ExFlow.workflow do
          38
          ~> error_operation
          ~> partial_operation(3)
        end

      assert result == @some_reason
    end

    test "works ok with arg name" do
      result =
        ExFlow.workflow do
          arg = 2

          40
          ~> partial_operation(arg)
        end

      assert result == 42
    end

    test "works ok with arg name outside workflow spec" do
      arg = 2

      result = ExFlow.workflow(do: 40 ~> partial_operation(arg))

      assert result == 42
    end

    test "works with remote calls" do
      result = ExFlow.workflow(do: 21 ~> ExFlowTest.public_operation())

      assert result == 42
    end

    test "works with remote partial calls" do
      result = ExFlow.workflow(do: 2 ~> ExFlowTest.public_operation(21))

      assert result == 42
    end
  end

  describe "works with lambdas" do
    test "which are not inline" do
      lambda = &identity_operation/1

      result = ExFlow.workflow(do: 42 ~> lambda.())

      assert result == 42
    end

    test "which are inline" do
      result = ExFlow.workflow(do: 42 ~> (&identity_operation/1).())

      assert result == 42
    end
  end

  describe "allows to make side effects without transforming the input" do
    test "it ignores the result of some sideeffect" do
      result =
        ExFlow.workflow do
          20
          ~> partial_operation(1)
          # if the result of this wasn't ignored the workflow result would eq 84
          ~>> public_operation
          ~> public_operation
        end

      assert result == 42
    end
  end

  def public_operation(arg), do: arg * 2
  def public_operation(a, arg), do: a * arg

  defp error_operation(_), do: @some_reason
  defp partial_operation(arg, my_arg), do: arg + my_arg
  defp identity_operation(a), do: a
end
