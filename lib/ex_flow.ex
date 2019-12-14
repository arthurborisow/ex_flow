defmodule ExFlow do
  @arg Macro.var(:"arg name for anonymous function", __MODULE__)

  @moduledoc """
    Module to make life with workflows easier

    Helps to compose functions with `|>` to not handle errors explicitly but just to bypass them.

    If you hate making names for variables with `Kernel.SpecialForms.with/1` this module is for you
    ```
    defmodule MyModule do
      import ExFlow

      def action do
        workflow do
          validate_input_data(params)
          ~> save_user
          ~> generate_plans(2)
          ~>> send_confirmation
          ~> redirect_to_user_page
        end
      end
    end
    ```

    Operations in previous example might be anything. It's a bogus code to show how to to pipe operations
    inside workflows and not care about failures.
    `~>` is for operations which transform data and `~>>` is for operations which don't transform data and can be built
    manually without metaprogramming with the help of `ExFlow.bind/1`, `ExFlow.bind/2`, `ExFlow.then/1` and
    `ExFlow.then/2`.
  """
  @moduledoc since: "0.1.0"

  @doc ~S"""
    Binds an argument and produces one-argument function

    Returns new anonymous function which either returns input parameter
    if it looks like error or calls the function being bound with that parameter.
    Inspired by `>>=` in Haskell.

    Parameter is considered to be error if it is equal to `:error` or a tuple which first element is `:error`.

    Helps to compose functions with `|>` to not handle errors explicitly but just to bypass them.

    ## Examples
      iex> ExFlow.bind(fn _ -> 42 end).({:error, :reason})
      {:error, :reason}

      iex> ExFlow.bind(fn _ -> 42 end).(:error)
      :error

      iex> ExFlow.bind(& &1).(42)
      42

      iex> {:error, :reason} |> ExFlow.bind(&(&1 * 2)) |> ExFlow.bind(&(&1 + 2))
      {:error, :reason}

      iex> :error |> ExFlow.bind(&(&1 * 2)) |> ExFlow.bind(&(&1 + 2))
      :error

      iex> 20 |> ExFlow.bind(&(&1 * 2)) |> ExFlow.bind(&(&1 + 2))
      42
  """
  @doc since: "0.1.0"
  def bind(fun)

  def bind(fun) do
    fn
      arg
      when is_tuple(arg) and elem(arg, 0) == :error
      when arg == :error ->
        arg

      arg ->
        fun.(arg)
    end
  end

  def bind(arg, fun) do
    bind(fun).(arg)
  end

  @doc ~S"""
    Binds an argument and produces one-argument function which ignores function return value

    Returns new anonymous function which either returns input parameter
    if it looks like error or calls the function being bound with that parameter and returns that very parameter.
    Usefull for sideffect functions which don't transform input e.g. scheduling job to send email when user is created/
    Inspired by `>>` in Haskell.

    Parameter is considered to be error if it is equal to `:error` or a tuple which first element is `:error`.

    Helps to compose functions with `|>` to not handle errors explicitly but just to bypass them.

    ## Examples
      iex> ExFlow.then(fn a -> a + 2 end).({:error, :reason})
      {:error, :reason}

      iex> ExFlow.then(fn a -> a + 2 end).(:error)
      :error

      iex> ExFlow.then(& &1).(42)
      42

      iex> {:error, :reason} |> ExFlow.then(&(&1 * 2)) |> ExFlow.then(&(&1 + 2))
      {:error, :reason}

      iex> :error |> ExFlow.then(&(&1 * 2)) |> ExFlow.then(&(&1 + 2))
      :error

      iex> 20 |> ExFlow.then(&(&1 * 2)) |> ExFlow.then(&(&1 + 2))
      20
  """
  @doc since: "0.1.0"
  def then(fun)

  def then(fun) do
    fn
      arg
      when is_tuple(arg) and elem(arg, 0) == :error
      when arg == :error ->
        arg

      arg ->
        fun.(arg)

        arg
    end
  end

  def then(arg, fun) do
    then(fun).(arg)
  end

  @doc ~S"""
    Creates workflow

    In simple words helps to compose functions thinking only about happy path and return error as soon as possible.
    Actually speaking it is the same as `Kernel.SpecialForms.with/1` but doesn't make you think about the errors
    and allows just to write the transformations on data instead.

    It uses `~>` operator which is the same as `|>` in context of workflow. So

    ```
    workflow do
      operation ~> operation2
    end
    ```

    is the same as

    ```
    operation |> ExFlow.bind(&(operation2(&1)))
    ```

    Also uses `~>>` operator where is the same as `|>` in context of workflow but ignores the return or right parameter
    function. So

    ```
    workflow do
      operation ~>> operation2
    end
    ```

    is the same as

    ```
    operation |> ExFlow.then(&(operation2(&1)))
    ```

    which will return the result of `operation` not `operation2`. Useful for side-effect oe async operations which
    shouldn't transform input data
  """
  defmacro workflow(do: body) do
    Macro.prewalk(body, &walk/1)
  end

  %{~>: :bind, ~>>: :then} |> Enum.each(fn {operator, mapping} ->
    defp walk({unquote(operator), context, [left, right]}) do
      {:|>, context, [left, quoted(unquote(mapping), right)]}
    end
  end)

  defp walk(a), do: a

  defp quoted(type, {name, cont, args}) do
    quote do
      ExFlow.unquote(type)(fn unquote(@arg) -> unquote({name, cont, args_for_anonymous_fn(args)}) end)
    end
  end

  defp args_for_anonymous_fn(nil), do: [@arg]
  defp args_for_anonymous_fn(args), do: [@arg | args]
end
