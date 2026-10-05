// In-memory product catalog for the Agentic Developer Loop demo.
// Keep this file boring on purpose — the demo's interesting parts live in
// routes/products.js (the seeded bug) and server.js (INJECT_ERROR).

const products = [
  { id: 'p-001', name: 'Wireless Mouse',         category: 'electronics', price:  29.99, stockCount: 142 },
  { id: 'p-002', name: 'USB-C Hub (7-in-1)',     category: 'electronics', price:  49.50, stockCount:  87 },
  { id: 'p-003', name: 'Mechanical Keyboard',    category: 'electronics', price: 129.00, stockCount:  34 },
  { id: 'p-004', name: 'Noise-Cancel Headphones',category: 'electronics', price: 249.00, stockCount:  56 },
  { id: 'p-005', name: 'Standing Desk Mat',      category: 'office',      price:  39.95, stockCount:  78 },
  { id: 'p-006', name: 'Monitor Arm',            category: 'office',      price:  89.00, stockCount:  41 },
  { id: 'p-007', name: 'Notebook (A5, dotted)',  category: 'office',      price:  12.50, stockCount: 220 },
  { id: 'p-008', name: 'Travel Backpack 28L',    category: 'travel',      price:  74.00, stockCount:  62 },
  { id: 'p-009', name: 'Packing Cubes (4-pack)', category: 'travel',      price:  24.00, stockCount: 130 },
  { id: 'p-010', name: 'Insulated Bottle 750ml', category: 'travel',      price:  32.00, stockCount: 110 }
];

const validCategories = new Set(products.map(p => p.category));

module.exports = { products, validCategories };
