defmodule LibxmlTest do
  use ExUnit.Case
  doctest Libxml

  @content """
  <!DOCTYPE doc [<!ATTLIST normId id ID #IMPLIED>]>
  <doc>
     <text attribute="gibberish">First line&#x0d;&#10;Second line</text>
     <value>&#x32;</value>
     <compute><![CDATA[value>"0" && value<"10" ?"valid":"error"]]></compute>
     <compute expr='value>"0" &amp;&amp; value&lt;"10" ?"valid":"error"'>valid</compute>
     <norm attr=' &apos;   &#x20;&#13;&#xa;&#9;   &apos; '/>
     <normId id=' &apos;   &#x20;&#13;&#xa;&#9;   &apos; '/>
  </doc>
  """

  @expected1 """
             <doc>
                <text attribute="gibberish">First line&#xD;
             Second line</text>
                <value>2</value>
                <compute>value&gt;"0" &amp;&amp; value&lt;"10" ?"valid":"error"</compute>
                <compute expr="value>&quot;0&quot; &amp;&amp; value&lt;&quot;10&quot; ?&quot;valid&quot;:&quot;error&quot;">valid</compute>
                <norm attr=" '    &#xD;&#xA;&#x9;   ' "></norm>
                <normId id="' &#xD;&#xA;&#x9; '"></normId>
             </doc>
             """
             |> String.trim_trailing()

  @expected2 """
             <doc>
                <text attribute="gibberish">First line&#xD;
             Second line</text>
                <value>2</value>
                
                
                <norm attr=" '    &#xD;&#xA;&#x9;   ' "></norm>
                <normId id="' &#xD;&#xA;&#x9; '"></normId>
             </doc>
             """
             |> String.trim_trailing()

  test "readme" do
    content = "<doc></doc>"
    {:ok, docptr} = Libxml.Nif.xml_read_memory(content)
    {:ok, docvalue} = Libxml.Nif.get_xml_node(docptr)
    # IO.inspect docvalue
    # output:
    #   %{children: 140639374148016, doc: 140639374150976, last: 140639374148016,
    #      name: 0, next: 0, parent: 0, prev: 0, private: 0, type: 9}
    # XML_DOCUMENT_NODE
    assert docvalue.type == 9

    # update
    docvalue = %{docvalue | private: 100}
    # apply
    :ok = Libxml.Nif.set_xml_node(docptr, docvalue)

    # check
    {:ok, docvalue} = Libxml.Nif.get_xml_node(docptr)
    assert docvalue.private == 100

    # free a doc node
    Libxml.Nif.xml_free_doc(docptr)
  end

  test "readme2" do
    content = "<doc></doc>"
    node = %Libxml.Node{} = Libxml.read_memory(content)
    node = Libxml.Node.extract(node)
    # IO.inspect node
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

    # update
    node = %{node | private: 100}
    # apply
    :ok = Libxml.Node.apply(node)

    # check
    node = Libxml.Node.extract(node)
    assert node.private == 100

    # free a doc node
    Libxml.free_doc(node)
  end

  test "nif" do
    {:ok, doc} = Libxml.Nif.xml_read_memory(@content)
    {:ok, contents} = Libxml.Nif.xml_c14n_doc_dump_memory(doc, 0, 0, [], 1)
    assert @expected1 == contents

    {:ok, copied_doc} = Libxml.Nif.xml_copy_doc(doc, 1)
    {:ok, contents} = Libxml.Nif.xml_c14n_doc_dump_memory(copied_doc, 0, 0, [], 1)
    assert @expected1 == contents
    :ok = Libxml.Nif.xml_free_doc(copied_doc)

    {:ok, copied_doc} = Libxml.Nif.xml_copy_doc(doc, 0)
    {:ok, contents} = Libxml.Nif.xml_c14n_doc_dump_memory(copied_doc, 0, 0, [], 1)
    assert "" == contents
    :ok = Libxml.Nif.xml_free_doc(copied_doc)

    {:ok, node} = Libxml.Nif.get_xml_node(doc)
    # XML_DOCUMENT_NODE
    assert 9 == node.type

    {:ok, node} = Libxml.Nif.get_xml_node(node.children)
    # XML_DTD_NODE
    assert 14 == node.type

    {:ok, node} = Libxml.Nif.get_xml_node(node.next)
    # XML_ELEMENT_NODE
    assert 1 == node.type
    {:ok, name} = Libxml.Nif.get_xml_char(node.name)
    assert "doc" == name

    {:ok, node} = Libxml.Nif.get_xml_node(node.children)
    # XML_TEXT_NODE
    assert 3 == node.type
    {:ok, content} = Libxml.Nif.get_xml_char(node.content)
    assert "\n   " == content

    nodeptr = node.next
    {:ok, node} = Libxml.Nif.get_xml_node(nodeptr)
    # XML_ELEMENT_NODE
    assert 1 == node.type
    {:ok, name} = Libxml.Nif.get_xml_char(node.name)
    assert "text" == name

    # attribute
    {:ok, prop} = Libxml.Nif.xml_get_prop(nodeptr, "attribute")
    assert "gibberish" == prop

    {:ok, node} = Libxml.Nif.get_xml_node(node.children)
    # XML_TEXT_NODE
    assert 3 == node.type
    {:ok, content} = Libxml.Nif.get_xml_char(node.content)
    assert "First line\r\nSecond line" == content
    assert 0 == node.next

    {:ok, ctx} = Libxml.Nif.xml_xpath_new_context(doc)
    {:ok, p} = Libxml.Nif.xml_xpath_eval(ctx, "/doc/compute")

    {:ok, obj} = Libxml.Nif.get_xml_xpath_object(p)
    # XPATH_NODESET
    assert 1 == obj.type
    {:ok, ns} = Libxml.Nif.get_xml_node_set(obj.nodesetval)
    assert 2 == length(ns.nodes)

    for node <- ns.nodes do
      :ok = Libxml.Nif.xml_unlink_node(node)
      :ok = Libxml.Nif.xml_free_node(node)
    end

    {:ok, contents} = Libxml.Nif.xml_c14n_doc_dump_memory(doc, 0, 0, [], 1)

    Libxml.Nif.xml_xpath_free_object(p)
    Libxml.Nif.xml_xpath_free_context(ctx)
    Libxml.Nif.xml_free_doc(doc)

    assert @expected2 == contents
  end

  test "nif2" do
    {:ok, doc} = Libxml.Nif.xml_read_memory(@content)

    # get <doc> node
    {:ok, ctx} = Libxml.Nif.xml_xpath_new_context(doc)
    {:ok, p} = Libxml.Nif.xml_xpath_eval(ctx, "/doc")
    {:ok, obj} = Libxml.Nif.get_xml_xpath_object(p)
    {:ok, ns} = Libxml.Nif.get_xml_node_set(obj.nodesetval)
    doc_node = Enum.fetch!(ns.nodes, 0)
    :ok = Libxml.Nif.xml_xpath_free_object(p)
    :ok = Libxml.Nif.xml_xpath_free_context(ctx)

    # get <value> node from <doc> node
    {:ok, ctx} = Libxml.Nif.xml_xpath_new_context(doc)
    {:ok, ctx_value} = Libxml.Nif.get_xml_xpath_context(ctx)
    ctx_value = %{ctx_value | node: doc_node}
    :ok = Libxml.Nif.set_xml_xpath_context(ctx, ctx_value)
    {:ok, p} = Libxml.Nif.xml_xpath_eval(ctx, "./value")
    {:ok, obj} = Libxml.Nif.get_xml_xpath_object(p)
    {:ok, ns} = Libxml.Nif.get_xml_node_set(obj.nodesetval)
    assert 1 == length(ns.nodes)
    value_node = Enum.fetch!(ns.nodes, 0)
    :ok = Libxml.Nif.xml_xpath_free_object(p)
    :ok = Libxml.Nif.xml_xpath_free_context(ctx)

    {:ok, node} = Libxml.Nif.get_xml_node(value_node)
    # XML_ELEMENT_NODE
    assert 1 == node.type
    {:ok, name} = Libxml.Nif.get_xml_char(node.name)
    assert "value" == name

    {:ok, node} = Libxml.Nif.get_xml_node(node.children)
    # XML_TEXT_NODE
    assert 3 == node.type
    {:ok, content} = Libxml.Nif.get_xml_char(node.content)
    assert "2" == content
  end

  test "fun" do
    Libxml.safe_read_memory(@content, fn doc ->
      contents = Libxml.C14N.doc_dump_memory(doc, nil, :c14n_1_0, [], false)
      assert @expected1 == contents

      Libxml.safe_copy_doc(doc, true, fn copied_doc ->
        contents = Libxml.C14N.doc_dump_memory(copied_doc, nil, :c14n_1_0, [], false)
        assert @expected1 == contents
      end)

      Libxml.safe_copy_doc(doc, false, fn copied_doc ->
        contents = Libxml.C14N.doc_dump_memory(copied_doc, nil, :c14n_1_0, [], false)
        assert "" == contents
      end)

      doc = Libxml.Node.extract(doc)
      assert :document_node == doc.type

      node = Libxml.Node.extract(doc.children)
      assert :dtd_node == node.type

      node = Libxml.Node.extract(node.next)
      assert :element_node == node.type
      name = Libxml.Char.extract(node.name)
      assert "doc" == name.content

      node = Libxml.Node.extract(node.children)
      assert :text_node == node.type
      content = Libxml.Char.extract(node.more.content)
      assert "\n   " == content.content

      node = Libxml.Node.extract(node.next)
      assert :element_node == node.type
      name = Libxml.Char.extract(node.name)
      assert "text" == name.content

      assert "gibberish" == Libxml.get_prop(node, "attribute")

      node = Libxml.Node.extract(node.children)
      assert :text_node == node.type
      content = Libxml.Char.extract(node.more.content)
      assert "First line\r\nSecond line" == content.content
      assert nil == node.next

      Libxml.XPath.safe_new_context(doc, fn ctx ->
        Libxml.XPath.safe_eval(ctx, "/doc/compute", fn obj ->
          obj = Libxml.XPath.Object.extract(obj)
          assert :nodeset == obj.type

          nodeset = Libxml.XPath.NodeSet.extract(obj.content)
          assert 2 == length(nodeset.nodes)

          for node <- nodeset.nodes do
            :ok = Libxml.unlink_node(node)
            :ok = Libxml.free_node(node)
          end
        end)
      end)

      content = Libxml.C14N.doc_dump_memory(doc, nil, :c14n_1_0, [], false)
      assert @expected2 == content
    end)
  end

  test "fun2" do
    Libxml.safe_read_memory(@content, fn doc ->
      # get <doc> node
      doc_node =
        Libxml.XPath.safe_new_context(doc, fn ctx ->
          Libxml.XPath.safe_eval(ctx, "/doc", fn p ->
            p = Libxml.XPath.Object.extract(p)
            ns = Libxml.XPath.NodeSet.extract(p.content)
            Enum.fetch!(ns.nodes, 0)
          end)
        end)

      # get <value> node from <doc> node
      value_node =
        Libxml.XPath.safe_new_context(doc, fn ctx ->
          ctx = Libxml.XPath.Context.extract(ctx)
          ctx = %{ctx | node: doc_node}
          :ok = Libxml.XPath.Context.apply(ctx)

          Libxml.XPath.safe_eval(ctx, "./value", fn p ->
            p = Libxml.XPath.Object.extract(p)
            ns = Libxml.XPath.NodeSet.extract(p.content)
            assert 1 == length(ns.nodes)
            Enum.fetch!(ns.nodes, 0)
          end)
        end)

      node = Libxml.Node.extract(value_node)
      assert :element_node == node.type
      name = Libxml.Char.extract(node.name)
      assert "value" == name.content

      node = Libxml.Node.extract(node.children)
      assert :text_node == node.type
      content = Libxml.Char.extract(node.more.content)
      assert "2" == content.content
    end)
  end

  test "XML Schema NIF" do
    {:ok, parser_ctxt} = Libxml.Nif.xml_schema_new_parser_ctxt("test/all_0.xsd")
    assert 0 != parser_ctxt
    {:ok, {schema, []}} = Libxml.Nif.xml_schema_parse(parser_ctxt)
    assert 0 != schema
    :ok = Libxml.Nif.xml_schema_free_parser_ctxt(parser_ctxt)

    content = "<doc><a/><b/><c/></doc>"
    {:ok, doc} = Libxml.Nif.xml_read_memory(content)
    assert 0 != doc
    {:ok, ctxt} = Libxml.Nif.xml_schema_new_valid_ctxt(schema)
    assert 0 != ctxt
    {:ok, ret} = Libxml.Nif.xml_schema_validate_doc(ctxt, doc)
    assert {0, []} == ret

    Libxml.Nif.xml_schema_free_valid_ctxt(ctxt)
    Libxml.Nif.xml_free_doc(doc)
    Libxml.Nif.xml_schema_free(schema)
  end

  test "XML Schema" do
    fun = fn ctxt ->
      Libxml.Schema.safe_parse(ctxt, fn schema, _ ->
        content = "<doc><a/><b/><c/></doc>"

        Libxml.safe_read_memory(content, fn doc ->
          Libxml.Schema.safe_new_valid_ctxt(schema, fn ctxt ->
            ret = Libxml.Schema.validate_doc(ctxt, doc)
            assert {:ok, []} == ret
          end)
        end)
      end)
    end

    Libxml.Schema.safe_new_parser_ctxt("test/all_0.xsd", fun)

    content = File.read!("test/all_0.xsd")

    Libxml.safe_read_memory(content, fn doc ->
      Libxml.Schema.safe_new_doc_parser_ctxt(doc, fun)
    end)
  end

  test "XML Schema with invalid document" do
    Libxml.Schema.safe_new_parser_ctxt("test/all_0.xsd", fn ctxt ->
      Libxml.Schema.safe_parse(ctxt, fn schema, _ ->
        content = "<doc><a/><b/></doc>"

        Libxml.safe_read_memory(content, fn doc ->
          Libxml.Schema.safe_new_valid_ctxt(schema, fn ctxt ->
            ret = Libxml.Schema.validate_doc(ctxt, doc)

            error = %Libxml.Error{
              domain: :from_schemasv,
              code: :schemav_element_content,
              level: :err_error,
              file: "noname.xml",
              line: 1,
              message: "Element 'doc': Missing child element(s). Expected is ( c ).\n",
              str1: "",
              str2: "",
              str3: "",
              int1: 0,
              int2: 0
            }

            assert {:error, [error]} == ret
          end)
        end)
      end)
    end)
  end

  @content """
  <?xml version="1.0" encoding="UTF-8"?>

  <foo xmlns="http://example.com/XMLSchema/1.0">
  </foo>
  """

  @schema """
  <?xml version="1.0" encoding="utf-8" ?>
  <!DOCTYPE xs:schema PUBLIC "-//W3C//DTD XMLSCHEMA 200102//EN" "XMLSchema.dtd" >
  <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns="http://example.com/XMLSchema/1.0" targetNamespace="http://example.com/XMLSchema/1.0" elementFormDefault="qualified" attributeFormDefault="unqualified">

      <xs:element name="foo">
      </xs:element>
  </xs:schema>
  """

  test "XML Schema from https://stackoverflow.com/questions/6284827/why-does-this-xml-validation-via-xsd-fail-in-libxml2-but-succeed-in-xmllint-an" do
    Libxml.safe_read_memory(@schema, fn doc ->
      Libxml.Schema.safe_new_doc_parser_ctxt(doc, fn ctxt ->
        Libxml.Schema.safe_parse(ctxt, fn schema, _ ->
          Libxml.safe_read_memory(@content, fn doc ->
            Libxml.Schema.safe_new_valid_ctxt(schema, fn ctxt ->
              ret = Libxml.Schema.validate_doc(ctxt, doc)
              assert {:ok, []} == ret
            end)
          end)
        end)
      end)
    end)
  end

  @schema """
  <?xml version="1.0" encoding="utf-8" ?>
  <!DOCTYPE xs:schema PUBLIC "-//W3C//DTD XMLSCHEMA 200102//EN" "XMLSchema.dtd" >
  <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns="http://example.com/XMLSchema/1.0" targetNamespace="http://example.com/XMLSchema/1.0" elementFormDefault="qualified" attributeFormDefault="unqualified">
      <xs:hoge name="foo">
      </xs:hoge>
  </xs:schema>
  """

  test "invalid XML Schema" do
    Libxml.safe_read_memory(@schema, fn doc ->
      Libxml.Schema.safe_new_doc_parser_ctxt(doc, fn ctxt ->
        Libxml.Schema.safe_parse(ctxt, fn schema, errors ->
          assert 0 == schema.pointer

          error = %Libxml.Error{
            domain: :from_schemasp,
            code: :schemap_s4s_elem_not_allowed,
            level: :err_error,
            file: "noname.xml",
            line: 4,
            message:
              "Element '{http://www.w3.org/2001/XMLSchema}schema': The content is not valid. Expected is ((include | import | redefine | annotation)*, (((simpleType | complexType | group | attributeGroup) | element | attribute | notation), annotation*)*).\n",
            str1: "Element '{http://www.w3.org/2001/XMLSchema}schema'",
            str2:
              "((include | import | redefine | annotation)*, (((simpleType | complexType | group | attributeGroup) | element | attribute | notation), annotation*)*)",
            str3: "",
            int1: 0,
            int2: 0
          }

          assert [error] == errors
        end)
      end)
    end)
  end
end
