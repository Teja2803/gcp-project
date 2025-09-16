from locust import HttpUser, task, between

class BookMyShowUser(HttpUser):
    wait_time = between(1, 5)

    @task
    def browse_movies(self):
        self.client.get("/api/movies")

    @task
    def home_page(self):
        self.client.get("/")