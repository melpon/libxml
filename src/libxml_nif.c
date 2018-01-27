#include "erl_nif.h"

#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/c14n.h>
#include <libxml/xmlschemas.h>
#include <string.h>
#include <assert.h>

static ERL_NIF_TERM make_error(ErlNifEnv* env, const char* reason) {
  int ret;

  ERL_NIF_TERM error_atom;
  ret = enif_make_existing_atom_len(env, "error", 5, &error_atom, ERL_NIF_LATIN1);
  if (ret == 0) {
    return enif_make_badarg(env);
  }

  ErlNifBinary bin;
  int size = strlen(reason);
  ret = enif_alloc_binary(size, &bin);
  if (ret == 0) {
    return enif_make_badarg(env);
  }
  memcpy(bin.data, reason, size);

  ERL_NIF_TERM error = enif_make_binary(env, &bin);
  return enif_make_tuple2(env, error_atom, error);
}

static ERL_NIF_TERM make_ok(ErlNifEnv* env, ERL_NIF_TERM value) {
  ERL_NIF_TERM ok_atom = enif_make_atom_len(env, "ok", 2);
  if (enif_is_exception(env, ok_atom)) {
    return ok_atom;
  }

  return enif_make_tuple2(env, ok_atom, value);
}

// Eterm(integer) to Pointer
#define GET_POINTER(TYPE, NAME, ETERM) \
  TYPE NAME; \
  { \
    ErlNifUInt64 intptr; \
    int ret = enif_get_uint64(env, ETERM, &intptr); \
    if (ret == 0) { \
      return make_error(env, "failed_to_get_pointer"); \
    } \
    if (intptr == 0) { \
      return make_error(env, "null_pointer"); \
    } \
    NAME = (TYPE)intptr; \
  }

// Eterm(integer) to Pointer or null
#define GET_POINTER_OR_NULL(TYPE, NAME, ETERM) \
  TYPE NAME; \
  { \
    ErlNifUInt64 intptr; \
    int ret = enif_get_uint64(env, ETERM, &intptr); \
    if (ret == 0) { \
      return make_error(env, "failed_to_get_pointer"); \
    } \
    NAME = (TYPE)intptr; \
  }

// Eterm to Integer
#define GET_INT(NAME, VALUE) \
  int NAME; \
  { \
    int ret = enif_get_int(env, VALUE, &NAME); \
    if (ret == 0) { \
      return make_error(env, "failed_to_get_int"); \
    } \
  }

// Pointer to Eterm(integer)
#define SET_POINTER(ETERM_NAME, POINTER) \
  if (POINTER == NULL) { \
    return make_error(env, "pointer_is_null"); \
  } \
  ERL_NIF_TERM ETERM_NAME = enif_make_uint64(env, (ErlNifUInt64)POINTER)

// Pointer or Null to Eterm(integer)
#define SET_POINTER_OR_NULL(ETERM_NAME, POINTER) \
  ERL_NIF_TERM ETERM_NAME = enif_make_uint64(env, (ErlNifUInt64)POINTER)

// Eterm(binary) to ErlNifBinary
#define GET_BINARY(BIN_NAME, ETERM) \
  ErlNifBinary BIN_NAME; \
  { \
    int ret = enif_inspect_binary(env, ETERM, &BIN_NAME); \
    if (ret == 0) { \
      return make_error(env, "failed_to_inspect_binary"); \
    } \
  }

// Integer to Eterm(integer)
#define SET_INT(ETERM_NAME, VALUE) \
  ERL_NIF_TERM ETERM_NAME = enif_make_int(env, VALUE)

// Double to Eterm(double)
#define SET_DOUBLE(ETERM_NAME, VALUE) \
  ERL_NIF_TERM ETERM_NAME = enif_make_double(env, VALUE)

