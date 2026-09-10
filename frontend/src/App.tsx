import { useState } from 'react'
import { Route, Routes } from 'react-router-dom'
import Header from './components/Header'
import Home from './pages/Home'
import ProductDetail from './pages/ProductDetail'
import Cart from './pages/Cart'

export default function App() {
  const [search, setSearch] = useState('')

  return (
    <div className="page">
      <Header search={search} onSearchChange={setSearch} />

      <main className="main">
        <Routes>
          <Route path="/" element={<Home search={search} />} />
          <Route path="/products/:id" element={<ProductDetail />} />
          <Route path="/cart" element={<Cart />} />
        </Routes>
      </main>

      <footer className="footer">Poly-Orchestrator lab · local Docker Compose</footer>
    </div>
  )
}
