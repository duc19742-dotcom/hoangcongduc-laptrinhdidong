"""Export the installation guide to Word using only Python's standard library."""
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile, ZIP_DEFLATED
from xml.sax.saxutils import escape
import re

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'HUONG_DAN_CAI_DAT.md'
TARGET = ROOT / 'HUONG_DAN_CAI_DAT.docx'
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'


def run(text, bold=False):
    props = '<w:rPr><w:b/></w:rPr>' if bold else ''
    return f'<w:r>{props}<w:t xml:space="preserve">{escape(text)}</w:t></w:r>'


def paragraph(text='', style='Normal', keep=False):
    props = f'<w:pStyle w:val="{style}"/>'
    if keep:
        props += '<w:keepNext/>'
    return f'<w:p><w:pPr>{props}</w:pPr>{run(text)}</w:p>'


def table(rows):
    parts = [
        '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
        '<w:tblBorders>' + ''.join(
            f'<w:{edge} w:val="single" w:sz="4" w:color="CBD5E1"/>'
            for edge in ('top', 'left', 'bottom', 'right', 'insideH', 'insideV')
        ) + '</w:tblBorders><w:tblCellMar><w:top w:w="80" w:type="dxa"/>'
        '<w:left w:w="100" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/>'
        '<w:right w:w="100" w:type="dxa"/></w:tblCellMar></w:tblPr>'
        '<w:tblGrid><w:gridCol w:w="3000"/><w:gridCol w:w="6746"/></w:tblGrid>'
    ]
    for index, row in enumerate(rows):
        props = '<w:trPr><w:cantSplit/>' + ('<w:tblHeader/>' if index == 0 else '') + '</w:trPr>'
        parts.append('<w:tr>' + props)
        for col, cell in enumerate(row):
            width = 3000 if col == 0 else 6746
            shade = '<w:shd w:fill="E6EEF7"/>' if index == 0 else ''
            parts.append(
                f'<w:tc><w:tcPr><w:tcW w:w="{width}" w:type="dxa"/>{shade}</w:tcPr>'
                f'<w:p><w:pPr><w:pStyle w:val="TableText"/></w:pPr>{run(cell, index == 0)}</w:p></w:tc>'
            )
        parts.append('</w:tr>')
    parts.append('</w:tbl>')
    return ''.join(parts)


def render_markdown(source):
    lines = source.splitlines()
    parts, index, in_code = [], 0, False
    while index < len(lines):
        line = lines[index]
        if line.startswith('```'):
            in_code = not in_code
        elif in_code:
            parts.append(paragraph(line, 'Code'))
        elif line.startswith('|'):
            rows = []
            while index < len(lines) and lines[index].startswith('|'):
                cells = [cell.strip() for cell in lines[index].strip().strip('|').split('|')]
                if not all(re.fullmatch(r':?-+:?', cell) for cell in cells):
                    rows.append(cells)
                index += 1
            parts.append(table(rows))
            continue
        elif line.startswith('# '):
            parts.append(paragraph(line[2:], 'Title'))
        elif line.startswith('## '):
            parts.append(paragraph(line[3:], 'Heading1', True))
        elif line.startswith('### '):
            parts.append(paragraph(line[4:], 'Heading2', True))
        elif line:
            parts.append(paragraph(line, 'ListText' if re.match(r'^(\d+\. |\- )', line) else 'Normal'))
        index += 1
    if in_code:
        raise ValueError('Unclosed fenced code block in Markdown source')
    return ''.join(parts)


STYLES = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="{W}">
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="Times New Roman"/><w:sz w:val="24"/><w:lang w:val="vi-VN"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/><w:widowControl/></w:pPr></w:pPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
<w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:before="240" w:after="260"/><w:keepNext/></w:pPr><w:rPr><w:b/><w:color w:val="17365D"/><w:sz w:val="36"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before="240" w:after="120"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:color w:val="17365D"/><w:sz w:val="30"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before="160" w:after="100"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:color w:val="245A81"/><w:sz w:val="26"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Code"><w:name w:val="Code"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/><w:ind w:left="100" w:right="100"/><w:shd w:fill="F1F5F9"/></w:pPr><w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/><w:sz w:val="19"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="TableText"><w:name w:val="Table Text"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="40" w:line="240" w:lineRule="auto"/></w:pPr><w:rPr><w:sz w:val="22"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="ListText"><w:name w:val="List Text"/><w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="200"/><w:spacing w:after="80"/></w:pPr></w:style>
</w:styles>'''


def main():
    content = render_markdown(SOURCE.read_text(encoding='utf-8-sig'))
    document = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="{W}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>{content}<w:sectPr><w:footerReference w:type="default" r:id="rId2"/><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" w:header="480" w:footer="480"/><w:pgNumType w:start="1"/></w:sectPr></w:body></w:document>'''
    files = {
        '[Content_Types].xml': '''<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/></Types>''',
        '_rels/.rels': '''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/></Relationships>''',
        'word/document.xml': document,
        'word/styles.xml': STYLES,
        'word/_rels/document.xml.rels': '''<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/></Relationships>''',
        'word/footer1.xml': f'''<w:ftr xmlns:w="{W}"><w:p><w:pPr><w:jc w:val="center"/></w:pPr>{run('Hướng dẫn cài đặt • Hoàng Công Đức | Trang ')}<w:fldSimple w:instr="PAGE"/></w:p></w:ftr>''',
        'docProps/core.xml': '''<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Tài liệu hướng dẫn cài đặt – Hoàng Công Đức</dc:title><dc:creator>Hoàng Công Đức</dc:creator><dc:description>Git, Flutter Android, Node.js và Twilio Verify Trial</dc:description></cp:coreProperties>''',
    }
    for xml in files.values():
        ET.fromstring(xml)
    with ZipFile(TARGET, 'w', ZIP_DEFLATED) as output:
        for name, xml in files.items():
            output.writestr(name, xml.encode('utf-8'))
    print(f'Exported {TARGET.name}: {TARGET.stat().st_size} bytes')


if __name__ == '__main__':
    main()
