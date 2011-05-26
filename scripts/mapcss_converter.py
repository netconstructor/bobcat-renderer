#!/usr/bin/python

import sys
sys.path.insert(0,"../../mapcss/mapcss-parser")

from mapcss_parser import MapCSSParser

import ast

if len(sys.argv) != 2:
    print "usage : mapcss.py inputfile"
    raise SystemExit

content = open(sys.argv[1]).read()
parser = MapCSSParser(debug=False)
mapcss = parser.parse(content)

CHECK_OPERATORS = {
    '=': '===',
    '<': '<',
    '<=': '<=',
    '>': '>',
    '>=': '>=',
    '!=': '!==',
    '<>': '!==',
}

DASH_PROPERTIES = ('dashes', 'casing-dashes')
NUMERIC_PROPERTIES = (
    'z-index', 
    'width', 
    'opacity', 
    'fill-opacity', 
    'casing-width', 
    'casing-opacity', 
#    'font-size', 
    'text-offset', 
    'max-width', 
    'text-halo-radius'
)

SCALES = [
    500000000,
    250000000,
    150000000,
    70000000,
    35000000,
    15000000,
    10000000,
    4000000,
    2000000,
    1000000,
    500000,
    250000,
    150000,
    70000,
    35000,
    15000,
    8000,
    4000,
    0,
]

def propagate_import(url):
    content = open(url).read()
    return parser.parse(content)

def escape_value(key, value):
    if isinstance(value, ast.Eval):
        return value.as_js()
    elif key in NUMERIC_PROPERTIES:
        return value
    elif key in DASH_PROPERTIES:
        return "[%s]" % value
    else:
        return "'%s'" % value

def mapcss_as_aj(self):
    imports = "".join(map(lambda imp: propagate_import(imp.url).as_js, self.imports))
    rules = "\n".join(map(lambda x: x.as_js(), self.rules))
    return "%s%s" % (imports, rules)
    
def mapcss_canvas_as_aj(self):
    actions = []
    for rule in self.rules:
        for selector in filter(lambda selector: selector.subject == 'canvas', rule.selectors):
            for action in rule.actions:
                for stmt in action.statements:
                    actions.append("canvas['%s'] = %s;" % (stmt.key, escape_value(stmt.key, stmt.value) ))
    return """
    var canvas = [];
    %s
    return canvas;""" % "\n    ".join(actions)
    
def rule_as_js(self):
    rules = []
    for selector in self.selectors:
        if selector.subject == 'canvas':
            continue

        for action in map(lambda action: "    if (%s) %s" % (selector.as_js(), action.as_js(selector.get_zoom(), selector.subpart)), self.actions):
            rules.append(action)

    return "\n".join(rules)
    
def selector_as_js(self):
    criteria = " && ".join(map(lambda x: x.as_js(), self.criteria))
    
    if self.subject in ['node', 'way', 'relation', 'coastline']:
        subject_property = 'type'
    else:
        subject_property = 'selector'
        
    if self.criteria:
        return "(obj.%s === '%s' && %s)" % (subject_property, self.subject, criteria)
    else:
        return "obj.%s === '%s'" % (subject_property, self.subject)
    
def condition_check_as_js(self):
    if self.value == 'yes' and self.sign == '=':
        return "(obj['tags']['%s'] === '1' || obj['tags']['%s'] === 'true' || obj['tags']['%s'] === 'yes')" % (self.key, self.key, self.key)
    elif self.value == 'yes' and (self.sign == '!=' or self.sign == '<>'):
        return "(obj['tags']['%s'] === '-1' || obj['tags']['%s'] === 'false' || obj['tags']['%s'] === 'no')" % (self.key, self.key, self.key)
    else:
        return "obj['tags']['%s'] %s '%s'" % (self.key, CHECK_OPERATORS[self.sign], self.value)

def condition_tag_as_js(self):
    return "(typeof obj['tags']['%s'] !== 'undefined' && obj['tags']['%s'] !== null)" % (self.key, self.key)

def condition_nottag_as_js(self):
    return "(typeof obj['tags']['%s'] === 'undefined' || obj['tags']['%s'] === null)" % (self.key, self.key)
    
def action_as_js(self, scale, subpart):
    if len(filter(lambda x: x, map(lambda x: isinstance(x, ast.StyleStatement), self.statements))) > 0:
        if scale[0] != SCALES[0]:
            min_scale = "subparts[x][scale]['max-scale'] = %d;" % scale[0]
        else:
            min_scale = ''
        
        if scale[1] != SCALES[-1]:
            max_scale = "subparts[x][scale]['min-scale'] = %d;" % scale[1]
        else:
            max_scale = ''
        
        return """{
        var x = '%s';
        var scale = '%s';
        if (typeof(subparts[x]) === 'undefined') {
            subparts[x] = {}
        }
        if (typeof(subparts[x][scale]) === 'undefined') {
            subparts[x][scale] = {}
        }
        %s
        %s
%s
    }\n""" % (subpart, scale, min_scale, max_scale, "\n".join(map(lambda x: x.as_js(), self.statements)))
    else:
        return "{\n    %s\n    }" % "\n".join(map(lambda x: x.as_js(), self.statements))
    
def style_statement_as_js(self):
    return "        subparts[x][scale]['%s'] = %s;" % (self.key, escape_value(self.key, self.value))

