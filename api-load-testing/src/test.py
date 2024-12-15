from locust import HttpUser, task, between

class ApiUser(HttpUser):
    # Define the host domain where your API is running
    host = "https://fa-masontest-0000000001.azurewebsites.net"
    @task
    def get_api(self):
        # Send a GET request to a specific endpoint
        self.client.get("/api/httpfunction")  # Replace with your API endpoint
