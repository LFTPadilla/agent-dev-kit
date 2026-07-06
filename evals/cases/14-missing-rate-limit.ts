type Req = { body: { prompt: string } }
type AiClient = { complete(prompt: string): Promise<string> }

export async function publicComplete(req: Req, ai: AiClient) {
  const answer = await ai.complete(req.body.prompt)
  return { answer }
}
