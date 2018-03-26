defmodule Libxml do
  def read_memory(contents) do
    {:ok, pointer} = Libxml.Nif.xml_read_memory(contents)
    %Libxml.Node{pointer: pointer}
  end

  def free_doc(%Libxml.Node{pointer: pointer}) do
    Libxml.Nif.xml_free_doc(pointer)
  end

  def safe_read_memory(contents, fun) do
    {:ok, pointer} = Libxml.Nif.xml_read_memory(contents)
    doc = %Libxml.Node{pointer: pointer}

    try do
      fun.(doc)
    after
      free_doc(doc)
    end
  end

  def copy_doc(%Libxml.Node{pointer: pointer}, recursive) do
    recursive_value = if recursive, do: 1, else: 0
    {:ok, pointer} = Libxml.Nif.xml_copy_doc(pointer, recursive_value)
    %Libxml.Node{pointer: pointer}
  end

  def safe_copy_doc(doc, recursive, fun) do
    doc = copy_doc(doc, recursive)

    try do
      fun.(doc)
    after
      free_doc(doc)
    end
  end

  def copy_node(%Libxml.Node{pointer: pointer}, extended) do
    extended_value =
      case extended do
        :shallow ->
          0

        # if 1 do a recursive copy (properties, namespaces and children when applicable)
        :recursive ->
          1

        # if 2 copy properties and namespaces (when applicable)
        :partial ->
          2
      end

    {:ok, pointer} = Libxml.Nif.xml_copy_node(pointer, extended_value)
    %Libxml.Node{pointer: pointer}
  end

  def safe_copy_node(node, extended, fun) do
    node = copy_node(node, extended)

    try do
      fun.(node)
    after
      free_node(node)
    end
  end

  def doc_copy_node(node, doc, extended) do
    extended_value =
      case extended do
        :shallow ->
          0

        # if 1 do a recursive copy (properties, namespaces and children when applicable)
        :recursive ->
          1

        # if 2 copy properties and namespaces (when applicable)
        :partial ->
          2
      end

    {:ok, pointer} = Libxml.Nif.xml_doc_copy_node(node.pointer, doc.pointer, extended_value)
    %Libxml.Node{pointer: pointer}
  end

  def safe_doc_copy_node(node, doc, extended, fun) do
    node = doc_copy_node(node, doc, extended)

    try do
      fun.(node)
    after
      free_node(node)
    end
  end

  def doc_get_root_element(%Libxml.Node{pointer: doc_pointer}) do
    {:ok, pointer} = Libxml.Nif.xml_doc_get_root_element(doc_pointer)
    Libxml.Util.ptr_to_type(Libxml.Node, pointer)
  end

  def doc_set_root_element(%Libxml.Node{pointer: doc_pointer}, %Libxml.Node{pointer: node_pointer}) do
    {:ok, pointer} = Libxml.Nif.xml_doc_set_root_element(doc_pointer, node_pointer)
    Libxml.Util.ptr_to_type(Libxml.Node, pointer)
  end

  def get_prop(%Libxml.Node{pointer: pointer}, attr_name) do
    {:ok, prop} = Libxml.Nif.xml_get_prop(pointer, attr_name)
    prop
  end

  def new_ns(%Libxml.Node{pointer: pointer}, href, prefix) do
    {:ok, pointer} = Libxml.Nif.xml_new_ns(pointer, href, prefix)
    %Libxml.Ns{pointer: pointer}
  end

  def unlink_node(%Libxml.Node{pointer: pointer}) do
    Libxml.Nif.xml_unlink_node(pointer)
  end

  def free_node(%Libxml.Node{pointer: pointer}) do
    Libxml.Nif.xml_free_node(pointer)
  end

  def free_node_list(%Libxml.Node{pointer: pointer}) do
    Libxml.Nif.xml_free_node_list(pointer)
  end
end
