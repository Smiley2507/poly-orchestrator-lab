export type Product = {
  id: number
  name: string
  description: string
  price: number
  image_url: string
  in_stock: boolean
}

// Configurable at build time. Empty string = same-origin relative requests,
// which nginx proxies to the backend (Compose service name / ECS Service Connect).
const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL ?? '').replace(/\/$/, '')

export async function fetchProducts(): Promise<Product[]> {
  const res = await fetch(`${API_BASE_URL}/api/products`)
  if (!res.ok) throw new Error(`Request failed with status ${res.status}`)
  return res.json()
}

export async function fetchProduct(id: number | string): Promise<Product> {
  const res = await fetch(`${API_BASE_URL}/api/products/${id}`)
  if (res.status === 404) throw new Error('NOT_FOUND')
  if (!res.ok) throw new Error(`Request failed with status ${res.status}`)
  return res.json()
}
