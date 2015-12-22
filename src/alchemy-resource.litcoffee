# Alchemy Resource

Alchemy Resource is an opinionated way to use the
[alchemy-ether](https://github.com/LoyaltyNZ/alchemy-ether)
implementation of the Alchemy Framework to
create a RESTful, scalable and highly available API.

The opinions that Alchemy Resource has are:

* Resource APIs have only 4 actions that match directly to HTTP methods:
  `GET` is `show`, `POST` is `create`, `PATCH` is `update` and `DELETE` is `delete`
* The returned error message structure contains a `code` that is from a set of well defined error types (e.g. `platform.not_found`), a human readable `message`, and a UUID `reference` so API clients and providers have a shared key to discuss specific errors.
* Service discovery is accomplished using [RabbitMQ topic exchanges]((https://www.rabbitmq.com/tutorials/tutorial-five-javascript.html)): A resource registers its path as a binding key on the topic exchange `resources.exchange`, e.g. `/v1/users` registers with the binding key `v1.users.#`, then all messages send to `/v1/users` are sent with the routing key `v1.users` which routes messages to the resource.
* Structured Logging is done via a RabbitMQ queue: Alchemy Resource asynchronously sends messages to a logging queue where a specialised service listens and writes to various outputs (database, console ...)
* Authentication is accomplished by a caller creating a session and sending the resulting session identifier in a header on each subsequent request: A `Caller` is resource that has a set of `permissions`, e.g. a caller may be permitted to call `show` on the `Users` resource but not `create`. A `Session` and `Caller` are both resources that are implemented using Alchemy Resource. To `create` a session a caller sends its id and secret to the Session resource, a session id and expiry is returned to be used for authentication. *Currently sessions are stored in memcached, this will likely change in the future*.

Other projects that are in different stages of development and open-sourcing that will enable a complete system are:

* Alchemy [Auth](https://github.com/LoyaltyNZ/alchemy-auth) implements the Session and Caller resources and handle the authentication tasks.
* Alchemy [Router](https://github.com/LoyaltyNZ/alchemy-router) is a gateway and router that receives HTTP requests and sends them to the correct resource.
* Alchemy [Logger](https://github.com/LoyaltyNZ/alchemy-logger) receives structured logging messages and writes them to various outputs including Database, SQS and log entries.

## Getting Started

To install Alchemy-Ether:

```
npm install alchemy-resource
```

This example creates a resource `Hello` which is located at `/hello`, then call its `show` method:

```coffeescript
AlchemyResource = require 'alchemy-resource'

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
```


## Examples

* [Sending a message to a Resource](http://loyaltynz.github.io/alchemy-resource/docs/examples/example_1_send_message.html)
* [Authentication of a Resource](http://loyaltynz.github.io/alchemy-resource/docs/examples/example_2_authentication.html)

## Documentation

*This Alchemy Resource documentation is generated with [docco](https://jashkenas.github.io/docco/) from the annotated source code.*

The Alchemy Resource package exports:

1. [Resource](http://loyaltynz.github.io/alchemy-resource/docs/src/resource.html) the interface that is overridden to implement Resources.
2. [ResourceService](http://loyaltynz.github.io/alchemy-resource/docs/src/resource_service.html) contains many resources and manages their discovery, authentication and logging.
3. [Bam](http://loyaltynz.github.io/alchemy-resource/docs/src/bam.html) (a homage to [Boom](https://www.npmjs.com/package/boom)) contains the formatted errors to be returned.
4. [MemcachedSessionClient](http://loyaltynz.github.io/alchemy-resource/docs/src/memcached_session_client.html) the session client for memcached.

    module.exports = {
      Resource:                require('./resource')
      ResourceService:         require('./resource_service')
      Bam:                     require('./bam')
      MemcachedSessionClient:  require('./memcached_session_client')
    }

## Contributors

* Graham Jenson
* David Mitchell
* Wayne Hoover

## Changelog

2015-12-16 - Updating errors to Hoodoo Specification - Graham
2015-12-3  - Open Sourced                            - Graham & Wayne
