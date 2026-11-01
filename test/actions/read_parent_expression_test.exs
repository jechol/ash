# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Actions.ReadParentExpressionTest do
  use ExUnit.Case, async: true

  alias Ash.Actions.Read.Relationships
  alias Ash.Query.{BooleanExpression, Call, Calculation, Exists, Parent, Ref}

  defmodule CountedExpression do
    use Ash.Resource.Calculation

    @impl true
    def expression(opts, _context) do
      send(Keyword.fetch!(opts, :pid), :expression_expanded)
      Keyword.get(opts, :expression, true)
    end
  end

  test "detects hydrated and unhydrated parent expressions" do
    assert Relationships.do_has_parent_expr?(%Parent{expr: true})
    assert Relationships.do_has_parent_expr?(%Call{name: :parent, args: [true]})
    refute Relationships.do_has_parent_expr?(%Call{name: :is_nil, args: [nil]})
  end

  test "a parent inside exists only refers to its own source" do
    refute Relationships.do_has_parent_expr?(%Exists{
             path: [:children],
             expr: %Parent{expr: true}
           })

    refute Relationships.do_has_parent_expr?(%Exists{
             path: [:children],
             expr: %Call{name: :parent, args: [true]}
           })
  end

  test "nested parents can reach outside exists" do
    assert Relationships.do_has_parent_expr?(%Exists{
             path: [:children],
             expr: %Parent{expr: %Parent{expr: true}}
           })

    assert Relationships.do_has_parent_expr?(%Exists{
             path: [:children],
             expr: %Call{name: :parent, args: [%Call{name: :parent, args: [true]}]}
           })
  end

  test "preserves scope through nested exists and boolean expressions" do
    parent = %Parent{expr: true}
    twice = %Parent{expr: parent}
    three_times = %Parent{expr: twice}

    for expression <- [parent, twice] do
      refute Relationships.do_has_parent_expr?(%Exists{
               path: [:children],
               expr: %Exists{path: [:children], expr: expression}
             })
    end

    assert Relationships.do_has_parent_expr?(%BooleanExpression{
             op: :or,
             left: %Exists{path: [:children], expr: true},
             right: %Exists{
               path: [:children],
               expr: %Exists{path: [:children], expr: three_times}
             }
           })
  end

  test "finds parents in filters, calls, functions, operators and nested values" do
    parent = %Parent{expr: true}

    expressions = [
      %Ash.Filter{expression: parent},
      %Ash.Query.Not{expression: parent},
      %BooleanExpression{op: :and, left: true, right: parent},
      %Call{name: :is_nil, args: [parent]},
      %{__function__?: true, arguments: [parent]},
      %{__operator__?: true, left: false, right: parent},
      %{nested: [{:value, parent}]},
      %{parent => true}
    ]

    assert Enum.all?(expressions, &Relationships.do_has_parent_expr?/1)
    refute Relationships.do_has_parent_expr?(%{nested: [{:value, false}]})
    refute Relationships.do_has_parent_expr?(%Ref{attribute: :id})
    refute Relationships.do_has_parent_expr?(%Ash.Query.Aggregate{field: :id})
  end

  test "expands an aggregate calculation once through nested exists" do
    calculation = %Calculation{module: CountedExpression, opts: [pid: self()]}
    aggregate = %Ash.Query.Aggregate{field: calculation}
    ref = %Ref{attribute: aggregate}
    expression = Enum.reduce(1..10, ref, fn _, expr -> %Exists{path: [:children], expr: expr} end)

    refute Relationships.do_has_parent_expr?(expression)
    assert_received :expression_expanded
    refute_received :expression_expanded
  end

  test "ignores parent-shaped data in aggregate and query context" do
    parent = %Parent{expr: true}
    query = %Ash.Query{filter: %Ash.Filter{expression: true}, context: %{actor: %{value: parent}}}
    aggregate = %Ash.Query.Aggregate{field: :id, query: query, context: %{value: parent}}

    refute Relationships.do_has_parent_expr?(%Ref{attribute: aggregate})
    refute Relationships.do_has_parent_expr?(query)
    refute Relationships.do_has_parent_expr?(%Ref{attribute: %Ash.Resource.Attribute{}})
  end

  test "keeps aggregate filter and join filter references" do
    parent = %Parent{expr: true}

    for aggregate <- [
          %Ash.Query.Aggregate{
            field: :id,
            query: %Ash.Query{filter: %Ash.Filter{expression: parent}}
          },
          %Ash.Query.Aggregate{join_filters: %{[:children] => parent}}
        ] do
      assert Relationships.do_has_parent_expr?(%Ref{attribute: aggregate})
    end
  end

  test "checks filters even when an aggregate field calculation has no outer parent" do
    parent = %Parent{expr: true}
    calculation = %Calculation{module: CountedExpression, opts: [pid: self()]}

    aggregate = %Ash.Query.Aggregate{
      field: calculation,
      query: %Ash.Query{filter: %Ash.Filter{expression: parent}}
    }

    assert Relationships.do_has_parent_expr?(%Ref{attribute: aggregate})
    assert_received :expression_expanded
    refute_received :expression_expanded
  end

  test "uses a calculation expression rather than its execution context" do
    parent = %Parent{expr: true}

    calculation = %Calculation{
      module: CountedExpression,
      opts: [pid: self()],
      context: %{actor: %{value: parent}}
    }

    refute Relationships.do_has_parent_expr?(calculation)
    assert_received :expression_expanded
    refute_received :expression_expanded

    calculation = %{calculation | opts: [pid: self(), expression: parent]}
    assert Relationships.do_has_parent_expr?(calculation)
    assert_received :expression_expanded
    refute_received :expression_expanded
  end

  test "stops after finding an outer parent" do
    calculation = %Calculation{module: CountedExpression, opts: [pid: self()]}

    expression = %BooleanExpression{
      op: :or,
      left: %Parent{expr: true},
      right: %Ref{attribute: %Ash.Query.Aggregate{field: calculation}}
    }

    assert Relationships.do_has_parent_expr?(expression)
    refute_received :expression_expanded
  end
end
