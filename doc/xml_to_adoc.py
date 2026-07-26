#!/usr/bin/env python3
"""
Convert jemalloc DocBook XML to AsciiDoc man page format.
"""

import sys
import xml.etree.ElementTree as ET
import re
from pathlib import Path

def strip_namespace(tag):
    """Remove namespace from XML tag."""
    return tag.split('}')[-1] if '}' in tag else tag

def render_inline_element(elem):
    """Render a single inline element with asciidoc markup for its tag.
    Applies the handler to *this* element (not its descendants)."""
    tag = strip_namespace(elem.tag)

    if tag == 'emphasis':
        child_text = extract_text(elem, preserve_markup=True)
        return f'*{child_text}*' if elem.get('role') == 'bold' else f'_{child_text}_'
    elif tag == 'function':
        child_text = extract_text(elem, preserve_markup=True)
        return f'*{child_text}*'
    elif tag == 'parameter':
        child_text = extract_text(elem, preserve_markup=True)
        return f'_{child_text}_'
    elif tag in ('constant', 'type', 'literal', 'code', 'filename', 'command',
                 'envar', 'errorname', 'varname', 'computeroutput', 'mallctl', 'option'):
        # These wrap content in single backticks (asciidoc inline literal),
        # which is a passthrough — inner markup would render literally.
        # Use plain text so e.g. <code>sizeof(<type>void *</type>)</code>
        # becomes `sizeof(void *)` rather than `sizeof(`void *`)`.
        plain = extract_text(elem, preserve_markup=False)
        return f'`{plain}`'
    elif tag == 'citerefentry':
        title_e = elem.find('refentrytitle')
        volnum_e = elem.find('manvolnum')
        title = extract_text(title_e) if title_e is not None else extract_text(elem)
        volnum = extract_text(volnum_e) if volnum_e is not None else ''
        return f'{title}({volnum})' if volnum else title
    elif tag == 'xref':
        linkend = elem.get('linkend', '')
        return f'<<{linkend}>>' if linkend else ''
    elif tag == 'link':
        linkend = elem.get('linkend', '')
        child_text = extract_text(elem, preserve_markup=True)
        if linkend:
            return f'<<{linkend},{child_text}>>'
        href = elem.get('{http://www.w3.org/1999/xlink}href', '')
        return f'link:{href}[{child_text}]' if href else child_text
    elif tag == 'ulink':
        child_text = extract_text(elem, preserve_markup=True)
        url = elem.get('url', '')
        return f'link:{url}[{child_text}]' if url else child_text
    elif tag == 'quote':
        child_text = extract_text(elem, preserve_markup=True)
        return f'"{child_text}"'
    return extract_text(elem, preserve_markup=True)

def extract_text(elem, preserve_markup=False):
    """Extract text content from element, optionally preserving inline markup."""
    if elem is None:
        return ""

    if not preserve_markup:
        return ''.join(elem.itertext()).strip()

    result = []
    if elem.text:
        result.append(elem.text)

    for child in elem:
        result.append(render_inline_element(child))
        if child.tail:
            result.append(child.tail)

    return ''.join(result)

def convert_para(elem, indent=0):
    """Convert paragraph element to AsciiDoc, emitting embedded block elements
    (programlisting, screen, table) as separate blocks."""
    prefix = '  ' * indent
    blocks = []
    inline_buf = []

    def flush_inline():
        if inline_buf:
            text = re.sub(r'\s+', ' ', ''.join(inline_buf)).strip()
            if text:
                blocks.append(prefix + text)
            inline_buf.clear()

    if elem.text:
        inline_buf.append(elem.text)

    for child in elem:
        tag = strip_namespace(child.tag)
        if tag in ('programlisting', 'screen'):
            flush_inline()
            blocks.append(convert_programlisting(child, indent))
            # Text after </programlisting> (e.g. "Take special note of the ")
            # is the tail — it begins the next inline run.
            if child.tail:
                inline_buf.append(child.tail)
        elif tag == 'table':
            flush_inline()
            blocks.append(convert_table(child, indent))
            if child.tail:
                inline_buf.append(child.tail)
        elif tag == 'variablelist':
            flush_inline()
            blocks.append(convert_variablelist(child, indent))
            if child.tail:
                inline_buf.append(child.tail)
        elif tag == 'itemizedlist':
            flush_inline()
            blocks.append(convert_itemizedlist(child, indent))
            if child.tail:
                inline_buf.append(child.tail)
        else:
            inline_buf.append(render_inline_element(child))
            if child.tail:
                inline_buf.append(child.tail)

    flush_inline()
    return '\n\n'.join(blocks)

def convert_programlisting(elem, indent=0):
    """Convert code block to AsciiDoc."""
    code = extract_text(elem, preserve_markup=False)
    prefix = '  ' * indent
    lines = ['', prefix + '[source,c]', prefix + '----']
    for line in code.split('\n'):
        lines.append(prefix + line)
    lines.append(prefix + '----')
    return '\n'.join(lines)

