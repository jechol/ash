defmodule Ash.Test.ExprCalculationWithRelatedDepTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule Balance do
    use Ash.Resource.Calculation

    @impl Ash.Resource.Calculation
    def load(_, _, _), do: :balance_attr

    @impl Ash.Resource.Calculation
    def calculate(accounts, _, context) do
      opts = Ash.Context.to_opts(context)

      if opts[:actor] != %{a: :b} do
        raise "actor not correct"
      end

      if opts[:authorize?] do
        raise "should not be authorizing"
      end

      {:ok, Enum.map(accounts, fn account -> account.balance_attr end)}
    end
  end

  defmodule Account2 do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      domain: Ash.Test.Domain

    ets do
      private? true
    end

    actions do
      defaults([:read, create: :*])
    end

    attributes do
      uuid_primary_key(:id)

      attribute(:type, :string, public?: true)
      attribute(:balance_attr, :integer, public?: true)

      timestamps()
    end

    calculations do
      calculate :balance, :integer, Balance
    end

    relationships do
      belongs_to :account, Account do
        public? true
        allow_nil? false
      end
    end
  end

  defmodule Account do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      domain: Ash.Test.Domain

    ets do
      private? true
    end

    actions do
      defaults([:read, create: :*])
    end

    attributes do
      uuid_primary_key(:id)

      attribute(:type, :string, public?: true)

      timestamps()
    end

    calculations do
      calculate(:balance, :integer, expr(related_account.balance))
    end

    relationships do
      has_one :related_account, Account2 do
        public?(true)
        destination_attribute(:account_id)
      end
    end
  end

  test "can load non-expression calculations from expressions" do
    account2 =
      Ash.Seed.seed!(Account2, %{type: :test, balance_attr: 10})

    account = Ash.Seed.seed!(Account, %{related_account: account2})

    assert Ash.load!(account, :balance, authorize?: true, actor: %{a: :b}).balance == 10
  end
end
