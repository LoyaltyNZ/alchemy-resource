# # Example 1: Sending a message to a resource
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
# Make show action public so no authentication is needed
hello_resource.show.public = true

# The resource service is created which contains the resource
service = new AlchemyResource.ResourceService('hello.service', [hello_resource])

# Start the Resource Service
service.start()
.then( ->
  # Service sending message to the resource,
  # it only knows the path and does not know where the service lives.
  service.send_message_to_resource({
    path: '/hello'
    body: JSON.stringify({ name: "Alice" })
    verb: "GET"
  })
)
.then( (response) ->
  console.log(response.body) # "Hello Alice"
)
.finally( ->
  service.stop()
)
