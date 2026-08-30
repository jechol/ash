defmodule Ash.Resource.ConstraintsDependencyTest do
  use ExUnit.Case, async: true

  @path [:constraints, :instance_of]

  defp entity(section_name, entity_name) when is_atom(section_name) do
    Ash.Resource.Dsl.sections()
    |> Enum.find(&(&1.name == section_name))
    |> Map.fetch!(:entities)
    |> entity(entity_name)
  end

  defp entity(entities, entity_name) when is_list(entities) do
    Enum.find(entities, &(&1.name == entity_name))
  end

  test "attribute의 instance_of는 compile dependency를 만들지 않는다" do
    assert @path in entity(:attributes, :attribute).no_depend_modules
  end

  test "action argument의 instance_of는 compile dependency를 만들지 않는다" do
    action = entity(:actions, :action)
    argument = action.entities |> Keyword.fetch!(:arguments) |> entity(:argument)

    assert @path in argument.no_depend_modules
    assert @path in action.no_depend_modules
  end

  test "calculation의 instance_of는 compile dependency를 만들지 않는다" do
    calculation = entity(:calculations, :calculate)

    assert @path in calculation.no_depend_modules
    assert :calculation in calculation.no_depend_modules
  end

  test "constraints 전체가 아니라 instance_of 경로만 지정한다" do
    # fields의 중첩 type module은 init/1이 compile time에 소비하므로 dependency를 유지해야 한다
    refute :constraints in entity(:attributes, :attribute).no_depend_modules
  end
end
