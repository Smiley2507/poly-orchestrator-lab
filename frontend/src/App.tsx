import { useCallback, useEffect, useState } from 'react'
import { fetchProducts, type Product } from './api'

export default function App() {
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      setProducts(await fetchProducts())
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  return (
    <div className="page">
      <header className="header">
        <h1>ShopNow</h1>
        <p className="tagline">A tiny 3-tier demo app — React, FastAPI, PostgreSQL, Redis</p>
      </header>

      <main>
        <div className="toolbar">
          <h2>Products</h2>
          <button onClick={() => void load()} disabled={loading}>
            {loading ? 'Loading…' : 'Reload'}
          </button>
        </div>

        {loading && <p className="state">Loading products…</p>}

        {error && !loading && (
          <div className="state error">
            <strong>Could not load products.</strong>
            <span>{error}</span>
          </div>
        )}

        {!loading && !error && products.length === 0 && (
          <p className="state">No products found.</p>
        )}

        {!loading && !error && products.length > 0 && (
          <ul className="grid">
            {products.map((p) => (
              <li key={p.id} className="card">
                <h3>{p.name}</h3>
                <p className="desc">{p.description}</p>
                <p className="price">${p.price.toFixed(2)}</p>
              </li>
            ))}
          </ul>
        )}
      </main>

      <footer className="footer">Poly-Orchestrator lab · local Docker Compose</footer>
    </div>
  )
}