// Eterm(map) -> Eterm(any)
#define GET(MAP, NAME) \
  ERL_NIF_TERM NAME; \
  if (enif_get_map_value(env, MAP, enif_make_atom(env, #NAME), &NAME) == 0) \
    make_error(env, "failed_to_get_map_value")

// Eterm(any) -> Eterm(map)
#define PUT(MAP, NAME) \
  if (enif_make_map_put(env, MAP, enif_make_atom(env, #NAME), NAME, &MAP) == 0) \
    make_error(env, "failed_to_map_put")

static ERL_NIF_TERM xml_read_memory(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_BINARY(content, argv[0]);

  xmlDocPtr doc = xmlReadMemory((const char*)content.data, content.size, "noname.xml", NULL, 0);
  if (doc == NULL) {
    return make_error(env, "failed_to_parse_document");
  }

  SET_POINTER(ptr, doc);

  return make_ok(env, ptr);
}
static ERL_NIF_TERM xml_copy_doc(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlDocPtr, doc, argv[0]);
  if (doc->type != XML_DOCUMENT_NODE) {
    return enif_make_badarg(env);
  }
  GET_INT(recursive, argv[1]);

  xmlDocPtr doc2 = xmlCopyDoc(doc, recursive);
  if (doc2 == NULL) {
    return make_error(env, "failed_to_copy_document");
  }

  SET_POINTER(ptr, doc2);

  return make_ok(env, ptr);
}
static ERL_NIF_TERM xml_free_doc(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlDocPtr, doc, argv[0]);
  if (doc->type != XML_DOCUMENT_NODE) {
    return enif_make_badarg(env);
  }

  xmlFreeDoc(doc);

  return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM xml_doc_copy_node(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlNodePtr, node, argv[0]);
  GET_POINTER(xmlDocPtr, doc, argv[1]);
  if (doc->type != XML_DOCUMENT_NODE) {
    return enif_make_badarg(env);
  }
  GET_INT(extended, argv[2]);

  xmlNodePtr node2 = xmlDocCopyNode(node, doc, extended);
  if (node2 == NULL) {
    return make_error(env, "failed_to_doc_copy_node");
  }

  SET_POINTER(ptr, node2);

  return make_ok(env, ptr);
}

static ERL_NIF_TERM xml_doc_get_root_element(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlDocPtr, doc, argv[0]);
  if (doc->type != XML_DOCUMENT_NODE) {
    return enif_make_badarg(env);
  }

  xmlNodePtr node = xmlDocGetRootElement(doc);

  SET_POINTER_OR_NULL(ptr, node);

  return make_ok(env, ptr);
}

static ERL_NIF_TERM xml_doc_set_root_element(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlDocPtr, doc, argv[0]);
  if (doc->type != XML_DOCUMENT_NODE) {
    return enif_make_badarg(env);
  }
  GET_POINTER(xmlNodePtr, node, argv[1]);

  xmlNodePtr node2 = xmlDocSetRootElement(doc, node);

  SET_POINTER_OR_NULL(ptr, node2);

  return make_ok(env, ptr);
}

static ERL_NIF_TERM xml_new_ns(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlNodePtr, node, argv[0]);
  GET_BINARY(href, argv[1]);
  GET_BINARY(prefix, argv[2]);

  xmlChar* hrefstr = (xmlChar*)xmlMalloc(href.size + 1);
  if (hrefstr == NULL) {
    return make_error(env, "malloc_failed");
  }
  memcpy(hrefstr, href.data, href.size);
  hrefstr[href.size] = '\0';

  xmlChar* prefixstr = (xmlChar*)xmlMalloc(prefix.size + 1);
  if (prefixstr == NULL) {
    xmlFree(prefixstr);
    return make_error(env, "malloc_failed");
  }
  memcpy(prefixstr, prefix.data, prefix.size);
  prefixstr[prefix.size] = '\0';

  xmlNsPtr ns = xmlNewNs(node, hrefstr, prefixstr);
  xmlFree(hrefstr);
  xmlFree(prefixstr);
  if (ns == NULL) {
    return make_error(env, "failed_to_new_ns");
  }

  SET_POINTER(ptr, ns);

  return make_ok(env, ptr);
}

static ERL_NIF_TERM xml_copy_node(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlNodePtr, node, argv[0]);
  GET_INT(extended, argv[1]);

  xmlNodePtr node2 = xmlCopyNode(node, extended);
  if (node2 == NULL) {
    return make_error(env, "failed_to_copy_node");
  }

  SET_POINTER(ptr, node2);

  return make_ok(env, ptr);
}

static ERL_NIF_TERM xml_unlink_node(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlNodePtr, node, argv[0]);

  xmlUnlinkNode(node);

  return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM xml_free_node(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlNodePtr, node, argv[0]);

  xmlFreeNode(node);

  return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM xml_free_node_list(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlNodePtr, node, argv[0]);

  xmlFreeNodeList(node);

  return enif_make_atom(env, "ok");
}

