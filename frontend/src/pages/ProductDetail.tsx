import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { fetchProduct, type Product } from '../api'
import { useCart } from '../cart/CartContext'

export default function ProductDetail() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { addItem } = useCart()

  const [product, setProduct] = useState<Product | null>(null)
  const [loading, setLoading] = useState(true)
  const [notFound, setNotFound] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [quantity, setQuantity] = useState(1)
  const [added, setAdded] = useState(false)

  useEffect(() => {
    let cancelled = false

    async function load() {
      if (!id) return
      setLoading(true)
      setError(null)
      setNotFound(false)
      setAdded(false)
      try {
        const data = await fetchProduct(id)
        if (!cancelled) {
          setProduct(data)
          setQuantity(1)
        }
      } catch (err) {
        if (cancelled) return
        if (err instanceof Error && err.message === 'NOT_FOUND') {
          setNotFound(true)
        } else {
          setError(err instanceof Error ? err.message : 'Unknown error')
        }
      } finally {
        if (!cancelled) setLoading(false)
      }
    }

    void load()
    return () => {
      cancelled = true
    }
  }, [id])

  if (loading) {
    return <p className="state">Loading product…</p>
  }

  if (notFound) {
    return (
      <div className="state">
        <strong>Product not found.</strong>
        <button className="btn btn--secondary" onClick={() => navigate('/')}>
          Back to shopping
        </button>
      </div>
    )
  }

  if (error || !product) {
    return (
      <div className="state state--error">
        <strong>Unable to load this product.</strong>
        <span>Please try again.</span>
      </div>
    )
  }

  return (
    <div className="product-detail">
      <Link to="/" className="back-link">
        ← Back to shopping
      </Link>

      <div className="product-detail__layout">
        <img src={product.image_url} alt={product.name} className="product-detail__image" />

        <div className="product-detail__info">
          <h1>{product.name}</h1>
          <p className="product-detail__price">${product.price.toFixed(2)}</p>
          <p className="product-detail__desc">{product.description}</p>

          <p className={`stock-badge ${product.in_stock ? 'stock-badge--in' : 'stock-badge--out'}`}>
            {product.in_stock ? 'In stock' : 'Out of stock'}
          </p>

          <div className="quantity-selector">
            <span>Quantity</span>
            <button
              type="button"
              onClick={() => setQuantity((q) => Math.max(1, q - 1))}
              disabled={!product.in_stock}
              aria-label="Decrease quantity"
            >
              −
            </button>
            <span className="quantity-selector__value">{quantity}</span>
            <button
              type="button"
              onClick={() => setQuantity((q) => q + 1)}
              disabled={!product.in_stock}
              aria-label="Increase quantity"
            >
              +
            </button>
          </div>

          <button
            className="btn btn--primary btn--large"
            disabled={!product.in_stock}
            onClick={() => {
              addItem(product, quantity)
              setAdded(true)
            }}
          >
            {product.in_stock ? 'Add to Cart' : 'Out of Stock'}
          </button>

          {added && <p className="added-note">Added to cart.</p>}
        </div>
      </div>
    </div>
  )
}
