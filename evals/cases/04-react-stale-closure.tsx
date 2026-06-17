// PLANTED: useEffect missing `userId` dependency -> stale closure, won't refetch on change.
// Expected: correctness finding, MEDIUM. (Deterministic SAST usually MISSES this; the LLM lens should catch it.)
import { useEffect, useState } from 'react'
import { fetchData } from './api'

export function Profile({ userId }: { userId: string }) {
  const [data, setData] = useState<unknown>(null)
  useEffect(() => {
    fetchData(userId).then(setData)
  }, [])
  return <div>{JSON.stringify(data)}</div>
}
