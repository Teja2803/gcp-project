const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

app.use(express.json());

app.get('/api/events', (req, res) => {
  res.json([
    { id: 1, title: "Coldplay Concert", date: "2025-01-20", location: "Mumbai, India" },
    { id: 2, title: "Comedy Night", date: "2025-01-25", location: "Delhi, India" },
    { id: 3, title: "Art Exhibition", date: "2025-02-10", location: "Bangalore, India" }
  ]);
});

app.post('/api/book', (req, res) => {
  const { eventId, user } = req.body;
  // Simulate booking logic here
  res.json({ message: `Ticket booked for event ${eventId} by user ${user}` });
});

app.listen(port, () => {
  console.log(`API listening on port ${port}`);
});
