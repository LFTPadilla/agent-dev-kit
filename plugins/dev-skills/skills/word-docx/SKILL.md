---
name: word-docx
tags: ['skill']
description: Create Microsoft Word .docx documents from a title and body text. Use when the user asks for a Word file, .docx, formal letter, proposal, quote, report, or document to edit/share in Microsoft Word.
---

# Word DOCX

Use this skill when the user asks for a Word document.

## Output

- Create a real `.docx` file, not plain text renamed as `.docx`.
- Save it under the current workspace, preferably `workspace/` or the current conversation folder.
- Use a clear filename ending in `.docx`.
- Reply with the file path and a short note about what was created.

## Tool

```bash
python3 scripts/create_docx.py \
  --title "Document title" \
  --body-file input.md \
  --output output.docx
```

## Body Format

The body file is plain text or simple Markdown:

- Lines starting with `# ` become Heading 1.
- Lines starting with `## ` become Heading 2.
- Lines starting with `- ` or `* ` become bullets.
- Blank lines separate paragraphs.
- Other lines become normal paragraphs.

## Guidance

- For letters, include date, recipient, greeting, body, closing, and sender name if known.
- For business documents, use short sections with headings and bullets.
- If user did not give all details, make a clean draft with reasonable placeholders instead of blocking.
