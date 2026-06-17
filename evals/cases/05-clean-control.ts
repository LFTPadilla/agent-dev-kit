// CONTROL: no planted bug. Parameterized query, ownership check, awaited, scoped columns.
// A reviewer that reports a finding here is producing a FALSE POSITIVE.
import { db } from './db'

export async function getActiveUser(id: string, requesterId: string) {
  if (id !== requesterId) throw new Error('forbidden')
  return db.query('SELECT id, name FROM users WHERE id = $1 AND active = true', [id])
}
