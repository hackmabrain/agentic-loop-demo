// GET /products            — list, optionally filter by ?category=
// GET /products/:id         — fetch one product
//
// SEEDED BUG (this is what GitHub Copilot Coding Agent fixes during the demo):
//   The list handler assumes req.query.category is always a string.
//   When the client calls /products with no query string, req.query.category
//   is undefined and `.toLowerCase()` throws TypeError → Express returns 500.
//
//   The audience-friendly fix is small: handle the no-category case (return
//   all products), validate the category against the known set, and lower-case
//   only when defined. There is a unit test in tests/products.test.js that
//   currently FAILS — the Coding Agent will make it pass.

const express = require('express');
const { products, validCategories } = require('../data/catalog');

const router = express.Router();

// GET /products
// BUG ▼ — five lines, easy for the agent to fix, satisfying for the audience.
router.get('/', (req, res) => {
  const category = req.query.category.toLowerCase(); // throws when undefined
  const filtered = products.filter(p => p.category === category);
  res.json(filtered);
});
// BUG ▲

// GET /products/:id
router.get('/:id', (req, res) => {
  const product = products.find(p => p.id === req.params.id);
  if (!product) {
    return res.status(404).json({ error: 'product_not_found', id: req.params.id });
  }
  res.json(product);
});

module.exports = router;