static void free_xml_char_pp(xmlChar** pp, unsigned int len) {
  if (pp == NULL) return;
  for (int i = 0; i < len; i++) {
    if (pp[i] != NULL)
      xmlFree(pp[i]);
  }
  xmlFree(pp);
}

static ERL_NIF_TERM xml_c14n_doc_dump_memory(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlDocPtr, doc, argv[0]);
  if (doc->type != XML_DOCUMENT_NODE) {
    return enif_make_badarg(env);
  }
  GET_POINTER_OR_NULL(xmlNodeSetPtr, nodeset, argv[1]);
  GET_INT(mode, argv[2]);

  xmlChar** inclusive_ns_prefixes = NULL;
  unsigned int inclusive_ns_prefixes_length;
  {
    ERL_NIF_TERM list = argv[3];
    int ret;

    unsigned int len = 0;
    ret = enif_get_list_length(env, list, &len);
    if (ret == 0) {
      return make_error(env, "failed_to_get_list_length");
    }
    inclusive_ns_prefixes_length = len;

    if (len != 0) {
      inclusive_ns_prefixes = (xmlChar**)xmlMalloc((len + 1) * sizeof(xmlChar*));
      for (int i = 0; i < len; i++) {
        inclusive_ns_prefixes[i] = NULL;
      }
      inclusive_ns_prefixes[len] = NULL;

      for (int i = 0; i < len; i++) {
        ERL_NIF_TERM head;
        ret = enif_get_list_cell(env, list, &head, &list);
        assert(ret != 0);

        ErlNifBinary bin;
        ret = enif_inspect_binary(env, head, &bin);
        if (ret == 0) {
          free_xml_char_pp(inclusive_ns_prefixes, len);
          return make_error(env, "failed_to_inspect_binary");
        }

        inclusive_ns_prefixes[i] = (xmlChar*)xmlMalloc(bin.size + 1);
        if (inclusive_ns_prefixes[i] == NULL) {
          free_xml_char_pp(inclusive_ns_prefixes, len);
          return make_error(env, "failed_to_malloc");
        }
        memcpy(inclusive_ns_prefixes[i], bin.data, bin.size);
        inclusive_ns_prefixes[i][bin.size] = '\0';
      }
    }
  }

  GET_INT(with_comments, argv[4]);

  int ret;

  xmlChar* output;
  ret = xmlC14NDocDumpMemory(doc, nodeset, mode, inclusive_ns_prefixes, with_comments, &output);
  free_xml_char_pp(inclusive_ns_prefixes, inclusive_ns_prefixes_length);
  if (ret < 0) {
    return make_error(env, "failed_to_c14n_dump_memory");
  }

  ErlNifBinary bin;
  ret = enif_alloc_binary(ret, &bin);
  if (ret == 0) {
    xmlFree(output);
    return make_error(env, "bad_alloc");
  }
  memcpy(bin.data, output, bin.size);
  xmlFree(output);

  return make_ok(env, enif_make_binary(env, &bin));
}