def convert_itemizedlist(elem, indent=0):
    """Convert itemized list to AsciiDoc."""
    lines = []
    prefix = '  ' * indent
    for item in elem.findall('.//listitem'):
        para = item.find('.//para')
        if para is not None:
            text = extract_text(para, preserve_markup=True)
            text = re.sub(r'\s+', ' ', text).strip()
            lines.append(f'{prefix}* {text}')
    return '\n'.join(lines)

def convert_variablelist(elem, indent=0):
    """Convert variable list (definition list) to AsciiDoc."""
    lines = []
    prefix = '  ' * indent
    for varlistentry in elem.findall('.//varlistentry'):
        term = varlistentry.find('.//term')
        listitem = varlistentry.find('.//listitem')

        if term is not None:
            term_text = extract_text(term, preserve_markup=True)
            term_text = re.sub(r'\s+', ' ', term_text).strip()
            lines.append(f'{prefix}{term_text}::')

            if listitem is not None:
                for para in listitem.findall('.//para'):
                    para_text = extract_text(para, preserve_markup=True)
                    para_text = re.sub(r'\s+', ' ', para_text).strip()
                    lines.append(f'{prefix}  {para_text}')
                lines.append('')

    return '\n'.join(lines)

def convert_table(elem, indent=0):
    """Convert DocBook CALS table to AsciiDoc table."""
    prefix = '  ' * indent

    header_cells = []
    thead = elem.find('.//thead')
    if thead is not None:
        for row in thead.findall('.//row'):
            cells = []
            for entry in row.findall('.//entry'):
                cell_text = extract_text(entry, preserve_markup=True)
                cell_text = re.sub(r'\s+', ' ', cell_text).strip()
                cells.append(cell_text)
            header_cells = cells
            break

    body_rows = []
    tbody = elem.find('.//tbody')
    if tbody is not None:
        for row in tbody.findall('.//row'):
            cells = []
            for entry in row.findall('.//entry'):
                cell_text = extract_text(entry, preserve_markup=True)
                cell_text = re.sub(r'\s+', ' ', cell_text).strip()
                # CALS morerows="N" means the cell spans N+1 rows total.
                # Asciidoc rowspan notation is ".N+|" — this prefix REPLACES
                # the leading cell separator, not appends to it.
                morerows = entry.get('morerows')
                if morerows is not None:
                    try:
                        span = int(morerows) + 1
                        cell_text = f'.{span}+| {cell_text}'
                    except ValueError:
                        cell_text = f'| {cell_text}'
                else:
                    cell_text = f'| {cell_text}'
                cells.append(cell_text)
            body_rows.append(cells)

    if not header_cells and not body_rows:
        return ''

    tgroup = elem.find('.//tgroup')
    cols = tgroup.get('cols', '') if tgroup is not None else ''

    lines = ['']
    title_elem = elem.find('.//title')
    if title_elem is not None:
        lines.append(f'{prefix}.{extract_text(title_elem)}')

    opts = []
    if cols:
        opts.append(f'cols="{cols}"')
    if header_cells:
        opts.append('options="header"')
    if opts:
        lines.append(f'{prefix}[{",".join(opts)}]')

    lines.append(f'{prefix}|===')
    if header_cells:
        header_prefixed = [f'| {c}' for c in header_cells]
        lines.append(prefix + ' '.join(header_prefixed))
    for body_row in body_rows:
        lines.append(prefix + ' '.join(body_row))
    lines.append(f'{prefix}|===')

    return '\n'.join(lines)

def convert_funcprototype(elem):
    """Convert function prototype to a plain C signature string (no markup).
    Synopsis prototypes are emitted inside a code block, so markup would not
    render anyway and would only risk collisions (e.g. "void *" + "*name*")."""
    funcdef = elem.find('.//funcdef')
    if funcdef is None:
        return ""

    func_name_elem = funcdef.find('.//function')
    func_name = extract_text(func_name_elem) if func_name_elem is not None else ""

    # Text in funcdef before <function> is the return type (e.g. "void *")
    return_type = (funcdef.text or "").strip()
    # Ensure a space between return type and function name unless the type
    # already ends with '*' (e.g. "void *") where C convention has no space
    if return_type and not return_type.endswith(('*', '&')):
        return_type += ' '
    # Text after <function> inside funcdef (rare; e.g. trailing const)
    if func_name_elem is not None and func_name_elem.tail:
        return_type_after = func_name_elem.tail.strip()
    else:
        return_type_after = ""

    params = []
    for paramdef in elem.findall('.//paramdef'):
        # Render plain text, but wrap any <funcparams> child in parens
        # (used for function-pointer parameters like void (*cb)(void *, ...))
        parts = []
        if paramdef.text:
            parts.append(paramdef.text)
        for child in paramdef:
            tag = strip_namespace(child.tag)
            text = extract_text(child, preserve_markup=False)
            parts.append(f'({text})' if tag == 'funcparams' else text)
            if child.tail:
                parts.append(child.tail)
        param_text = re.sub(r'\s+', ' ', ''.join(parts)).strip()
        params.append(param_text)

    param_str = ', '.join(params) if params else 'void'

    return f'{return_type}{func_name}{return_type_after}({param_str});'

