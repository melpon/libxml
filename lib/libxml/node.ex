defmodule Libxml.Node do
  defstruct [
    :pointer,
    :private,
    :type,
    :name,
    :children,
    :last,
    :parent,
    :next,
    :prev,
    :doc,
    :more
  ]

  defmodule Default do
    defstruct [:ns, :content, :properties, :ns_def, :line]
  end

  defmodule TODO do
    defstruct []
  end

  @special_types [:attribute_node, :dtd_node, :element_decl, :attribute_decl, :document_node]
  def extract(%__MODULE__{pointer: pointer}) do
    {:ok, node} = Libxml.Nif.get_xml_node(pointer)

    result = %__MODULE__{
      pointer: pointer,
      private: node.private,
      type: node_type(node.type),
      name: Libxml.Util.ptr_to_type(Libxml.Char, node.name),
      children: Libxml.Util.ptr_to_type(Libxml.Node, node.children),
      last: Libxml.Util.ptr_to_type(Libxml.Node, node.last),
      parent: Libxml.Util.ptr_to_type(Libxml.Node, node.parent),
      next: Libxml.Util.ptr_to_type(Libxml.Node, node.next),
      prev: Libxml.Util.ptr_to_type(Libxml.Node, node.prev),
      doc: Libxml.Util.ptr_to_type(Libxml.Node, node.doc)
    }

    case result.type do
      type when type in @special_types ->
        %{result | more: %TODO{}}

      _ ->
        more = %__MODULE__.Default{
          ns: Libxml.Util.ptr_to_type(Libxml.Ns, node.ns),
          content: Libxml.Util.ptr_to_type(Libxml.Char, node.content),
          properties: Libxml.Util.ptr_to_type(Libxml.Node, node.properties),
          ns_def: Libxml.Util.ptr_to_type(Libxml.Ns, node.ns_def),
          line: node.line
        }

        %{result | more: more}
    end
  end

  def apply(%__MODULE__{pointer: pointer} = node) do
    map = %{
      private: node.private,
      type: rnode_type(node.type),
      name: Libxml.Util.type_to_ptr(node.name),
      children: Libxml.Util.type_to_ptr(node.children),
      last: Libxml.Util.type_to_ptr(node.last),
      parent: Libxml.Util.type_to_ptr(node.parent),
      next: Libxml.Util.type_to_ptr(node.next),
      prev: Libxml.Util.type_to_ptr(node.prev),
      doc: Libxml.Util.type_to_ptr(node.doc)
    }

    case node.type do
      type when type in @special_types ->
        :ok = Libxml.Nif.set_xml_node(pointer, map)

      _ ->
        more = %{
          ns: Libxml.Util.type_to_ptr(node.more.ns),
          content: Libxml.Util.type_to_ptr(node.more.content),
          properties: Libxml.Util.type_to_ptr(node.more.properties),
          ns_def: Libxml.Util.type_to_ptr(node.more.ns_def),
          line: node.more.line
        }

        :ok = Libxml.Nif.set_xml_node(pointer, Map.merge(map, more))
    end

    :ok
  end

  defp rnode_type(type) do
    try do
      for n <- 1..20 do
        if type == node_type(n) do
          throw(n)
        end
      end

      raise "not found"
    catch
      value -> value
    end
  end

  defp node_type(1), do: :element_node
  defp node_type(2), do: :attribute_node
  defp node_type(3), do: :text_node
  defp node_type(4), do: :cdata_section_node
  defp node_type(5), do: :entity_ref_node
  defp node_type(6), do: :entity_node
  defp node_type(7), do: :pi_node
  defp node_type(8), do: :comment_node
  defp node_type(9), do: :document_node
  defp node_type(10), do: :document_type_node
  defp node_type(11), do: :document_frag_node
  defp node_type(12), do: :notation_node
  defp node_type(13), do: :html_document_node
  defp node_type(14), do: :dtd_node
  defp node_type(15), do: :element_decl
  defp node_type(16), do: :attribute_decl
  defp node_type(17), do: :entity_decl
  defp node_type(18), do: :namespace_decl
  defp node_type(19), do: :xinclude_start
  defp node_type(20), do: :xinclude_end
end
