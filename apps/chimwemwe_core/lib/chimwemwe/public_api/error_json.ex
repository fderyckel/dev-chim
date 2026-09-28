defmodule Chimwemwe.PublicApi.ErrorJSON do
  @moduledoc false

  def render(_template, _assigns) do
    %{"errors" => [%{"code" => "internal_error", "detail" => "The request failed."}]}
  end
end