static ERL_NIF_TERM xml_xpath_new_context(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlDocPtr, doc, argv[0]);
  if (doc->type != XML_DOCUMENT_NODE) {
    return enif_make_badarg(env);
  }

  xmlXPathContextPtr ctx = xmlXPathNewContext(doc);
  if (ctx == NULL) {
    return make_error(env, "xpath_new_context");
  }

  SET_POINTER(ptr, ctx);

  return make_ok(env, ptr);
}
static ERL_NIF_TERM xml_xpath_free_context(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlXPathContextPtr, ctx, argv[0]);

  xmlXPathFreeContext(ctx);

  return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM xml_xpath_eval(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlXPathContextPtr, ctx, argv[0]);
  GET_BINARY(strbin, argv[1]);

  xmlChar* xpath = (xmlChar*)xmlMalloc(strbin.size + 1);
  if (xpath == NULL) {
    return make_error(env, "malloc_failed");
  }
  memcpy(xpath, strbin.data, strbin.size);
  xpath[strbin.size] = '\0';

  xmlXPathObjectPtr obj = xmlXPathEval(xpath, ctx);
  xmlFree(xpath);
  if (obj == NULL) {
    return make_error(env, "xpath_eval");
  }

  SET_POINTER(ptr, obj);

  return make_ok(env, ptr);
}
static ERL_NIF_TERM xml_xpath_free_object(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlXPathObjectPtr, p, argv[0]);

  xmlXPathFreeObject(p);

  return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM get_xml_node(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlNodePtr, node, argv[0]);

  //void           *_private;   /* application data */
  //xmlElementType   type;      /* type number, must be second ! */
  //const xmlChar   *name;      /* the name of the node, or the entity */
  //struct _xmlNode *children;  /* parent->childs link */
  //struct _xmlNode *last;      /* last child link */
  //struct _xmlNode *parent;    /* child->parent link */
  //struct _xmlNode *next;      /* next sibling link  */
  //struct _xmlNode *prev;      /* previous sibling link  */
  //struct _xmlDoc  *doc;       /* the containing document */

  SET_POINTER_OR_NULL(private, node->_private);
  SET_INT(type, node->type);
  SET_POINTER_OR_NULL(name, node->name);
  SET_POINTER_OR_NULL(children, node->children);
  SET_POINTER_OR_NULL(last, node->last);
  SET_POINTER_OR_NULL(parent, node->parent);
  SET_POINTER_OR_NULL(next, node->next);
  SET_POINTER_OR_NULL(prev, node->prev);
  SET_POINTER_OR_NULL(doc, node->doc);

  ERL_NIF_TERM map = enif_make_new_map(env);

  PUT(map, private);
  PUT(map, type);
  PUT(map, name);
  PUT(map, children);
  PUT(map, last);
  PUT(map, parent);
  PUT(map, next);
  PUT(map, prev);
  PUT(map, doc);

  switch (node->type) {
  // special node types
  case XML_ATTRIBUTE_NODE:
    {
      //xmlAttrPtr:
      //xmlNs           *ns;        /* pointer to the associated namespace */
      //xmlAttributeType atype;     /* the attribute type if validating */
      //void            *psvi;      /* for type/PSVI informations */
      return make_ok(env, map);
    }
  case XML_DTD_NODE:
    {
      //xmlDtdPtr:
      //void          *notations;   /* Hash table for notations if any */
      //void          *elements;    /* Hash table for elements if any */
      //void          *attributes;  /* Hash table for attributes if any */
      //void          *entities;    /* Hash table for entities if any */
      //const xmlChar *ExternalID;  /* External identifier for PUBLIC DTD */
      //const xmlChar *SystemID;    /* URI for a SYSTEM or PUBLIC DTD */
      //void          *pentities;   /* Hash table for param entities if any */
      return make_ok(env, map);
    }
  case XML_ELEMENT_DECL:
    {
      //xmlElementPtr:
      //xmlElementTypeVal      etype;   /* The type */
      //xmlElementContentPtr content;   /* the allowed element content */
      //xmlAttributePtr   attributes;   /* List of the declared attributes */
      //const xmlChar        *prefix;   /* the namespace prefix if any */
      return make_ok(env, map);
    }
  case XML_ATTRIBUTE_DECL:
    {
      //xmlAttributePtr:
      //struct _xmlAttribute  *nexth;   /* next in hash table */
      //xmlAttributeType       atype;   /* The attribute type */
      //xmlAttributeDefault      def;   /* the default */
      //const xmlChar  *defaultValue;   /* or the default value */
      //xmlEnumerationPtr       tree;       /* or the enumeration tree if any */
      //const xmlChar        *prefix;   /* the namespace prefix if any */
      //const xmlChar          *elem;   /* Element holding the attribute */
      return make_ok(env, map);
    }
  case XML_DOCUMENT_NODE:
    {
      //xmlDocPtr:
      //int             compression;/* level of zlib compression */
      //int             standalone; /* standalone document (no external refs) 
      //                                 1 if standalone="yes"
      //                                 0 if standalone="no"
      //                                -1 if there is no XML declaration
      //                                -2 if there is an XML declaration, but no
      //                                    standalone attribute was specified */
      //struct _xmlDtd  *intSubset; /* the document internal subset */
      //struct _xmlDtd  *extSubset; /* the document external subset */
      //struct _xmlNs   *oldNs;     /* Global namespace, the old way */
      //const xmlChar  *version;    /* the XML version string */
      //const xmlChar  *encoding;   /* external initial encoding, if any */
      //void           *ids;        /* Hash table for ID attributes if any */
      //void           *refs;       /* Hash table for IDREFs attributes if any */
      //const xmlChar  *URL;        /* The URI for that document */
      //int             charset;    /* encoding of the in-memory content
      //                               actually an xmlCharEncoding */
      //struct _xmlDict *dict;      /* dict used to allocate names or NULL */
      //void           *psvi;       /* for type/PSVI informations */
      //int             parseFlags; /* set of xmlParserOption used to parse the
      //                               document */
      //int             properties; /* set of xmlDocProperties for this document
      //                               set at the end of parsing */
      return make_ok(env, map);
    }
  default:
    break;
  }

  //xmlNs           *ns;        /* pointer to the associated namespace */
  //xmlChar         *content;   /* the content */
  //struct _xmlAttr *properties;/* properties list */
  //xmlNs           *nsDef;     /* namespace definitions on this node */
  //void            *psvi;      /* for type/PSVI informations */
  //unsigned short   line;      /* line number */
  //unsigned short   extra;     /* extra data for XPath/XSLT */
  SET_POINTER_OR_NULL(ns, node->ns);
  SET_POINTER_OR_NULL(content, node->content);
  SET_POINTER_OR_NULL(properties, node->properties);
  SET_POINTER_OR_NULL(ns_def, node->nsDef);
  SET_INT(line, node->line);

  PUT(map, ns);
  PUT(map, content);
  PUT(map, properties);
  PUT(map, ns_def);
  PUT(map, line);

  return make_ok(env, map);
}

