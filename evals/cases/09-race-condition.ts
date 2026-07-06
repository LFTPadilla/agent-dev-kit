type Store = {
  countActive(userId: string): Promise<number>
  createSession(userId: string): Promise<{ id: string }>
}

export async function createSession(store: Store, userId: string) {
  const active = await store.countActive(userId)
  if (active >= 3) throw new Error('too many sessions')
  return store.createSession(userId)
}
