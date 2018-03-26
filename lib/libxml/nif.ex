defmodule Libxml.Nif do
  @on_load :load_nif

  def load_nif() do
    :ok = :erlang.load_nif(:code.lib_dir(:libxml) ++ '/priv/libxml_nif', 0)
  end

  def xml_read_memory(_contents), do: raise("NIF not implemented")
  def xml_copy_doc(_doc, _recursive), do: raise("NIF not implemented")
  def xml_free_doc(_doc), do: raise("NIF not implemented")

  def xml_get_prop(_char, _attr_name), do: raise("NIF not implemented")

  def xml_doc_copy_node(_node, _doc, _extended), do: raise("NIF not implemented")
  def xml_doc_get_root_element(_doc), do: raise("NIF not implemented")
  def xml_doc_set_root_element(_doc, _node), do: raise("NIF not implemented")

  def xml_new_ns(_node, _href, _prefix), do: raise("NIF not implemented")

  def xml_unlink_node(_node), do: raise("NIF not implemented")
  def xml_copy_node(_node, _extended), do: raise("NIF not implemented")
  def xml_free_node(_node), do: raise("NIF not implemented")
  def xml_free_node_list(_node), do: raise("NIF not implemented")

  def xml_c14n_doc_dump_memory(_doc, _nodeset, _mode, _inclusive_ns_prefixes, _with_comments),
    do: raise("NIF not implemented")

  def xml_xpath_new_context(_doc), do: raise("NIF not implemented")
  def xml_xpath_free_context(_context), do: raise("NIF not implemented")
  def xml_xpath_eval(_ctx, _xpath), do: raise("NIF not implemented")
  def xml_xpath_free_object(_obj), do: raise("NIF not implemented")

  def xml_schema_new_parser_ctxt(_url), do: raise("NIF not implemented")
  def xml_schema_new_doc_parser_ctxt(_doc), do: raise("NIF not implemented")
  def xml_schema_parse(_ctxt), do: raise("NIF not implemented")
  def xml_schema_new_valid_ctxt(_schema), do: raise("NIF not implemented")
  def xml_schema_validate_doc(_ctxt, _doc), do: raise("NIF not implemented")
  def xml_schema_free_parser_ctxt(_ctxt), do: raise("NIF not implemented")
  def xml_schema_free(_schema), do: raise("NIF not implemented")
  def xml_schema_free_valid_ctxt(_ctxt), do: raise("NIF not implemented")
  # def xml_schema_set_parser_errors(_ctxt, _err, _warn, _ctx), do: raise("NIF not implemented")

  def get_xml_node(_node), do: raise("NIF not implemented")
  def set_xml_node(_node, _map), do: raise("NIF not implemented")
  def get_xml_char(_char), do: raise("NIF not implemented")
  def get_xml_ns(_ns), do: raise("NIF not implemented")
  def get_xml_xpath_context(_obj), do: raise("NIF not implemented")
  def set_xml_xpath_context(_obj, _map), do: raise("NIF not implemented")
  def get_xml_xpath_object(_obj), do: raise("NIF not implemented")
  def get_xml_node_set(_nodeset), do: raise("NIF not implemented")
end
