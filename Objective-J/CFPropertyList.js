
var OBJECT_COUNT   = 0;

function generateObjectUID()
{
    return OBJECT_COUNT++;
}

function CFPropertyList()
{
    this._UID = generateObjectUID();
}

// We are really liberal when accepting DOCTYPEs.
CFPropertyList.DTDRE = /^\s*(?:<\?\s*xml\s+version\s*=\s*\"1.0\"[^>]*\?>\s*)?(?:<\!DOCTYPE[^>]*>\s*)?/i
CFPropertyList.XMLRE = /^\s*(?:<\?\s*xml\s+version\s*=\s*\"1.0\"[^>]*\?>\s*)?(?:<\!DOCTYPE[^>]*>\s*)?<\s*plist[^>]*\>/i;

CFPropertyList.FormatXMLDTD = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">";
CFPropertyList.Format280NorthMagicNumber = "280NPLIST";

// Serialization Formats

CFPropertyList.FormatOpenStep         = 1,
CFPropertyList.FormatXML_v1_0         = 100,
CFPropertyList.FormatBinary_v1_0      = 200,
CFPropertyList.Format280North_v1_0    = -1000;

CFPropertyList.sniffedFormatOfString = function(/*String*/ aString)
{
    // Check if this is an XML Plist.
    if (aString.match(CFPropertyList.XMLRE))
        return CFPropertyList.FormatXML_v1_0;

    if (aString.substr(0, CFPropertyList.Format280NorthMagicNumber.length) === CFPropertyList.Format280NorthMagicNumber)
       return CFPropertyList.Format280North_v1_0;

    return NULL;
}

// Serialization

CFPropertyList.dataFromPropertyList = function(/*CFPropertyList*/ aPropertyList, /*Format*/ aFormat)
{
    var data = new CFMutableData();

    data.setEncodedString(CFPropertyList.stringFromPropertyList(aPropertyList, aFormat));

    return data;
}

CFPropertyList.stringFromPropertyList = function(/*CFPropertyList*/ aPropertyList, /*Format*/ aFormat)
{
    if (!aFormat)
        aFormat = CFPropertyList.Format280North_v1_0;

    var serializers = CFPropertyListSerializers[aFormat];

    return  serializers["start"]() +
            serializePropertyList(aPropertyList, serializers) +
            serializers["finish"]();
}

function serializePropertyList(/*CFPropertyList*/ aPropertyList, /*Object*/ serializers)
{
    var type = typeof aPropertyList,
        valueOf = aPropertyList.valueOf(),
        typeValueOf = typeof valueOf;

    if (type !== typeValueOf)
    {
        type = typeValueOf;
        aPropertyList = valueOf;
    }

    if (aPropertyList === YES || aPropertyList === NO)
        type = "boolean";
    
    else if (type === "number")
    {
        if (FLOOR(aPropertyList) === aPropertyList)
            type = "integer";
        else
            type = "real";
    }
    
    else if (type !== "string")
    {
        if (aPropertyList.slice)
            type = "array";
    
        else
            type = "dictionary";
    }

    return serializers[type](aPropertyList, serializers);
}

var CFPropertyListSerializers = { };

CFPropertyListSerializers[CFPropertyList.FormatXML_v1_0] =
{
    "start":        function()
                    {
                        return CFPropertyList.FormatXMLDTD + "<plist version = \"1.0\">";
                    },

    "finish":       function()
                    {
                        return "</plist>";
                    },

    "string":       function(/*String*/ aString)
                    {
                        return "<string>" + encodeHTMLComponent(aString) + "</string>";;
                    },

    "boolean" :     function(/*Boolean*/ aBoolean)
                    {
                        return aBoolean ? "<true/>" : "<false/>";
                    },

    "integer":      function(/*Integer*/ anInteger)
                    {
                        return "<integer>" + anInteger + "</integer>";
                    },

    "real":         function(/*Float*/ aFloat)
                    {
                        return "<real>" + aFloat + "</real>";
                    },

    "array":        function(/*Array*/ anArray, /*Object*/ serializers)
                    {
                        var index = 0,
                            count = anArray.length,
                            string = "<array>";

                        for (; index < count; ++index)
                            string += serializePropertyList(anArray[index], serializers);
    
                        return string + "</array>";
                    },

    "dictionary":   function(/*CFDictionary*/ aDictionary, /*Object*/ serializers)
                    {
                        var keys = aDictionary._keys,
                            index = 0,
                            count = keys.length,
                            string = "<dict>";

                        for (; index < count; ++index)
                        {
                            var key = keys[index];

                            string += "<key>" + key + "</key>";
                            string += serializePropertyList(aDictionary.valueForKey(key), serializers);
                        }

                        return string + "</dict>";
                    }
}

// 280 North Plist Format

var ARRAY_MARKER        = "A",
    DICTIONARY_MARKER   = "D",
    FLOAT_MARKER        = "f",
    INTEGER_MARKER      = "d",
    STRING_MARKER       = "S",
    TRUE_MARKER         = "T",
    FALSE_MARKER        = "F",
    KEY_MARKER          = "K",
    END_MARKER          = "E";

CFPropertyListSerializers[CFPropertyList.Format280North_v1_0] =
{
    "start":        function()
                    {
                        return CFPropertyList.Format280NorthMagicNumber + ";1.0;";
                    },

    "finish":       function()
                    {
                        return "";
                    },

    "string" :      function(/*String*/ aString)
                    {
                        return STRING_MARKER + ';' + aString.length + ';' + aString;
                    },
    
    "boolean" :     function(/*Boolean*/ aBoolean)
                    {
                        return (aBoolean ? TRUE_MARKER : FALSE_MARKER) + ';';
                    },

    "integer":      function(/*Integer*/ anInteger)
                    {
                        var string = "" + anInteger;
    
                        return INTEGER_MARKER + ';' + string.length + ';' + string;
                    },

    "real":         function(/*Float*/ aFloat)
                    {
                        var string = "" + aFloat;
    
                        return FLOAT_MARKER + ';' + string.length + ';' + string;
                    },

    "array":        function(/*Array*/ anArray, /*Object*/ serializers)
                    {
                        var index = 0,
                            count = anArray.length,
                            string = ARRAY_MARKER + ';';

                        for (; index < count; ++index)
                            string += serializePropertyList(anArray[index], serializers);
    
                        return string + END_MARKER + ';';
                    },

    "dictionary":   function(/*CFDictionary*/ aDictionary, /*Object*/ serializers)
                    {
                        var keys = aDictionary._keys,
                            index = 0,
                            count = keys.length,
                            string = DICTIONARY_MARKER +';';

                        for (; index < count; ++index)
                        {
                            var key = keys[index];

                            string += KEY_MARKER + ';' + key.length + ';' + key;
                            string += serializePropertyList(aDictionary.valueForKey(key), serializers);
                        }

                        return string + END_MARKER + ';';
                    }
}

// Deserialization

var XML_XML                 = "xml",
    XML_DOCUMENT            = "#document",

    PLIST_PLIST             = "plist",
    PLIST_KEY               = "key",
    PLIST_DICTIONARY        = "dict",
    PLIST_ARRAY             = "array",
    PLIST_STRING            = "string",
    PLIST_BOOLEAN_TRUE      = "true",
    PLIST_BOOLEAN_FALSE     = "false",
    PLIST_NUMBER_REAL       = "real",
    PLIST_NUMBER_INTEGER    = "integer",
    PLIST_DATA              = "data";

#define NODE_NAME(anXMLNode)        (String(anXMLNode.nodeName))
#define NODE_TYPE(anXMLNode)        (anXMLNode.nodeType)
#define NODE_VALUE(anXMLNode)       (String(anXMLNode.nodeValue))
#define FIRST_CHILD(anXMLNode)      (anXMLNode.firstChild)
#define NEXT_SIBLING(anXMLNode)     (anXMLNode.nextSibling)
#define PARENT_NODE(anXMLNode)      (anXMLNode.parentNode)
#define DOCUMENT_ELEMENT(aDocument) (aDocument.documentElement)

#define IS_OF_TYPE(anXMLNode, aType) (NODE_NAME(anXMLNode) === aType)
#define IS_PLIST(anXMLNode) IS_OF_TYPE(anXMLNode, PLIST_PLIST)

#define IS_WHITESPACE(anXMLNode) (NODE_TYPE(anXMLNode) === 8 || NODE_TYPE(anXMLNode) === 3)
#define IS_DOCUMENTTYPE(anXMLNode) (NODE_TYPE(anXMLNode) === 10)

#define PLIST_NEXT_SIBLING(anXMLNode) while ((anXMLNode = NEXT_SIBLING(anXMLNode)) && IS_WHITESPACE(anXMLNode)) ;
#define PLIST_FIRST_CHILD(anXMLNode) anXMLNode = FIRST_CHILD(anXMLNode); if (anXMLNode !== NULL && IS_WHITESPACE(anXMLNode)) PLIST_NEXT_SIBLING(anXMLNode)

// FIXME: no first child?
#define CHILD_VALUE(anXMLNode) (NODE_VALUE(FIRST_CHILD(anXMLNode)))

var _plist_traverseNextNode = function(anXMLNode, stayWithin, stack)
{
    var node = anXMLNode;
    
    PLIST_FIRST_CHILD(node);
    
    // If this element has a child, traverse to it.
    if (node)
        return node;
    
    // If not, first check if it is a container class (as opposed to a designated leaf).
    // If it is, then we have to pop this container off the stack, since it is empty.
    if (NODE_NAME(anXMLNode) === PLIST_ARRAY || NODE_NAME(anXMLNode) === PLIST_DICTIONARY)
        stack.pop();
    
    // If not, next check whether it has a sibling.
    else
    {
        if (node === stayWithin)
            return NULL;
        
        node = anXMLNode;
        
        PLIST_NEXT_SIBLING(node);
        
        if (node)
            return node; 
    }
    
    // If it doesn't, start working our way back up the node tree.
    node = anXMLNode;
    
    // While we have a node and it doesn't have a sibling (and we're within our stayWithin),
    // keep moving up.
    while (node)
    {
        var next = node;
        
        PLIST_NEXT_SIBLING(next);
        
        // If we have a next sibling, just go to it.
        if (next)
            return next;
            
        var node = PARENT_NODE(node);
            
        // If we are being asked to move up, and our parent is the stay within, then just 
        if (stayWithin && node === stayWithin)
            return NULL;
        
        // Pop the stack if we have officially "moved up"
        stack.pop();
    }
        
    return NULL;
}

CFPropertyList.propertyListFromData = function(/*Data*/ aData, /*Format*/ aFormat)
{
    return CFPropertyList.propertyListFromString(aData.encodedString(), aFormat);
}

CFPropertyList.propertyListFromString = function(/*String*/ aString, /*Format*/ aFormat)
{
    if (!aFormat)
        aFormat = CFPropertyList.sniffedFormatOfString(aString);

    if (aFormat === CFPropertyList.FormatXML_v1_0)
        return CFPropertyList.propertyListFromXML(aString);

    if (aFormat === CFPropertyList.Format280North_v1_0)
        return propertyListFrom280NorthString(aString);

    return NULL;
}

// 280 North Plist Format

var ARRAY_MARKER        = "A",
    DICTIONARY_MARKER   = "D",
    FLOAT_MARKER        = "f",
    INTEGER_MARKER      = "d",
    STRING_MARKER       = "S",
    TRUE_MARKER         = "T",
    FALSE_MARKER        = "F",
    KEY_MARKER          = "K",
    END_MARKER          = "E";

function propertyListFrom280NorthString(/*String*/ aString)
{
    var stream = new MarkedStream(aString),
    
        marker = NULL,
        
        key = "",
        object = NULL,
        plistObject = NULL,
        
        containers = [],
        currentContainer = NULL;

    while (marker = stream.getMarker())
    {
        if (marker === END_MARKER)
        {
            containers.pop();
            continue;
        }
        
        var count = containers.length;
        
        if (count)
            currentContainer = containers[count - 1];
        
        if (marker === KEY_MARKER)
        {
            key = stream.getString();
            marker = stream.getMarker();
        }

        switch (marker)
        {
            case ARRAY_MARKER:      object = []
                                    containers.push(object);
                                    break;
            case DICTIONARY_MARKER: object = new CFMutableDictionary();
                                    containers.push(object);
                                    break;
            
            case FLOAT_MARKER:      object = parseFloat(stream.getString());
                                    break;
            case INTEGER_MARKER:    object = parseInt(stream.getString(), 10);
                                    break;
                                        
            case STRING_MARKER:     object = stream.getString();
                                    break;
                                        
            case TRUE_MARKER:       object = YES;
                                    break;
            case FALSE_MARKER:      object = NO;
                                    break;
                                        
            default:                throw new Error("*** " + marker + " marker not recognized in Plist.");
        }

        if (!plistObject)
            plistObject = object;
            
        else if (currentContainer)
            // If the container is an array...
            if (currentContainer.slice)
                currentContainer.push(object);
            else
                currentContainer.setValueForKey(key, object);
    }
    
    return plistObject;
}

function encodeHTMLComponent(/*String*/ aString)
{
    return aString.replace(/&/g,'&amp;').replace(/"/g, '&quot;').replace(/'/g, '&apos;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

function decodeHTMLComponent(/*String*/ aString)
{
    return aString.replace(/&quot;/g, '"').replace(/&apos;/g, '\'').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
}

function parseXML(/*String*/ aString)
{
    if (window.DOMParser)
        return DOCUMENT_ELEMENT(new window.DOMParser().parseFromString(aString, "text/xml"));

    else if (window.ActiveXObject)
    {
        XMLNode = new ActiveXObject("Microsoft.XMLDOM");

        // Extract the DTD, which confuses IE.
        var matches = aString.match(CFPropertyList.DTDRE);

        if (matches)
            aString = aString.substr(matches[0].length);

        XMLNode.loadXML(aString);

        return XMLNode
    }

    return NULL;
}

CFPropertyList.propertyListFromXML = function(/*String | XMLNode*/ aStringOrXMLNode)
{
    var XMLNode = aStringOrXMLNode;

    if (aStringOrXMLNode.valueOf && typeof aStringOrXMLNode.valueOf() === "string")
        XMLNode = parseXML(aStringOrXMLNode);

    // Skip over DOCTYPE and so forth.
    while (IS_OF_TYPE(XMLNode, XML_DOCUMENT) || IS_OF_TYPE(XMLNode, XML_XML))
        PLIST_FIRST_CHILD(XMLNode);
    
    // Skip over the DOCTYPE... see a pattern?
    if (IS_DOCUMENTTYPE(XMLNode))
        PLIST_NEXT_SIBLING(XMLNode);

    // If this is not a PLIST, bail.
    if (!IS_PLIST(XMLNode))
        return NULL;

    var key = "",
        object = NULL,
        plistObject = NULL,
        
        plistNode = XMLNode,
        
        containers = [],
        currentContainer = NULL;
    
    while (XMLNode = _plist_traverseNextNode(XMLNode, plistNode, containers))
    {
        var count = containers.length;
        
        if (count)
            currentContainer = containers[count - 1];
            
        if (NODE_NAME(XMLNode) === PLIST_KEY)
        {
            key = CHILD_VALUE(XMLNode);
            PLIST_NEXT_SIBLING(XMLNode);
        }

        switch (String(NODE_NAME(XMLNode)))
        {
            case PLIST_ARRAY:           object = []
                                        containers.push(object);
                                        break;
            case PLIST_DICTIONARY:      object = new CFMutableDictionary();
                                        containers.push(object);
                                        break;
            
            case PLIST_NUMBER_REAL:     object = parseFloat(CHILD_VALUE(XMLNode));
                                        break;
            case PLIST_NUMBER_INTEGER:  object = parseInt(CHILD_VALUE(XMLNode), 10);
                                        break;
                                        
            case PLIST_STRING:          object = decodeHTMLComponent(FIRST_CHILD(XMLNode) ? CHILD_VALUE(XMLNode) : "");
                                        break;
                                        
            case PLIST_BOOLEAN_TRUE:    object = YES;
                                        break;
            case PLIST_BOOLEAN_FALSE:   object = NO;
                                        break;
                                        
            case PLIST_DATA:            object = new CFMutableData();
                                        object.bytes = FIRST_CHILD(XMLNode) ? base64_decode_to_array(CHILD_VALUE(XMLNode), YES) : [];
                                        break;
                                        
            default:                    throw new Error("*** " + NODE_NAME(XMLNode) + " tag not recognized in Plist.");
        }

        if (!plistObject)
            plistObject = object;
            
        else if (currentContainer)
            // If the container is an array...
            if (currentContainer.slice)
                currentContainer.push(object);
            else
                currentContainer.setValueForKey(key, object);
    }
    
    return plistObject;
}

exports.generateObjectUID = generateObjectUID;
exports.CFPropertyList = CFPropertyList;

exports.CFPropertyListCreate = function()
{
    return new CFPropertyList();
}

exports.kCFPropertyListOpenStepFormat        = CFPropertyList.FormatOpenStep;
exports.kCFPropertyListXMLFormat_v1_0        = CFPropertyList.FormatXML_v1_0;
exports.kCFPropertyListBinaryFormat_v1_0     = CFPropertyList.FormatBinary_v1_0;
exports.kCFPropertyList280NorthFormat_v1_0   = CFPropertyList.Format280North_v1_0;

exports.CFPropertyListCreateFromXMLData = function(/*Data*/ data)
{
    return CFPropertyList.propertyListFromData(data, CFPropertyList.FormatXML_v1_0);
}

exports.CFPropertyListCreateXMLData = function(/*PropertyList*/ aPropertyList)
{
    return CFPropertyList.dataFromPropertyList(aPropertyList, CFPropertyList.FormatXML_v1_0);
}

exports.CFPropertyListCreateFrom280NorthData = function(/*Data*/ data)
{
    return CFPropertyList.propertyListFromData(data, CFPropertyList.Format280North_v1_0);
}

exports.CFPropertyListCreate280NorthData = function(/*PropertyList*/ aPropertyList)
{
    return CFPropertyList.dataFromPropertyList(aPropertyList, CFPropertyList.Format280North_v1_0);
}

exports.CPPropertyListCreateFromData = function(/*CFData*/ data, /*Format*/ aFormat)
{
    return CFPropertyList.propertyListFromData(data, aFormat);
}

exports.CPPropertyListCreateData = function(/*PropertyList*/ aPropertyList, /*Format*/ aFormat)
{
    return CFPropertyList.dataFromPropertyList(aPropertyList, aFormat);
}
