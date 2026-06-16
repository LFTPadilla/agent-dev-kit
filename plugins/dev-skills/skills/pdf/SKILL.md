---
name: pdf
tags: ['skill']
description: Work with PDF files using the environment's built-in PDF and document tools. Use when the user wants to inspect, summarize, split, merge, compress, or convert PDFs.
---

# PDF

Use this skill when a user asks to work with a PDF or another document format that needs PDF conversion.

## Preferred path

Use the environment's built-in document and PDF tooling first. Prefer:

- reading and summarizing PDFs,
- extracting specific pages,
- merging PDFs,
- compressing PDFs,
- converting common document formats to or from PDF.

## Guidance

- If the user wants information from a PDF, inspect the file and answer directly.
- If the user wants a document operation, use the available PDF/document toolchain instead of inventing shell pipelines.
- Keep page references explicit when summarizing or extracting.
- Confirm before destructive operations like overwriting or replacing a file.

## Notes

- If the environment already exposes richer built-in PDF tools, treat this skill as routing guidance, not as a custom implementation.
