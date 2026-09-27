defmodule Chimwemwe.AuthDemo.ErrorHTML do
  @moduledoc false

  use Phoenix.Component

  def render(_template, _assigns) do
    """
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8"><title>Authentication demonstration error</title></head>
    <body><main><h1>Authentication demonstration error</h1><p>The local page could not be displayed.</p></main></body></html>
    """
  end
end
