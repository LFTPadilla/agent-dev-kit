import { useEffect, useState } from 'react'

export function SearchBox({ query }: { query: string }) {
  const [resultCount, setResultCount] = useState(0)

  useEffect(() => {
    let cancelled = false
    async function run() {
      const response = await fetch(`/api/search?q=${encodeURIComponent(query)}`)
      const data = await response.json()
      if (!cancelled) setResultCount(data.count)
    }
    run()
    return () => {
      cancelled = true
    }
  }, [query])

  return <p>{resultCount} results</p>
}
