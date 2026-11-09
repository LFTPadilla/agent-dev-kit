---
name: task-intake
tags: ['skill']
description: 'Starts a new task with full context and minimum human attention. Collects every source, writes a one-page brief with one diagram and one ELI5 analogy, and asks only the questions that change the plan. Use when a new task, ticket, or assignment arrives. Triggers on: "new task", "I got assigned", "onboard me to this ticket", "help me understand this task", "where do I start".'
---

# Task Intake

"Take as little human attention as possible and give as much value as possible."

## Output contract

The human receives a short chat summary and links to the full task record.

1. Keep chat within 120 words by default. Expand for requested detail or a safe, correct decision.
2. Save the complete brief, source notes, approach options, and stakeholder message in the task record.
3. The brief gives the gist in 2 minutes and full depth in 10 minutes.
4. Ask at most 3 questions. Include a recommended answer with each question.
5. Draft the stakeholder questions as one message, ready to send.

Keep requested artifacts complete. Link detailed evidence instead of repeating it in chat.

## Step 0. Open the task record

Use the workspace convention for work items.

If the workspace has no convention, create `tasks/<YYYY-MM-DD>-<slug>/` with these items:

1. `brief.md`. Put the done criteria first.
2. `notes.md`.
3. `outputs/`.

## Step 1. Collect

Ask the human nothing in this step.

1. Copy the assignment verbatim.
2. Recall memory for the project and the topic.
3. Read every linked document end to end.
4. Locate the code paths as `file:line` at one fixed commit.
5. Fetch current docs for every external API and every library. Use Context7 or the vendor docs. Never use training data.
6. Write each fact in `notes.md` with its source.
7. Mark each interpretation as an interpretation.

## Step 2. Distill

Write the 60-second layer in this order.

1. State the problem in one sentence.
2. Show today and the target in one diagram. Use a timeline for dates. Use a flow for systems. Use a state machine for statuses.
3. Give one ELI5 analogy. Map each moving part to one everyday object.
4. Define at most 7 new terms in a glossary.
5. Quote what must change and what must not change. Take the quotes from the sources.
6. List each conflict. When two sources disagree, quote both sources.

## Step 3. Explain

Default to one HTML page. Layer the depth in this order: TL;DR, diagram, analogy, details, sources.

Use one toggle for the before view and the after view.

Route through `explain-concept` when that default does not fit.

1. Use a narrated video only when speech must give the order of events.
2. Use a `file:line` trail when the reader will read the code.

## Step 4. Grill

1. List every open question.
2. Search memory, docs, and tickets before you keep a question.
3. Delete each question that a source answers.
4. Delete each question whose answer does not change the plan.
5. For each question that remains, write why it matters, the options, the recommended answer, and who answers.
6. Ask the human at most 3 questions.
7. Use a grilling skill when one is installed. Ask directly when no grilling skill is installed.
8. Draft the stakeholder questions as one message.

## Step 5. Record

1. Store each confirmed fact and each confirmed decision in memory.
2. Update the task status and the time log when the workspace keeps them.

## Step 6. Hand off to planning

Record 2 or 3 approach options in the brief. State the trade-offs and recommend one option.
In chat, link the brief and give the recommendation.

Apply the ponytail rules. Choose the smallest approach that meets every constraint.

Mark the recommendation as preliminary until the open questions close.

## Anti-patterns

- A wall of text before the diagram.
- A question that a document already answers.
- A summary that hides a conflict between the assignment and the spec.
- Two mediums for one explanation when one medium is enough.