static ERL_NIF_TERM set_xml_node(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlNodePtr, p, argv[0]);
  ERL_NIF_TERM map = argv[1];

  GET(map, private);
  GET(map, type);
  GET(map, name);
  GET(map, children);
  GET(map, last);
  GET(map, parent);
  GET(map, next);
  GET(map, prev);
  GET(map, doc);

  GET_POINTER_OR_NULL(void*, private2, private);
  GET_INT(type2, type);
  GET_POINTER_OR_NULL(const xmlChar*, name2, name);
  GET_POINTER_OR_NULL(xmlNodePtr, children2, children);
  GET_POINTER_OR_NULL(xmlNodePtr, last2, last);
  GET_POINTER_OR_NULL(xmlNodePtr, parent2, parent);
  GET_POINTER_OR_NULL(xmlNodePtr, next2, next);
  GET_POINTER_OR_NULL(xmlNodePtr, prev2, prev);
  GET_POINTER_OR_NULL(xmlDocPtr, doc2, doc);

  p->_private = private2;
  p->type = type2;
  p->name = name2;
  p->children = children2;
  p->last = last2;
  p->parent = parent2;
  p->next = next2;
  p->prev = prev2;
  p->doc = doc2;

  switch (p->type) {
  // special node types
  case XML_ATTRIBUTE_NODE:
  case XML_DTD_NODE:
  case XML_ELEMENT_DECL:
  case XML_ATTRIBUTE_DECL:
  case XML_DOCUMENT_NODE:
    return enif_make_atom(env, "ok");
  default:
    break;
  }

  GET(map, ns);
  GET(map, content);
  GET(map, properties);
  GET(map, ns_def);
  GET(map, line);

  GET_POINTER_OR_NULL(xmlNsPtr, ns2, ns);
  GET_POINTER_OR_NULL(xmlChar*, content2, content);
  GET_POINTER_OR_NULL(xmlAttrPtr, properties2, properties);
  GET_POINTER_OR_NULL(xmlNsPtr, ns_def2, ns_def);
  GET_INT(line2, line);

  p->ns = ns2;
  p->content = content2;
  p->properties = properties2;
  p->nsDef = ns_def2;

  return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM get_xml_char(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlChar*, str, argv[0]);

  ErlNifBinary bin;
  int ret = enif_alloc_binary(strlen((const char*)str), &bin);
  if (ret == 0) {
    return make_error(env, "bad_alloc");
  }
  memcpy(bin.data, str, bin.size);

  return make_ok(env, enif_make_binary(env, &bin));
}

static ERL_NIF_TERM get_xml_ns(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlNsPtr, ns, argv[0]);

  ERL_NIF_TERM map = enif_make_new_map(env);

  SET_POINTER_OR_NULL(next, ns->next);
  SET_POINTER_OR_NULL(href, ns->href);
  SET_POINTER_OR_NULL(prefix, ns->prefix);

  PUT(map, next);
  PUT(map, href);
  PUT(map, prefix);

  return make_ok(env, map);
}

static ERL_NIF_TERM get_xml_xpath_context(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlXPathContextPtr, p, argv[0]);

  ERL_NIF_TERM map = enif_make_new_map(env);

  SET_POINTER(doc, p->doc);
  SET_POINTER_OR_NULL(node, p->node);

  PUT(map, doc);
  PUT(map, node);

  return make_ok(env, map);
}

