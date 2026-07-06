type Req = { headers: { origin?: string } }
type Res = { setHeader(name: string, value: string): void; json(value: unknown): void }

export function userSettings(req: Req, res: Res) {
  if (req.headers.origin) {
    res.setHeader('Access-Control-Allow-Origin', req.headers.origin)
    res.setHeader('Access-Control-Allow-Credentials', 'true')
  }
  res.json({ theme: 'dark' })
}
