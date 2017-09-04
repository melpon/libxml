defmodule Libxml.Util do
  def ptr_to_type(_struct, 0) do
    nil
  end
  def ptr_to_type(struct, pointer) do
    Kernel.struct(struct, pointer: pointer)
  end

  def type_to_ptr(nil) do
    0
  end
  def type_to_ptr(%{pointer: pointer}) do
    pointer
  end
end
