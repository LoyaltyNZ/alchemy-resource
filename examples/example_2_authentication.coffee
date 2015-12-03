# # Example 2: Authentication of a Message
#
# Prerequisites:
# * RabbitMQ running
# * Memcached running

AlchemyResource = require '../src/alchemy-resource'

# Creating the `Hello` resource, whose path is '/hello'
hello_resource = new AlchemyResource.Resource("Hello", '/hello')

# The Hello resource implements `show` which takes a body and returns a string of the name
hello_resource.show = (context) ->
  {body: "Hello #{context.body.name}"}

# The resource service is created which contains the resource
service = new AlchemyResource.ResourceService('hello.service', [hello_resource])

# Start the Resource Service
service.start()
.then( ->
  # **Authentication** would usually be handled by another service.
  #
  # Set the caller with the version and permissions to access the `show` method on the `Hello` resource
  service.set_caller("cid", {
    version: 1
    permissions: {
      resources: {
        "Hello": {
          "show": "allow"
        }
      }
    }
  })
)
.then( ->
  # Set the session with the caller_id and the caller_version
  service.set_session("sid", {
    caller_id: "cid",
    caller_version : 1
  })
)
.then( ->
  # For authentication the session id needs to be sent as header
  service.send_message_to_resource({
    path: '/hello'
    body: JSON.stringify({ name: "Alice" })
    verb: "GET"
    headers: {"x-session-id": "sid"}
  })
)
.then( (response) ->
  console.log(response.body) # "Hello Alice"
)
.finally( ->
  service.stop()
)
