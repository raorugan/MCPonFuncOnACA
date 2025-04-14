import json
import logging
import requests


import azure.functions as func

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# Constants for the Azure Blob Storage container, file, and blob path



class ToolProperty:
    def __init__(self, property_name: str, property_type: str, description: str):
        self.propertyName = property_name
        self.propertyType = property_type
        self.description = description

    def to_dict(self):
        return {
            "propertyName": self.propertyName,
            "propertyType": self.propertyType,
            "description": self.description,
        }


# Define the tool properties using the ToolProperty class


tool_properties_get_attractions_object = [
    ToolProperty("query", "string", "The search query for the location."),
    ToolProperty("languagecode", "string", "The language code for the response."),
]

tool_properties_get_attraction_reviews_object = [
    ToolProperty("id", "string", "The ID of the attraction."),
    ToolProperty("page", "integer", "The page number for reviews."),
]

# Convert the tool properties to JSON

tool_properties_get_attractions_json = json.dumps([prop.to_dict() for prop in tool_properties_get_attractions_object])
tool_properties_get_attraction_reviews_json = json.dumps(
    [prop.to_dict() for prop in tool_properties_get_attraction_reviews_object]
)


@app.generic_trigger(
    arg_name="context",
    type="mcpToolTrigger",
    toolName="hello_mcp",
    description="Hello world.",
    toolProperties="[]",
)
def hello_mcp(context) -> None:
    """
    A simple function that returns a greeting message.

    Args:
        context: The trigger context (not used in this function).

    Returns:
        str: A greeting message.
    """
    return "Hello I am MCPTool!"


@app.generic_trigger(
    arg_name="context",
    type="mcpToolTrigger",
    toolName="get_attractions",
    description="Retrieve attractions at a search location.",
    toolProperties=tool_properties_get_attractions_json,
)
def get_attractions(context) -> str:
    """
    Retrieves attractions at a search location using the RapidAPI endpoint.

    Args:
        context: The trigger context containing the input arguments.

    Returns:
        str: A JSON string containing the attractions or an error message.
    """
    content = json.loads(context)
    query = content["arguments"].get("query", "").strip()
    language_code = content["arguments"].get("languagecode", "en-us").strip()

    if not query:
        logging.error("No search query provided.")
        return json.dumps({"error": "No search query provided."})

    url = "https://booking-com15.p.rapidapi.com/api/v1/attraction/searchLocation"
    query_params = {
        "query": query,
        "languagecode": "en-us",
    }
    headers = {
        "x-rapidapi-host": "booking-com15.p.rapidapi.com",
# Replace the API key with a secure method of retrieval (e.g., environment variable)
        "x-rapidapi-key": "8e67031934mshca12b6f3403e477p1117cajsn8506d5ca6a48"
    }

    logging.info(f"Sending request to {url} with params: {query_params}")
    try:
        response = requests.get(url, headers=headers, params=query_params)
        response.raise_for_status()  # Raise an exception for HTTP errors
    except requests.exceptions.RequestException as e:
        logging.error(f"HTTP request failed: {e}")
        return json.dumps({"error": f"HTTP request failed: {str(e)}"})

    try:
        data = response.json()
        attractions = extract_attractions(data)

        if not attractions:
            logging.warning("No attractions found in the response.")
            return json.dumps({"query": query, "attractions": []})

        result = {"query": query, "attractions": attractions}
        logging.info(f"Retrieved attractions: {result}")
        return json.dumps(result)
    except (json.JSONDecodeError, KeyError) as e:
        logging.error(f"Failed to parse JSON response or extract data: {e}")
        logging.debug(f"Response content: {response.text}")
        return json.dumps({"error": "Invalid response format or missing data from API."})


@app.generic_trigger(
    arg_name="context",
    type="mcpToolTrigger",
    toolName="get_attraction_reviews",
    description="Retrieve reviews for a specific attraction.",
    toolProperties=tool_properties_get_attraction_reviews_json,
)
def get_attraction_reviews(context) -> str:
    """
    Retrieves reviews for a specific attraction using the RapidAPI endpoint.

    Args:
        context: The trigger context containing the input arguments.

    Returns:
        str: A JSON string containing the reviews or an error message.
    """
    content = json.loads(context)
    attraction_id = content["arguments"].get("id", "").strip()
    page = content["arguments"].get("page", 1)

    if not attraction_id:
        logging.error("No attraction ID provided.")
        return json.dumps({"error": "No attraction ID provided."})

    url = "https://booking-com15.p.rapidapi.com/api/v1/attraction/getAttractionReviews"
    query_params = {
        "id": attraction_id,
        "page": page,
    }
    headers = {
        "x-rapidapi-host": "booking-com15.p.rapidapi.com",
        # Replace the API key with a secure method of retrieval (e.g., environment variable)
        "x-rapidapi-key": "8e67031934mshca12b6f3403e477p1117cajsn8506d5ca6a48"
    }

    logging.info(f"Sending request to {url} with params: {query_params}")
    try:
        response = requests.get(url, headers=headers, params=query_params)
        response.raise_for_status()  # Raise an exception for HTTP errors
    except requests.exceptions.RequestException as e:
        logging.error(f"HTTP request failed: {e}")
        return json.dumps({"error": f"HTTP request failed: {str(e)}"})

    try:
        data = response.json()
        reviews = extract_reviews(data)

        if not reviews:
            logging.warning("No reviews found in the response.")
            return json.dumps({"id": attraction_id, "reviews": []})

        result = {"id": attraction_id, "reviews": reviews}
        logging.info(f"Retrieved reviews: {result}")
        return json.dumps(result)
    except (json.JSONDecodeError, KeyError) as e:
        logging.error(f"Failed to parse JSON response or extract data: {e}")
        logging.debug(f"Response content: {response.text}")
        return json.dumps({"error": "Invalid response format or missing data from API."})


def extract_reviews(response_json):
    """
    Extracts the reviews from the API response.

    Args:
        response_json (dict): The JSON response from the API.

    Returns:
        list: A list of reviews containing the 'content', 'id', 'language', 'numericRating', and 'user' fields.
    """
    try:
        reviews = [
            {
                "content": review.get("content"),
                "id": review.get("id"),
                "language": review.get("language"),
                "numericRating": review.get("numericRating"),
                "user": review.get("user", {}).get("name"),
            }
            for review in response_json.get("data", [])  # Adjusted to match the provided JSON structure
            if isinstance(review, dict)  # Safeguard against non-dict items in the list
        ]
        return reviews
    except (KeyError, AttributeError, TypeError) as e:
        logging.error(f"Error while extracting reviews: {e}")
        return []


def extract_attractions(response_json):
    try:
        products = response_json.get("data", {}).get("products", [])
        attractions = [
            {
                "title": product.get("title"),
                "productId": product.get("productId"),
                "cityName": product.get("cityName"),
                "countryCode": product.get("countryCode"),
            }
            for product in products
        ]
        return attractions
    except KeyError as e:
        logging.error(f"KeyError: {e}")
        return []
