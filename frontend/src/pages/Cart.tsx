import { Link } from 'react-router-dom'
import { useCart } from '../cart/CartContext'

export default function Cart() {
  const { items, increment, decrement, removeItem, subtotal } = useCart()

  if (items.length === 0) {
    return (
      <div className="state cart-empty">
        <strong>Your cart is empty.</strong>
        <Link to="/" className="btn btn--primary">
          Continue Shopping
        </Link>
      </div>
    )
  }

  return (
    <div className="cart-page">
      <h1>Shopping Cart</h1>

      <ul className="cart-list">
        {items.map((item) => (
          <li key={item.id} className="cart-line">
            <img src={item.image_url} alt={item.name} className="cart-line__image" />
            <div className="cart-line__info">
              <p className="cart-line__name">{item.name}</p>
              <p className="cart-line__price">${item.price.toFixed(2)}</p>
            </div>
            <div className="quantity-selector">
              <button type="button" onClick={() => decrement(item.id)} aria-label={`Decrease quantity of ${item.name}`}>
                −
              </button>
              <span className="quantity-selector__value">{item.quantity}</span>
              <button type="button" onClick={() => increment(item.id)} aria-label={`Increase quantity of ${item.name}`}>
                +
              </button>
            </div>
            <p className="cart-line__total">${(item.price * item.quantity).toFixed(2)}</p>
            <button className="cart-line__remove" onClick={() => removeItem(item.id)} aria-label={`Remove ${item.name}`}>
              Remove
            </button>
          </li>
        ))}
      </ul>

      <div className="cart-summary">
        <span>Subtotal</span>
        <strong>${subtotal.toFixed(2)}</strong>
      </div>

      <Link to="/" className="btn btn--secondary">
        Continue Shopping
      </Link>
    </div>
  )
}
