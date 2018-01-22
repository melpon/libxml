defmodule Libxml.C14N do
  def doc_dump_memory(node, nodeset, mode, inclusive_ns_prefixes, with_comments) do
    %Libxml.Node{pointer: pointer, type: _document_node} = node

    nodeset_value =
      case nodeset do
        nil -> 0
        %Libxml.XPath.NodeSet{pointer: pointer} -> pointer
      end

    mode_value =
      case mode do
        :c14n_1_0 -> 0
        :c14n_exclusive_1_0 -> 1
        :c14n_1_1 -> 2
      end

    with_comments_value =
      case with_comments do
        true -> 1
        false -> 0
      end

    {:ok, content} = Libxml.Nif.xml_c14n_doc_dump_memory(pointer, nodeset_value, mode_value, inclusive_ns_prefixes, with_comments_value)

    content
  end
end
