<!--
---
name: Remote MCP with Azure Functions (Python)
description: Run a remote MCP server on Azure functions.  
page_type: sample
languages:
- python
- bicep
- azdeveloper
products:
- azure-functions
- azure
urlFragment: remote-mcp-functions-python
---
-->

# Getting Started with Remote MCP Servers using Azure Functions (Python)

This is a quickstart template to easily build and deploy a custom remote MCP server to the cloud using Azure Functions with Python.  The MCP server is secured by design using keys and HTTPS, and allows more options for OAuth using built-in auth and/or API Management as well as network isolation using VNET.

>Note

>Large Language Models (LLMs) are non-deterministic and it's important to be aware of their possible inaccuracies, real-time changes. Therefore recommend to double-check information and validate before making decisions.


## Prerequisites

+ [Python](https://www.python.org/downloads/) version 3.11 or higher
+ [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local?pivots=programming-language-python#install-the-azure-functions-core-tools)
+ + To use Visual Studio Code to run and debug locally:
  + [Visual Studio Code](https://code.visualstudio.com/)
  + [Azure Functions extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)

> Note : Here I have used [Rapid API marketplace](https://rapidapi.com/hub) Booking COM travel APIs to make calls and process the travel details. The API needs a key so you will need to subscribe for Booking COM API to get the key and use it.


## Prepare your local environment

An Azure Storage Emulator is needed for this particular sample because we will save and get snippets from blob storage.

1. Start Azurite

    ```shell
    docker run -p 10000:10000 -p 10001:10001 -p 10002:10002 \
        mcr.microsoft.com/azure-storage/azurite
    ```

>**Note** if you use Azurite coming from VS Code extension you need to run `Azurite: Start` now or you will see errors.

## Run your MCP Server locally from the terminal

1. Change to the src folder in a new terminal window:

   ```shell
   cd src
   ```

1. Install Python dependencies:

   ```shell
   pip install -r requirements.txt
   ```

1. Start the Functions host locally:

   ```shell
   func start
   ```

> **Note** by default this will use the webhooks route: `/runtime/webhooks/mcp/sse`.  Later we will use this in Azure to set the key on client/host calls: `/runtime/webhooks/mcp/sse?code=<system_key>`

## Use the MCP server from within a client/host

### VS Code - Copilot Edits

1. **Add MCP Server** from command palette and add URL to your running Function app's SSE endpoint:

    ```shell
    http://0.0.0.0:7071/runtime/webhooks/mcp/sse
    OR
     http://localhost:7071/runtime/webhooks/mcp/sse
    ```

1. **List MCP Servers** from command palette and start the server
1. In Copilot chat agent mode enter a prompt to trigger the tool, e.g., select some code and enter this prompt

   

    ```plaintext
    Hey what are the attractions in <place of your choice> 
    ```

    ```plaintext
    Please share reviews of the tour <tour_name>
    ```

1. When prompted to run the tool, consent by clicking **Continue**

1. When you're done, press Ctrl+C in the terminal window to stop the Functions host process.

### MCP Inspector

1. In a **new terminal window**, install and run MCP Inspector

    ```shell
    npx @modelcontextprotocol/inspector
    ```

2. CTRL click to load the MCP Inspector web app from the URL displayed by the app (e.g. http://0.0.0.0:5173/#resources)
3. Set the transport type to `SSE`
4. Set the URL to your running Function app's SSE endpoint and **Connect**:

    ```shell
    http://0.0.0.0:7071/runtime/webhooks/mcp/sse
    ```

5. **List Tools**.  Click on a tool and **Run Tool**.  

## Deploy to Azure for Remote MCP

Use instructions documented in this [link](https://learn.microsoft.com/en-us/azure/container-apps/functions-usage?pivots=azure-portal) to provision the Azure Functions on Azure Container Apps resource hosting the MCP Azure Functions server using the all new MCP extension for Azure Functions

OR

Run this azd command to provision the function app, with any required Azure resources, and deploy your code:
```sh
azd up

```


Additionally, [API Management]() can be used for improved security and policies over your MCP Server, and [App Service built-in authentication](https://learn.microsoft.com/azure/app-service/overview-authentication-authorization) can be used to set up your favorite OAuth provider including Entra.  

### Connect to your function app from a client

Your client will need a key in order to invoke the new hosted SSE endpoint, which will be of the form `https://<function-name>.*****-****.<location>.azurecontainerapps.io`. The hosted function requires a system key by default which can be obtained from the Storage account-> Blob containers -> azure-webjobs-secrets->host.json -> View/edit Obtain the system key value named `mcp_extension`.

For MCP Inspector, you can include the key in the URL: 

```sh
`https://<function-name>.*****-****.<location>.azurecontainerapps.io/runtime/webhooks/mcp/sse?code=<your-mcp-extension-system-key>`.

```

For GitHub Copilot within VS Code, you should instead set the key as the `x-functions-key` header in `mcp.json`, and you would just use `https://<function-name>.*****-****.<location>.azurecontainerapps.io/runtime/webhooks/mcp/sse` for the URL. The following example uses an input and will prompt you to provide the key when you start the server from VS Code:

```json
{
    "inputs": [
        {
            "type": "promptString",
            "id": "functions-mcp-extension-system-key",
            "description": "Azure Functions MCP Extension System Key",
            "password": true
        }
    ],
    "servers": {
        "my-mcp-server": {
            "type": "sse",
            "url": "<funcappname>.azurewebsites.net/runtime/webhooks/mcp/sse",
            "headers": {
                "x-functions-key": "${input:functions-mcp-extension-system-key}"
            }
        }
    }
}
```





## Source Code

The function code for the `get_attractions` and `get_attractions_reviews` endpoints are defined in the Python files in the `src` directory. The MCP function annotations expose these functions as MCP Server tools.

Here's the actual code from the function_app.py file:

```python

@app.generic_trigger(arg_name="context", type="mcpToolTrigger", toolName="hello", 
                     description="Hello world.", 
                     toolProperties="[]")
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
```

Note that the `host.json` file also includes a reference to the experimental bundle, which is required for apps using this feature:

```json
"extensionBundle": {
  "id": "Microsoft.Azure.Functions.ExtensionBundle.Experimental",
  "version": "[4.*, 5.0.0)"
}
```

## Next Steps

- Add [API Management]() to your MCP server
- Add [built-in auth]() to your MCP server
- Enable VNET using VNET_ENABLED=true flag
- Learn more about [related MCP efforts from Microsoft]()
