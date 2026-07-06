type Req = { headers: { authorization?: string }; body: unknown }
type Logger = { info(value: unknown): void }

export function handleWebhook(req: Req, logger: Logger) {
  logger.info({
    authorization: req.headers.authorization,
    body: req.body
  })
  return { ok: true }
}
