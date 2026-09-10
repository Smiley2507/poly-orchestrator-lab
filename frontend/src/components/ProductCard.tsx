import { Link } from 'react-router-dom'
import type { Product } from '../api'
import { useCart } from '../cart/CartContext'

export default function ProductCard({ product }: { product: Product }) {
  const { addItem } = useCart()

  return (
    <li className="product-card">
      <Link to={`/products/${product.id}`} className="product-card__image-link">
        <img src={product.image_url} alt={product.name} className="product-card__image" loading="lazy" />
      </Link>
      <div className="product-card__body">
        <h3 className="product-card__name">
          <Link to={`/products/${product.id}`}>{product.name}</Link>
        </h3>
        <p className="product-card__desc">{product.description}</p>
        <p className="product-card__price">${product.price.toFixed(2)}</p>
        {!product.in_stock && <p className="product-card__stock">Out of stock</p>}
        <div className="product-card__actions">
          <Link to={`/products/${product.id}`} className="btn btn--secondary">
            View Product
          </Link>
          <button
            className="btn btn--primary"
            disabled={!product.in_stock}
            onClick={() => addItem(product, 1)}
          >
            Add to Cart
          </button>
        </div>
      </div>
    </li>
  )
}
