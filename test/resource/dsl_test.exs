defmodule Ash.Resource.DslTest do
  use ExUnit.Case, async: true

  test "generic action module metadata does not create compile dependencies" do
    action = entity(:actions, :action)
    argument = action.entities |> Keyword.fetch!(:arguments) |> entity(:argument)

    assert :constraints in action.no_depend_modules
    assert :touches_resources in action.no_depend_modules
    assert :run in action.no_depend_modules
    assert :error_handler in action.no_depend_modules
    assert :constraints in argument.no_depend_modules
  end

  test "action callback modules do not create compile dependencies" do
    for action_name <- [:create, :update, :destroy] do
      action = entity(:actions, action_name)

      assert :error_handler in action.no_depend_modules
      assert :notifiers in action.no_depend_modules
    end
  end

  test "calculation constraint modules do not create compile dependencies" do
    calculation = entity(:calculations, :calculate)

    assert :constraints in calculation.no_depend_modules
  end

  test "custom aggregate implementation does not create compile dependencies" do
    aggregate = entity(:aggregates, :custom)

    assert :implementation in aggregate.no_depend_modules
  end

  test "reactor default domain does not create compile dependencies" do
    section = Enum.find(Ash.Reactor.sections(), &(&1.name == :ash))

    assert :default_domain in section.no_depend_modules
  end

  defp entity(section_name, entity_name) when is_atom(section_name) do
    Ash.Resource.Dsl.sections()
    |> Enum.find(&(&1.name == section_name))
    |> Map.fetch!(:entities)
    |> entity(entity_name)
  end

  defp entity(entities, entity_name) when is_list(entities) do
    Enum.find(entities, &(&1.name == entity_name))
  end
end
