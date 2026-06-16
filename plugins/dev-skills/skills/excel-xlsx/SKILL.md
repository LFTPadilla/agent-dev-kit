---
name: excel-xlsx
tags: ['skill']
description: Create Microsoft Excel .xlsx spreadsheets from tables, CSV/TSV, Markdown tables, or JSON data. Use when the user asks for Excel, spreadsheet, .xlsx, tabla editable, budget, inventory, report table, calculations, or data they need to open/edit in Microsoft Excel.
---

# Excel XLSX

Use this skill when the user asks for an Excel spreadsheet or editable table.

## Output

- Create a real `.xlsx` file, not plain text renamed as `.xlsx`.
- Save it under the current workspace, preferably `workspace/`, `vault/`, or the current conversation folder.
- Use a clear filename ending in `.xlsx`.
- Reply with the file path and a short note about what was created.

## Tool

```bash
python3 scripts/create_xlsx.py \
  --title "Sheet title" \
  --input data.csv \
  --output output.xlsx
```

You can also pass data directly:

```bash
python3 scripts/create_xlsx.py \
  --title "Cotizacion" \
  --data "Item,Cantidad,Precio\nSilla,4,120000\nMesa,1,450000" \
  --output cotizacion.xlsx
```

## Input Formats

- CSV or TSV files.
- Markdown tables.
- JSON array of objects or array of arrays.
- Plain text tables separated by commas, tabs, semicolons, or pipes.

## Guidance

- Put headers in the first row when the user gives categories or columns.
- For budgets, quotes, inventories, grades, schedules, or reports, include totals and clear column names when useful.
- Use formulas only when the user needs calculations and the formula is straightforward.
- If the user gives messy text, normalize it into a clean table instead of blocking.
