defmodule Libxml.XPath do
  defmodule Context do
    defstruct [:pointer, :doc, :node]

    def extract(%__MODULE__{pointer: pointer}) do
      {:ok, ctx} = Libxml.Nif.get_xml_xpath_context(pointer)

      %__MODULE__{
        pointer: pointer,
        doc: %Libxml.Node{pointer: ctx.doc},
        node: Libxml.Util.ptr_to_type(Libxml.Node, ctx.node)
      }
    end

    def apply(%__MODULE__{pointer: pointer, doc: doc, node: node}) do
      map = %{
        doc: doc.pointer,
        node: Libxml.Util.type_to_ptr(node)
      }

      :ok = Libxml.Nif.set_xml_xpath_context(pointer, map)
      :ok
    end
  end

  defmodule NodeSet do
    defstruct [:pointer, :nodes]

    def extract(%__MODULE__{pointer: pointer}) do
      {:ok, nodeset} = Libxml.Nif.get_xml_node_set(pointer)

      nodes =
        for node <- nodeset.nodes do
          %Libxml.Node{pointer: node}
        end

      %__MODULE__{
        pointer: pointer,
        nodes: nodes
      }
    end
  end

  defmodule Object do
    defstruct [:pointer, :type, :content]

    def extract(%__MODULE__{pointer: pointer}) do
      {:ok, obj} = Libxml.Nif.get_xml_xpath_object(pointer)

      type = obj_type(obj.type)

      content =
        case type do
          :undefined -> nil
          :nodeset -> Libxml.Util.ptr_to_type(Libxml.XPath.NodeSet, obj.nodesetval)
          :boolean -> obj.boolval != 0
          :number -> obj.floatval
          :string -> Libxml.Util.ptr_to_type(Libxml.Char, obj.stringval)
          :point -> %{index: obj.index, user: obj.user}
          :range -> %{index: obj.index, index2: obj.index2, user: obj.user, user2: obj.user2}
          :locationset -> %{user: obj.user}
          :users -> nil
          :xslt_tree -> Libxml.Util.ptr_to_type(Libxml.XPath.NodeSet, obj.nodesetval)
        end

      %__MODULE__{
        pointer: pointer,
        type: type,
        content: content
      }
    end

    defp obj_type(0), do: :undefined
    defp obj_type(1), do: :nodeset
    defp obj_type(2), do: :boolean
    defp obj_type(3), do: :number
    defp obj_type(4), do: :string
    defp obj_type(5), do: :point
    defp obj_type(6), do: :range
    defp obj_type(7), do: :locationset
    defp obj_type(8), do: :users
    defp obj_type(9), do: :xslt_tree
  end

  def new_context(%Libxml.Node{pointer: pointer, type: _document_node}) do
    {:ok, pointer} = Libxml.Nif.xml_xpath_new_context(pointer)
    %Libxml.XPath.Context{pointer: pointer}
  end

  def free_context(%Libxml.XPath.Context{pointer: pointer}) do
    Libxml.Nif.xml_xpath_free_context(pointer)
  end

  def safe_new_context(doc, fun) do
    context = new_context(doc)

    try do
      fun.(context)
    after
      free_context(context)
    end
  end

  def eval(%Libxml.XPath.Context{pointer: pointer}, xpath) do
    {:ok, pointer} = Libxml.Nif.xml_xpath_eval(pointer, xpath)
    %Libxml.XPath.Object{pointer: pointer}
  end

  def free_object(%Libxml.XPath.Object{pointer: pointer}) do
    Libxml.Nif.xml_xpath_free_object(pointer)
  end

  def safe_eval(context, xpath, fun) do
    obj = eval(context, xpath)

    try do
      fun.(obj)
    after
      free_object(obj)
    end
  end
end
