// PLANTED: state-changing endpoint with no auth / ownership check.
// Expected: security finding, CRITICAL.
import type { Request, Response } from 'express'
import { db } from './db'

export async function deleteAccount(req: Request, res: Response) {
  const { userId } = req.params
  await db.query('DELETE FROM users WHERE id = $1', [userId])
  res.json({ ok: true })
}
