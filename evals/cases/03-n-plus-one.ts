// PLANTED: N+1 query — one DB round-trip per user inside a loop.
// Expected: performance finding, HIGH/MEDIUM.
import { db } from './db'
import type { User } from './types'

export async function withPosts(users: User[]) {
  for (const u of users) {
    u.posts = await db.query('SELECT * FROM posts WHERE user_id = $1', [u.id])
  }
  return users
}