static ERL_NIF_TERM set_xml_xpath_context(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlXPathContextPtr, p, argv[0]);
  ERL_NIF_TERM map = argv[1];

  GET(map, doc);
  GET(map, node);

  GET_POINTER(xmlDocPtr, doc2, doc);
  GET_POINTER_OR_NULL(xmlNodePtr, node2, node);

  p->doc = doc2;
  p->node = node2;

  return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM get_xml_xpath_object(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlXPathObjectPtr, p, argv[0]);

  //xmlXPathObjectType type;
  //xmlNodeSetPtr nodesetval;
  //int boolval;
  //double floatval;
  //xmlChar *stringval;
  //void *user;
  //int index;
  //void *user2;
  //int index2;

  ERL_NIF_TERM map = enif_make_new_map(env);

  SET_INT(type, p->type);
  PUT(map, type);

  switch (p->type) {
  case XPATH_UNDEFINED:
    break;
  case XPATH_NODESET:
    {
      SET_POINTER_OR_NULL(nodesetval, p->nodesetval);
      PUT(map, nodesetval);
    }
    break;
  case XPATH_XSLT_TREE:
    {
      SET_POINTER_OR_NULL(nodesetval, p->nodesetval);
      PUT(map, nodesetval);
    }
    break;
  case XPATH_BOOLEAN:
    {
      SET_INT(boolval, p->boolval);
      PUT(map, boolval);
    }
    break;
  case XPATH_NUMBER:
    {
      SET_DOUBLE(floatval, p->floatval);
      PUT(map, floatval);
    }
    break;
  case XPATH_STRING:
    {
      SET_POINTER_OR_NULL(stringval, p->stringval);
      PUT(map, stringval);
    }
    break;
  case XPATH_POINT:
    {
      SET_INT(index, p->index);
      SET_POINTER_OR_NULL(user, p->user);
      PUT(map, index);
      PUT(map, user);
    }
    break;
  case XPATH_RANGE:
    {
      SET_INT(index, p->index);
      SET_INT(index2, p->index2);
      SET_POINTER_OR_NULL(user, p->user);
      SET_POINTER_OR_NULL(user2, p->user2);
      PUT(map, index);
      PUT(map, index2);
      PUT(map, user);
      PUT(map, user2);
    }
    break;
  case XPATH_LOCATIONSET:
    {
      SET_POINTER_OR_NULL(user, p->user);
      PUT(map, user);
    }
    break;
  case XPATH_USERS:
    break;
  }
  return make_ok(env, map);
}

static ERL_NIF_TERM get_xml_node_set(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlNodeSetPtr, p, argv[0]);

  //int nodeNr;                 /* number of nodes in the set */
  //int nodeMax;                /* size of the array as allocated */
  //xmlNodePtr *nodeTab;        /* array of nodes in no particular order */
  ///* @@ with_ns to check wether namespace nodes should be looked at @@ */

  ERL_NIF_TERM map = enif_make_new_map(env);

  SET_INT(node_nr, p->nodeNr);
  SET_INT(node_max, p->nodeMax);

  ERL_NIF_TERM nodes = enif_make_list(env, 0);
  for (int i = p->nodeNr - 1; i >= 0; i--) {
    SET_POINTER(node_tab, p->nodeTab[i]);
    nodes = enif_make_list_cell(env, node_tab, nodes);
  }
  PUT(map, node_nr);
  PUT(map, node_max);
  PUT(map, nodes);

  return make_ok(env, map);
}