def convert_section(elem, level=2):
    """Convert section element to AsciiDoc."""
    lines = []
    indent = 0

    title_elem = elem.find('.//title')
    if title_elem is not None:
        title = extract_text(title_elem)
        header = '=' * level
        lines.append(f'{header} {title.upper()}')
        lines.append('')

    for child in elem:
        tag = strip_namespace(child.tag)

        if tag == 'title':
            continue
        elif tag == 'para':
            lines.append(convert_para(child, indent))
            lines.append('')
        elif tag == 'programlisting':
            lines.append(convert_programlisting(child, indent))
            lines.append('')
        elif tag == 'itemizedlist':
            lines.append(convert_itemizedlist(child, indent))
            lines.append('')
        elif tag == 'variablelist':
            lines.append(convert_variablelist(child, indent))
            lines.append('')
        elif tag == 'screen':
            lines.append(convert_programlisting(child, indent))
            lines.append('')
        elif tag == 'table':
            lines.append(convert_table(child, indent))
            lines.append('')
        elif tag in ['refsect2', 'refsect3']:
            subsect_lines = convert_section(child, level + 1)
            lines.append(subsect_lines)
            lines.append('')

    return '\n'.join(lines)

def convert_xml_to_adoc(xml_file, output_file):
    """Main conversion function."""
    tree = ET.parse(xml_file)
    root = tree.getroot()

    lines = []

    # Extract metadata
    refmeta = root.find('.//refmeta')
    refentry_title = root.find('.//refentrytitle')
    manvolnum = root.find('.//manvolnum')

    title = extract_text(refentry_title) if refentry_title is not None else "JEMALLOC"
    volnum = extract_text(manvolnum) if manvolnum is not None else "3"

    # Get version from refentryinfo
    version_elem = root.find('.//releaseinfo[@role="version"]')
    version = extract_text(version_elem) if version_elem is not None else "@jemalloc_version@"

    # AsciiDoc header
    lines.append(f'= {title}({volnum})')
    lines.append(':doctype: manpage')
    lines.append(f':man manual: User Manual')
    lines.append(f':man source: jemalloc {version}')
    lines.append('')

    # NAME section
    refnamediv = root.find('.//refnamediv')
    if refnamediv is not None:
        lines.append('== NAME')
        lines.append('')
        refname = refnamediv.find('.//refname')
        refpurpose = refnamediv.find('.//refpurpose')
        if refname is not None and refpurpose is not None:
            name = extract_text(refname)
            purpose = extract_text(refpurpose)
            lines.append(f'{name} - {purpose}')
        lines.append('')

    # SYNOPSIS section
    synopsis = root.find('.//refsynopsisdiv')
    if synopsis is not None:
        lines.append('== SYNOPSIS')
        lines.append('')

        funcsynopsisinfo = synopsis.find('.//funcsynopsisinfo')

        # Emit a single [source,c] block containing the #include and every
        # function prototype. <refsect2> blocks (Standard API / Non-standard
        # API) are nested inside <funcsynopsis>, not direct children of
        # <refsynopsisdiv>, so we use findall('.//refsect2') to descend.
        proto_lines = []
        if funcsynopsisinfo is not None:
            proto_lines.append(extract_text(funcsynopsisinfo).strip())
            proto_lines.append('')

        for child in synopsis.findall('.//refsect2'):
            title_elem = child.find('.//title')
            if title_elem is not None:
                # Group separator inside the code block
                if proto_lines and proto_lines[-1] != '':
                    proto_lines.append('')
                proto_lines.append(f'// {extract_text(title_elem)}')
                proto_lines.append('')

            for funcproto in child.findall('.//funcprototype'):
                proto = convert_funcprototype(funcproto)
                if proto:
                    proto_lines.append(proto)

        if proto_lines:
            lines.append('[source,c]')
            lines.append('----')
            lines.extend(proto_lines)
            lines.append('----')
            lines.append('')

    # Main sections
    for refsect1 in root.findall('.//refsect1'):
        section_id = refsect1.get('id', '')
        if section_id in ['library']:
            continue  # Skip library section, handled in NAME

        lines.append(convert_section(refsect1, level=2))
        lines.append('')

    # Write output
    output_path = Path(output_file)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    content = '\n'.join(lines)
    # Clean up multiple consecutive blank lines
    content = re.sub(r'\n{3,}', '\n\n', content)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"Converted {xml_file} to {output_file}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.xml.in> <output.adoc>")
        sys.exit(1)

    xml_file = sys.argv[1]
    output_file = sys.argv[2]

    convert_xml_to_adoc(xml_file, output_file)