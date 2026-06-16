#!/usr/bin/env python3
import argparse
import csv
import html
import json
import os
import re
import zipfile
from datetime import datetime, timezone
from io import StringIO


CONTENT_TYPES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
"""

ROOT_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
"""

WORKBOOK_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>
"""

STYLES_XML = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>
  <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
  <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>
"""

APP_XML = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>agent-dev-kit</Application>
</Properties>
"""


def sanitize_sheet_name(name):
    clean = re.sub(r"[][\\\\/*?:]", " ", name or "Sheet1").strip()
    return (clean[:31] or "Sheet1")


def col_name(index):
    name = ""
    while index:
        index, rem = divmod(index - 1, 26)
        name = chr(65 + rem) + name
    return name


def parse_markdown_table(text):
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    table_lines = [line for line in lines if "|" in line]
    if not table_lines:
        return None
    rows = []
    for line in table_lines:
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if all(re.fullmatch(r":?-{3,}:?", cell or "") for cell in cells):
            continue
        rows.append(cells)
    return rows or None


def parse_delimited(text):
    sample = text[:2048]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",;\t|")
    except csv.Error:
        dialect = csv.excel
    return [row for row in csv.reader(StringIO(text), dialect) if any(cell.strip() for cell in row)]


def parse_json(text):
    data = json.loads(text)
    if isinstance(data, dict):
        data = data.get("rows", data.get("data", [data]))
    if not isinstance(data, list):
        raise ValueError("JSON input must be an array, object, or object with rows/data.")
    if not data:
        return []
    if all(isinstance(item, dict) for item in data):
        columns = []
        for item in data:
            for key in item.keys():
                if key not in columns:
                    columns.append(key)
        return [columns] + [[item.get(column, "") for column in columns] for item in data]
    if all(isinstance(item, list) for item in data):
        return data
    return [[item] for item in data]


def parse_rows(text):
    stripped = text.strip()
    if not stripped:
        return []
    if stripped[0] in "[{":
        try:
            return parse_json(stripped)
        except Exception:
            pass
    markdown_rows = parse_markdown_table(stripped)
    if markdown_rows:
        return markdown_rows
    return parse_delimited(stripped)


def normalize_rows(rows):
    normalized = [[("" if cell is None else str(cell)).strip() for cell in row] for row in rows]
    width = max((len(row) for row in normalized), default=0)
    return [row + [""] * (width - len(row)) for row in normalized]


def shared_strings(rows):
    strings = []
    index = {}
    for row in rows:
        for value in row:
            if is_number(value) or is_formula(value):
                continue
            if value not in index:
                index[value] = len(strings)
                strings.append(value)
    return strings, index


def is_number(value):
    return bool(re.fullmatch(r"-?\d+(\.\d+)?", value or ""))


def is_formula(value):
    return bool(value and value.startswith("="))


def cell_xml(row_index, col_index, value, string_index, header=False):
    ref = f"{col_name(col_index)}{row_index}"
    style = ' s="1"' if header else ""
    if is_formula(value):
        formula = html.escape(value[1:], quote=False)
        return f'<c r="{ref}"{style}><f>{formula}</f></c>'
    if is_number(value):
        return f'<c r="{ref}"{style}><v>{value}</v></c>'
    idx = string_index[value]
    return f'<c r="{ref}" t="s"{style}><v>{idx}</v></c>'


def worksheet_xml(rows, string_index):
    sheet_rows = []
    for r_idx, row in enumerate(rows, 1):
        cells = [cell_xml(r_idx, c_idx, value, string_index, header=(r_idx == 1)) for c_idx, value in enumerate(row, 1)]
        sheet_rows.append(f'<row r="{r_idx}">{"".join(cells)}</row>')
    width = max((len(row) for row in rows), default=1)
    dimension = f"A1:{col_name(width)}{max(len(rows), 1)}"
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <dimension ref="{dimension}"/>
  <sheetViews><sheetView workbookViewId="0"/></sheetViews>
  <sheetFormatPr defaultRowHeight="15"/>
  <sheetData>{''.join(sheet_rows)}</sheetData>
</worksheet>
"""


def shared_strings_xml(strings):
    items = "".join(f'<si><t>{html.escape(value, quote=False)}</t></si>' for value in strings)
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="{len(strings)}" uniqueCount="{len(strings)}">{items}</sst>
"""


def workbook_xml(sheet_name):
    safe_name = html.escape(sanitize_sheet_name(sheet_name), quote=True)
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="{safe_name}" sheetId="1" r:id="rId1"/></sheets>
</workbook>
"""


def core_xml(title):
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    safe_title = html.escape(title or "Spreadsheet", quote=False)
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>{safe_title}</dc:title>
  <dc:creator>agent-dev-kit</dc:creator>
  <cp:lastModifiedBy>agent-dev-kit</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>
"""


def write_xlsx(output, title, rows):
    rows = normalize_rows(rows)
    if not rows:
        rows = [["Value"]]
    strings, string_index = shared_strings(rows)
    os.makedirs(os.path.dirname(os.path.abspath(output)) or ".", exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", CONTENT_TYPES)
        z.writestr("_rels/.rels", ROOT_RELS)
        z.writestr("xl/_rels/workbook.xml.rels", WORKBOOK_RELS)
        z.writestr("xl/workbook.xml", workbook_xml(title))
        z.writestr("xl/worksheets/sheet1.xml", worksheet_xml(rows, string_index))
        z.writestr("xl/styles.xml", STYLES_XML)
        z.writestr("xl/sharedStrings.xml", shared_strings_xml(strings))
        z.writestr("docProps/core.xml", core_xml(title))
        z.writestr("docProps/app.xml", APP_XML)


def main():
    parser = argparse.ArgumentParser(description="Create a basic Microsoft Excel .xlsx file.")
    parser.add_argument("--title", default="Sheet1")
    parser.add_argument("--input")
    parser.add_argument("--data", default="")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    if args.input:
        with open(args.input, "r", encoding="utf-8") as f:
            text = f.read()
    else:
        text = args.data
    rows = parse_rows(text)
    write_xlsx(args.output, args.title, rows)
    print(os.path.abspath(args.output))


if __name__ == "__main__":
    main()
