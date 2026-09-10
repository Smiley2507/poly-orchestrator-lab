import { Link, NavLink } from 'react-router-dom'
import { useCart } from '../cart/CartContext'

type HeaderProps = {
  search: string
  onSearchChange: (value: string) => void
}

export default function Header({ search, onSearchChange }: HeaderProps) {
  const { totalItems } = useCart()

  return (
    <header className="site-header">
      <div className="site-header__row">
        <Link to="/" className="brand">
          ShopNow
        </Link>

        <nav className="main-nav">
          <NavLink to="/" end className={({ isActive }) => (isActive ? 'active' : '')}>
            Home
          </NavLink>
          <NavLink to="/" className={({ isActive }) => (isActive ? 'active' : '')}>
            Shop
          </NavLink>
        </nav>

        <input
          type="search"
          className="search-input"
          placeholder="Search products…"
          value={search}
          onChange={(e) => onSearchChange(e.target.value)}
          aria-label="Search products"
        />

        <Link to="/cart" className="cart-link" aria-label="View cart">
          <CartIcon />
          <span className="cart-count">{totalItems}</span>
        </Link>
      </div>
    </header>
  )
}

function CartIcon() {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="9" cy="21" r="1.5" fill="currentColor" stroke="none" />
      <circle cx="19" cy="21" r="1.5" fill="currentColor" stroke="none" />
      <path d="M2.5 3h2l2.2 12.2a2 2 0 0 0 2 1.6h8.6a2 2 0 0 0 2-1.6L21 7H6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}
