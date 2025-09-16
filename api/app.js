const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

app.get('/api/movies', (req, res) => {
  res.json([
    { id: 1, title: "Inception", genre: "Sci-Fi" },
    { id: 2, title: "Interstellar", genre: "Sci-Fi" },
    { id: 3, title: "The Dark Knight", genre: "Action" }
  ]);
});

app.get('/', (req, res) => {
  res.send('Welcome to BookMyShow API');
});

app.listen(port, () => {
  console.log(`BookMyShow API listening on port ${port}`);
});
