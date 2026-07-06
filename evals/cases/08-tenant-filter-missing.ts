type Db = {
  invoice: {
    findUnique(args: { where: { id: string } }): Promise<{ id: string; tenantId: string; total: number } | null>
  }
}

export async function getInvoice(db: Db, user: { tenantId: string }, invoiceId: string) {
  const invoice = await db.invoice.findUnique({ where: { id: invoiceId } })
  if (!invoice) return null
  return invoice
}
