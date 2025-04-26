defmodule OctoconWeb.PollJSON do
  def index(%{polls: polls}) do
    %{data: Enum.map(polls, &data/1)}
  end

  def show(%{entry: entry}) do
    %{data: data(entry)}
  end

  def data(entry) do
    entry
    |> Map.from_struct()
    |> Map.drop([:__meta__, :user])
  end
end
