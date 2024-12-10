# from locust import HttpUser, task, constant

# class MyApiUser(HttpUser):
#     host = "https://your-api-url.com"
    
#     # Fixed wait time of 2 seconds between tasks
#     wait_time = constant(2)

#     @task
#     def get_api(self):
#         # Make a GET request to your endpoint
#         self.client.get("/your-endpoint")

from locust import HttpUser, task, constant, events
import threading

# Global variable to track the total number of requests
total_requests = 0
max_requests = 100000  # Set your maximum number of requests here

# Lock to ensure thread-safe access to total_requests
# request_counter_lock = threading.Lock()

class MyApiUser(HttpUser):
    host = "https://reqres.in/"
    
    # Fixed wait time of 2 seconds between tasks
    # wait_time = constant(2)

    @task
    def get_api(self):
        global total_requests

        # with request_counter_lock:
        if total_requests < max_requests:
            self.client.get("/api/users/2")
            total_requests += 1
        else:
            # Stop the test if max_requests is reached
            self.environment.runner.quit()

# Global event listener to stop the test after the limit is reached
@events.request.add_listener
def my_request_handler(request_type, name, response_time, response_length, response,
                       context, exception, start_time, url, **kwargs):

    global total_requests

    # with request_counter_lock:
    if total_requests >= max_requests:
        # Stop the test once the max number of requests is reached
        events.quitting.fire()
    if exception:
        print(f"Request to {name} failed with exception {exception}")
    else:
        print(f"Successfully made a request to: {name}")
        print(f"The response was {response.text}")