static ERL_NIF_TERM xml_schema_new_parser_ctxt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_BINARY(url, argv[0]);

  char* urlstr = (char*)xmlMalloc(url.size + 1);
  if (urlstr == NULL) {
    return make_error(env, "malloc_failed");
  }
  memcpy(urlstr, url.data, url.size);
  urlstr[url.size] = '\0';

  xmlSchemaParserCtxtPtr ctxt = xmlSchemaNewParserCtxt(urlstr);

  xmlFree(urlstr);

  SET_POINTER(ptr, ctxt);

  return make_ok(env, ptr);
}
static ERL_NIF_TERM xml_schema_new_doc_parser_ctxt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlDocPtr, doc, argv[0]);
  xmlSchemaParserCtxtPtr ctxt = xmlSchemaNewDocParserCtxt(doc);
  SET_POINTER(ptr, ctxt);
  return make_ok(env, ptr);
}
static ERL_NIF_TERM xml_schema_parse(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlSchemaParserCtxtPtr, ctxt, argv[0]);
  xmlSchemaPtr schema = xmlSchemaParse(ctxt);
  SET_POINTER(ptr, schema);
  return make_ok(env, ptr);
}
static ERL_NIF_TERM xml_schema_new_valid_ctxt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlSchemaPtr, schema, argv[0]);
  xmlSchemaValidCtxtPtr ctxt = xmlSchemaNewValidCtxt(schema);
  SET_POINTER(ptr, ctxt);
  return make_ok(env, ptr);
}
static ERL_NIF_TERM xml_schema_validate_doc(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlSchemaValidCtxtPtr, ctxt, argv[0]);
  GET_POINTER(xmlDocPtr, instance, argv[1]);
  int result = xmlSchemaValidateDoc(ctxt, instance);
  SET_INT(result_term, result);
  return make_ok(env, result_term);
}
static ERL_NIF_TERM xml_schema_free_parser_ctxt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlSchemaParserCtxtPtr, ctxt, argv[0]);
  xmlSchemaFreeParserCtxt(ctxt);
  return enif_make_atom(env, "ok");
}
static ERL_NIF_TERM xml_schema_free(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlSchemaPtr, schema, argv[0]);
  xmlSchemaFree(schema);
  return enif_make_atom(env, "ok");
}
static ERL_NIF_TERM xml_schema_free_valid_ctxt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  GET_POINTER(xmlSchemaValidCtxtPtr, ctxt, argv[0]);
  xmlSchemaFreeValidCtxt(ctxt);
  return enif_make_atom(env, "ok");
}

static ErlNifFunc nif_funcs[] = {
  // {erl_function_name, erl_function_arity, c_function}
  {"xml_read_memory", 1, xml_read_memory},
  {"xml_copy_doc", 2, xml_copy_doc},
  {"xml_free_doc", 1, xml_free_doc},

  {"xml_doc_copy_node", 3, xml_doc_copy_node},
  {"xml_doc_get_root_element", 1, xml_doc_get_root_element},
  {"xml_doc_set_root_element", 2, xml_doc_set_root_element},

  {"xml_new_ns", 3, xml_new_ns},

  {"xml_copy_node", 2, xml_copy_node},
  {"xml_unlink_node", 1, xml_unlink_node},
  {"xml_free_node", 1, xml_free_node},
  {"xml_free_node_list", 1, xml_free_node_list},

  {"xml_c14n_doc_dump_memory", 5, xml_c14n_doc_dump_memory},

  {"xml_xpath_new_context", 1, xml_xpath_new_context},
  {"xml_xpath_free_context", 1, xml_xpath_free_context},
  {"xml_xpath_eval", 2, xml_xpath_eval},
  {"xml_xpath_free_object", 1, xml_xpath_free_object},

  {"xml_schema_new_parser_ctxt", 1, xml_schema_new_parser_ctxt},
  {"xml_schema_new_doc_parser_ctxt", 1, xml_schema_new_doc_parser_ctxt},
  {"xml_schema_parse", 1, xml_schema_parse},
  {"xml_schema_new_valid_ctxt", 1, xml_schema_new_valid_ctxt},
  {"xml_schema_validate_doc", 2, xml_schema_validate_doc},
  {"xml_schema_free_parser_ctxt", 1, xml_schema_free_parser_ctxt},
  {"xml_schema_free", 1, xml_schema_free},
  {"xml_schema_free_valid_ctxt", 1, xml_schema_free_valid_ctxt},
  // {"xml_schema_set_parser_errors, 4, xml_schema_set_parser_errors},

  {"get_xml_node", 1, get_xml_node},
  {"set_xml_node", 2, set_xml_node},
  {"get_xml_char", 1, get_xml_char},
  {"get_xml_ns", 1, get_xml_ns},
  {"get_xml_xpath_context", 1, get_xml_xpath_context},
  {"set_xml_xpath_context", 2, set_xml_xpath_context},
  {"get_xml_xpath_object", 1, get_xml_xpath_object},
  {"get_xml_node_set", 1, get_xml_node_set},
};

ERL_NIF_INIT(Elixir.Libxml.Nif, nif_funcs, NULL, NULL, NULL, NULL)
