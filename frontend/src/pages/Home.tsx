import { useEffect, useMemo, useState } from 'react'
import { fetchProducts, type Product } from '../api'
import ProductCard from '../components/ProductCard'

export default function Home({ search }: { search: string }) {
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false

    async function load() {
      setLoading(true)
      setError(null)
      try {
        const data = await fetchProducts()
        if (!cancelled) setProducts(data)
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Unknown error')
      } finally {
        if (!cancelled) setLoading(false)
      }
    }

    void load()
    return () => {
      cancelled = true
    }
  }, [])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return products
    return products.filter(
      (p) => p.name.toLowerCase().includes(q) || p.description.toLowerCase().includes(q),
    )
  }, [products, search])

  return (
    <>
      <section className="hero">
        <h1>Find what you need.</h1>
        <p>Simple shopping, made easy.</p>
        <a href="#catalog" className="btn btn--primary">
          Browse Products
        </a>
      </section>

      <section id="catalog" className="catalog">
        <div className="catalog__header">
          <h2>Featured Products</h2>
        </div>

        {loading && <p className="state">Loading products…</p>}

        {error && !loading && (
          <div className="state state--error">
            <strong>Unable to load products.</strong>
            <span>Please try again.</span>
          </div>
        )}

        {!loading && !error && filtered.length === 0 && (
          <p className="state">No products match your search.</p>
        )}

        {!loading && !error && filtered.length > 0 && (
          <ul className="product-grid">
            {filtered.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </ul>
        )}
      </section>
    </>
  )
}
