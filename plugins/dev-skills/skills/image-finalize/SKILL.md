---
name: image-finalize
tags: ['skill']
description: Two-stage image generation workflow. First asks clarifying questions, then uses minimax for fast iterative drafts, then gemini-3-pro-image-preview for final polish. Trigger on image generation requests, editing/refining images, or when user wants to produce a final version.
---

# Image Finalize Skill

## Step 1: Briefing (MANDATORY before generating)

Before generating ANY image, ask the user these key questions:

1. **What is this for?** (Instagram post, banner, logo, etc.)
2. **What content should it include?** (text, services, products, specific messaging)
3. **What's the focus?** (e.g., hosting services, self-hosting, specific product)
4. **Style preference?** (illustration, photo-realistic, minimalist, etc.)
5. **Logo/branding?** (use existing logo, placeholder box, no logo, specific placement)
6. **Any reference images?** (upload or describe a style you like)

Keep it brief — 2-3 questions max, prioritizing the most important for the use case.

## Step 2: Iterative Drafts (minimax)

Once briefed, use `image_generate` with `model: "minimax/image-01"` for fast, cheap iterations.
- Deliver the image immediately.
- Ask for feedback.
- If logo placeholder needed, include a clearly marked "LOGO" area.

## Step 3: Final Polish (gemini)

When user signals finalization via keywords like:
- "final", "done", "approve", "polish", "ready", "finalize"
- "this is good", "love it", "perfect", "yes", "great"

**Before proceeding, confirm:**
> "Ready to generate the final polished version with Gemini 3.1 Pro? This will produce higher quality but may take longer."

If confirmed:
1. Use `image_generate` with:
   - `model: "google/gemini-3-pro-image-preview"`
   - Pass the last minimax image as reference (`images` parameter)
   - If user has a logo file, pass it as reference too
   - Prompt: "Polish and finalize this image to production quality. Maintain the same composition and subject. Enhance details, lighting, and overall professional finish. Replace any LOGO placeholder with the provided logo."
2. Deliver final image.

## Notes

- minimax is fast/cheap for drafts; Gemini is slower/higher quality for final.
- If Google provider shows `configured: no`, warn user: "Gemini 3.1 Pro not configured. Please set GEMINI_API_KEY."
- Always deliver the final version with `MEDIA:` tag for inline display.