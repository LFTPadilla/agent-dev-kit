type Request = {
  body: { url: string }
}

export async function preview(req: Request) {
  const response = await fetch(req.body.url)
  return {
    status: response.status,
    body: await response.text()
  }
}
