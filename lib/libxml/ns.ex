defmodule Libxml.Ns do
  defstruct [:pointer, :next, :href, :prefix]

  def extract(%__MODULE__{pointer: pointer}) do
    {:ok, ns} = Libxml.Nif.get_xml_ns(pointer)
    %__MODULE__{
      pointer: pointer,
      next: Libxml.Util.ptr_to_type(Libxml.Ns, ns.next),
      href: Libxml.Util.ptr_to_type(Libxml.Char, ns.href),
      prefix: Libxml.Util.ptr_to_type(Libxml.Char, ns.prefix),
    }
  end
end
