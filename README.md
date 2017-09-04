# Libxml

Thin wrapper for Libxml2 using NIF

## NIF

NIF for Libxml2 are defined in `Libxml.Nif`.

These functions are **thin** wrapper.
You should manage yourself the memory allocation and deallocation.

For example, `Libxml.Nif.xml_read_memory/1` corresponds to [`xmlReadMemory`](http://xmlsoft.org/html/libxml-parser.html#xmlReadMemory) in Libxml2.
`xmlReadMemory` returns `xmlDocPtr` pointer. `Libxml.Nif.xml_read_memory/1` returns the pointer value as integer.

If you want to see inside the `xmlDocPtr` pointer, call `Libxml.Nif.get_xml_node/1`.
If you want to apply a value to `xmlDocPtr`, call `Libxml.Nif.set_xml_node/2`.

```elixir
content = "<doc></doc>"
{:ok, docptr} = Libxml.Nif.xml_read_memory(content)
{:ok, docvalue} = Libxml.Nif.get_xml_node(docptr)
IO.inspect docvalue
# output:
#   %{children: 140639374148016, doc: 140639374150976, last: 140639374148016,
#      name: 0, next: 0, parent: 0, prev: 0, private: 0, type: 9}
assert docvalue.type == 9 # XML_DOCUMENT_NODE

children = docvalue.children

# update
docvalue = %{docvalue | children: 0}
:ok = Libxml.Nif.set_xml_node(docptr, docvalue) # apply

# check
{:ok, docvalue} = Libxml.Nif.get_xml_node(docptr)
assert docvalue.children == 0

# free a doc node, but the child node doesn't free yet
Libxml.Nif.xml_free_doc(docptr)

# free the child node
Libxml.Nif.xml_free_node(children)
```

## Typed Thin Wrapper

NIF is incovinient, so I provide typed thin wrapper.

For example, `Libxml.read_memory/1` corresponds to xmlReadMemory in Libxml2.
`Libxml.read_memory/1` returns a value type of `%Libxml.Node{}`.
`%Libxml.Node{}` has `:pointer` field. The pointer value returned the function is assined this field.

If you want to see inside the `xmlDocPtr` pointer, call `Libxml.Node.extract/1`.
If you want to apply a value to `xmlDocPtr`, call `Libxml.Node.apply/1`.

```elixir
content = "<doc></doc>"
node = %Libxml.Node{} = Libxml.read_memory(content)
node = Libxml.Node.extract(node)
IO.inspect node
# output:
#   %Libxml.Node{children: %Libxml.Node{children: nil, doc: nil, last: nil,
#     more: nil, name: nil, next: nil, parent: nil, pointer: 140551835942432,
#     prev: nil, private: nil, type: nil},
#    doc: %Libxml.Node{children: nil, doc: nil, last: nil, more: nil, name: nil,
#     next: nil, parent: nil, pointer: 140551835942128, prev: nil, private: nil,
#     type: nil},
#    last: %Libxml.Node{children: nil, doc: nil, last: nil, more: nil, name: nil,
#     next: nil, parent: nil, pointer: 140551835942432, prev: nil, private: nil,
#     type: nil}, more: %Libxml.Node.TODO{}, name: nil, next: nil, parent: nil,
#    pointer: 140551835942128, prev: nil, private: 0, type: :document_node}
assert node.type == :document_node

children = node.children

# update
node = %{node | children: nil}
:ok = Libxml.Node.apply(node) # apply

# check
node = Libxml.Node.extract(node)
assert node.children == nil

# free a doc node, but the child node doesn't free yet
Libxml.free_doc(node)

# free the child node
Libxml.free_node(children)
```