def tag_statement_as_js(self):
    return "        obj.tags['%s'] = %s" % (self.key, escape_value(self.key, self.value))
    
def eval_as_js(self):
    return self.expression.as_js()
    
def eval_function_as_js(self):
    args = ", ".join(map(lambda arg: arg.as_js(), self.arguments))
    if self.function == 'tag':
        return "MapCSS.tag(obj, %s)" % (args)
    elif self.function == 'prop':
        return "MapCSS.prop(subparts[x][scale], %s)" % (args)
    else:
        return "MapCSS.%s(%s)" % (self.function, args)

def eval_string_as_js(self):
    return str(self)
    
def eval_op_as_js(self):
    op = self.operation
    if op == '.':
        op = '+'

    if op == 'eq':
        op = '=='

    if op == 'ne':
        op = '!='
        
    return "%s %s %s" % (self.arg1.as_js(), self.operation, self.arg2.as_js())
    
def eval_group_as_js(self):
    return "(%s)" % str(self.expression.as_js())
    
def selector_get_zoom(self):
    zoom = self.zoom
    zoom = zoom.strip("|")
    if zoom and zoom[0] == 'z':
        zoom = zoom[1:].split('-')
        if len(zoom) == 1 and int(zoom[0]) < 18:
            zoom.append(int(zoom[0]) + 1)
        elif len(zoom) == 1:
            zoom.append(int(zoom[0]))

        zoom[0] = zoom[0] or 0
        zoom[1] = zoom[1] or 18
        zoom = map(lambda z: SCALES[int(z)], zoom)
    else:
        zoom = [SCALES[0], SCALES[18]]
        
    return zoom

ast.MapCSS.as_js = mapcss_as_aj
ast.MapCSS.canvas_as_js = mapcss_canvas_as_aj
ast.Rule.as_js = rule_as_js
ast.Selector.as_js = selector_as_js
ast.Selector.get_zoom = selector_get_zoom
ast.ConditionCheck.as_js = condition_check_as_js
ast.ConditionTag.as_js = condition_tag_as_js
ast.ConditionNotTag.as_js = condition_nottag_as_js
ast.Action.as_js = action_as_js
ast.StyleStatement.as_js = style_statement_as_js
ast.TagStatement.as_js = tag_statement_as_js
ast.Eval.as_js = eval_as_js

ast.EvalExpressionString.as_js = eval_string_as_js
ast.EvalExpressionOperation.as_js = eval_op_as_js
ast.EvalExpressionGroup.as_js = eval_group_as_js
ast.EvalFunction.as_js = eval_function_as_js


print """
MapCSS = function() {
    return this;
}

MapCSS.min = function(/*...*/) {
    return Math.min.apply(null, arguments);
}

MapCSS.max = function(/*...*/) {
    return Math.max.apply(null, arguments);
}

MapCSS.any = function(/*...*/) {
    for(var i = 0; i < arguments.length; i++) {
        if (typeof(arguments[i]) != 'undefined' && arguments[i] != '') {
            return arguments[i];
        }
    }
    
    return "";
}

MapCSS.num = function(arg) {
    if (!isNaN(parseFloat(arg))) {
        return parseFloat(arg);
    } else {
        return ""
    }
}

MapCSS.str = function(arg) {
    return arg;
}

MapCSS.int = function(arg) {
    return parseInt(arg);
}

MapCSS.tag = function(obj, tag) {
    if (typeof(obj['tags'][tag]) != 'undefined') {
        return obj['tags'][tag];
    } else {
        return "";
    }
}

MapCSS.prop = function(obj, tag) {
    if (typeof(obj[tag]) != 'undefined') {
        return obj[tag];
    } else {
        return "";
    }
}

MapCSS.sqrt = function(arg) {
    return math.sqrt(arg);
}

MapCSS.boolean = function(arg) {
    if (arg == '0' || arg == 'false' || arg == '') {
        return 'false';
    } else {
        return 'true';
    }
}

MapCSS.boolean = function(exp, if_exp, else_exp) {
    if (MapCSS.boolean(exp) == 'true') {
        return if_exp;
    } else {
        return else_exp;
    }
}

MapCSS.metric = function(arg) {
    if (/\d\s*mm$/.test(arg)) {
        return 1000 * parseInt(arg);
    } else if (/\d\s*cm$/.test(arg)) {
        return 100 * parseInt(arg);
    } else if (/\d\s*dm$/.test(arg)) {
        return 10 * parseInt(arg);
    } else if (/\d\s*km$/.test(arg)) {
        return 0.001 * parseInt(arg);
    } else if (/\d\s*in$/.test(arg)) {
        return 0.0254 * parseInt(arg);
    } else if (/\d\s*ft$/.test(arg)) {
        return 0,3048 * parseInt(arg);
    } else {
        return parseInt(arg);
    }
}

MapCSS.zmetric = function(arg) {
    return MapCSS.metric(arg)
}

MapCSS.set_styles = function(obj) {

    var subparts = {};
"""
print mapcss.as_js()
print """
    parts = [];
    for (var k in subparts) {
        for (var scale in subparts[k]) {
            parts.push(subparts[k][scale]);
        }
    }

    return parts;
}

MapCSS.get_canvas = function() {
%s
}""" % mapcss.canvas_as_js()
