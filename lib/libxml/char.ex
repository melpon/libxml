defmodule Libxml.Char do
  defstruct [:pointer, :content]

  def extract(%__MODULE__{pointer: pointer}) do
    {:ok, content} = Libxml.Nif.get_xml_char(pointer)
    %__MODULE__{
      pointer: pointer,
      content: content,
    }
  end
end
