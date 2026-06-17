// PLANTED: SQL injection — user-controlled id interpolated into the query string.
// Expected: security finding, CRITICAL.
import { db } from './db'

export async function getUser(id: string) {
  const query = `SELECT * FROM users WHERE id = '${id}'`
  return db.query(query)
}
