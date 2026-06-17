// PLANTED: SQL injection — request-sourced id interpolated into the query string.
// Expected: security finding, CRITICAL.
import type { Request, Response } from 'express'
import { db } from './db'

export async function getUser(req: Request, res: Response) {
  const id = req.query.id as string
  const query = `SELECT * FROM users WHERE id = '${id}'`
  res.json(await db.query(query))
}
