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

    assert :modify_query in entity(:actions, :read).no_depend_modules
  end

  test "calculation constraint modules do not create compile dependencies" do
    calculation = entity(:calculations, :calculate)
    argument = calculation.entities |> Keyword.fetch!(:arguments) |> entity(:argument)

    assert :constraints in calculation.no_depend_modules
    assert :constraints in argument.no_depend_modules
  end

  test "type constraint modules do not create compile dependencies" do
    for attribute_name <- [
          :attribute,
          :create_timestamp,
          :update_timestamp,
          :integer_primary_key,
          :uuid_primary_key,
          :uuid_v7_primary_key
        ] do
      assert :constraints in entity(:attributes, attribute_name).no_depend_modules
    end

    create = entity(:actions, :create)
    metadata = create.entities |> Keyword.fetch!(:metadata) |> entity(:metadata)
    assert :constraints in metadata.no_depend_modules

    define = entity(:code_interface, :define)
    custom_input = define.entities |> Keyword.fetch!(:custom_inputs) |> entity(:custom_input)
    assert :constraints in custom_input.no_depend_modules

    typed_struct_field = entity(Ash.TypedStruct.Dsl, :typed_struct, :field)
    assert :constraints in typed_struct_field.no_depend_modules
  end

  test "aggregate resource metadata does not create compile dependencies" do
    for aggregate_name <- [:count, :first, :max, :min, :sum, :avg, :exists, :list, :custom] do
      assert :relationship_path in entity(:aggregates, aggregate_name).no_depend_modules
    end

    assert :implementation in entity(:aggregates, :custom).no_depend_modules
  end

  test "reactor default domain does not create compile dependencies" do
    section = Enum.find(Ash.Reactor.sections(), &(&1.name == :ash))

    assert :default_domain in section.no_depend_modules
  end

  test "runtime callback modules do not create compile dependencies" do
    assert :allow in section(Ash.Domain.Dsl, :resources).no_depend_modules

    multitenancy = section(Ash.Resource.Dsl, :multitenancy)
    assert :parse_attribute in multitenancy.no_depend_modules
    assert :tenant_from_attribute in multitenancy.no_depend_modules

    for publication_name <- [:publish, :publish_all] do
      publication = entity(Ash.Notifier.PubSub, :pub_sub, publication_name)
      assert :constraints in publication.no_depend_modules
      assert :dispatcher in publication.no_depend_modules
    end
  end

  defp entity(section_name, entity_name) when is_atom(section_name) do
    entity(Ash.Resource.Dsl, section_name, entity_name)
  end

  defp entity(entities, entity_name) when is_list(entities) do
    Enum.find(entities, &(&1.name == entity_name))
  end

  defp entity(extension, section_name, entity_name) do
    extension
    |> section(section_name)
    |> Map.fetch!(:entities)
    |> entity(entity_name)
  end

  defp section(extension, section_name) do
    Enum.find(extension.sections(), &(&1.name == section_name))
  end
end
