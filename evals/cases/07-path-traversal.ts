import { readFile } from 'node:fs/promises'
import path from 'node:path'

export async function downloadInvoice(userId: string, filename: string) {
  const base = path.join('/srv/app/invoices', userId)
  const fullPath = path.join(base, filename)
  return readFile(fullPath, 'utf8')
}
