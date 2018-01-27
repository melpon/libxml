defmodule Libxml.Schema do
  defstruct [:pointer]

  defmodule ParserCtxt do
    defstruct [:pointer]
  end
  defmodule ValidCtxt do
    defstruct [:pointer]
  end

  def new_parser_ctxt(path) when is_binary(path) do
    {:ok, ctxt} = Libxml.Nif.xml_schema_new_parser_ctxt(path)
    %ParserCtxt{pointer: ctxt}
  end

  def new_doc_parser_ctxt(%Libxml.Node{} = doc) do
    {:ok, ctxt} = Libxml.Nif.xml_schema_new_doc_parser_ctxt(doc)
    %ParserCtxt{pointer: ctxt}
  end

  def parse(%ParserCtxt{} = ctxt) do
    {:ok, schema} = Libxml.Nif.xml_schema_parse(ctxt.pointer)
    %__MODULE__{pointer: schema}
  end

  def new_valid_ctxt(%__MODULE__{} = schema) do
    {:ok, ctxt} = Libxml.Nif.xml_schema_new_valid_ctxt(schema.pointer)
    %ValidCtxt{pointer: ctxt}
  end

  def validate_doc(%ValidCtxt{} = ctxt, %Libxml.Node{} = doc) do
    {:ok, ret} = Libxml.Nif.xml_schema_validate_doc(ctxt.pointer, doc.pointer)
    cond do
      ret == 0 -> :ok
      ret < 0 ->
        {:error, {:internal_error, ret}}
      ret > 0 ->
        {:error, {:validate_error, validate_error_to_atom(ret)}}
    end
  end

  def free_parser_ctxt(%ParserCtxt{} = ctxt) do
    :ok = Libxml.Nif.xml_schema_free_parser_ctxt(ctxt.pointer)
  end
  def free(schema) do
    :ok = Libxml.Nif.xml_schema_free(schema.pointer)
  end
  def free_valid_ctxt(ctxt) do
    :ok = Libxml.Nif.xml_schema_free_valid_ctxt(ctxt.pointer)
  end

  def safe_new_parser_ctxt(path, fun) when is_binary(path) do
    {:ok, ctxt} = Libxml.Nif.xml_schema_new_parser_ctxt(path)
    ctxt = %ParserCtxt{pointer: ctxt}

    try do
      fun.(ctxt)
    after
      free_parser_ctxt(ctxt)
    end
  end

  def safe_new_doc_parser_ctxt(%Libxml.Node{} = doc, fun) do
    {:ok, ctxt} = Libxml.Nif.xml_schema_new_doc_parser_ctxt(doc.pointer)
    ctxt = %ParserCtxt{pointer: ctxt}

    try do
      fun.(ctxt)
    after
      free_parser_ctxt(ctxt)
    end
  end

  def safe_parse(%ParserCtxt{} = ctxt, fun) do
    {:ok, schema} = Libxml.Nif.xml_schema_parse(ctxt.pointer)
    schema = %__MODULE__{pointer: schema}

    try do
      fun.(schema)
    after
      free(schema)
    end
  end

  def safe_new_valid_ctxt(%__MODULE__{} = schema, fun) do
    {:ok, ctxt} = Libxml.Nif.xml_schema_new_valid_ctxt(schema.pointer)
    ctxt = %ValidCtxt{pointer: ctxt}

    try do
      fun.(ctxt)
    after
      free_valid_ctxt(ctxt)
    end
  end

  @validate_errors [
    :ok,
    :noroot,
    :undeclaredelem,
    :nottoplevel,
    :missing,
    :wrongelem,
    :notype,
    :norollback,
    :isabstract,
    :notempty,
    :elemcont,
    :havedefault,
    :notnillable,
    :extracontent,
    :invalidattr,
    :invalidelem,
    :notdeterminist,
    :construct,
    :internal,
    :notsimple,
    :attrunknown,
    :attrinvalid,
    :value,
    :facet,
  ]
  defp validate_error_to_atom(value) do
    case Enum.fetch(@validate_errors, value) do
      {:ok, name} -> name
      :error -> :unknown
    end
  end
end
