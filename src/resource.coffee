# # Resource

# ## Imports
# * `bluebird` is the promises library
# * `lodash` is used as a general purpose utility library
# * `Bam` is the error library used to generate errors if a method is not implemented
bb = require "bluebird"
_ = require('lodash')
Bam = require('./bam')

# ## Resource
# Resource is the class to override to implement a resource to be deployed
# Each resource has:
# 1. `name` of the resource used for logging and authentication
# 2. `path` of the resource used for service discovery and routing
# 3. `show`, `create`, `update` and `delete` methods, meant to be overridden by the resource implementations.
# 4. `start` and `stop` lifecycle methods  to control its connections
class Resource

  # #### Routing and Paths
  #
  # [RabbitMQ topic exchanges](https://www.rabbitmq.com/tutorials/tutorial-five-javascript.html)
  # route a message using a **routing key** to queues bound with a **binding key**.
  # Alchemy Resource binds resources to the topic exchange `resources.exchange`
  # and converts URL paths into routing keys
  # to route messages to the right resources without knowing their specific location or queue.
  #
  # For example, the **users* resource has the path of `/v1/users`.
  # By binding this resource to the `resources.exchange` with the `binding_key` `v1.users.#`
  # (the `.#` means zero-to-many additional words),
  # messages with paths `/v1/users` and `/v1/users/1`,
  # and routing keys `v1.users` and `v1.users.1` respectively,
  # would be routed to the users resource.
  #
  # Note: path conflicts will occur if you have resource that has a parent path of another.
  # For example, if two resources had paths `/v1/users` and `/v1/users/registered`
  # messages sent to `/v1/users/registered` will be send to **both** resources,
  # unless the resources are in the same service then it will make it to only one.
  # So, don't have resources that have parent paths.

  # `path_to_routing_key` is the class method that takes a `path` and converts it into a RabbitMQ routing key.
  # The path is converted to a routing key by:
  # 1. converting all `'/'` characters to `'.'` except the first and last characters
  # 2. adding all non `'/'` characters
  #
  # For Example, `path_to_routing_key('/v1/users')` return `'v1.users'`.
  @path_to_routing_key = (path) ->
    new_path = ""
    for c,i in path
      if c == '/' and i != 0 and i != path.length-1
        new_path += '.'
      else if c != '/'
        new_path += c
    new_path

  # `matches_path` checks to see if a `path` should be routed to this resource.
  #
  # It first normalises the incoming path
  # and check to see if it starts with the same string as the resources path.
  matches_path: (path) ->
    path = path.replace(/(^\/)|(\/$)/g, "") # normalise path by remove trailing and leading /
    return _.startsWith(path, @path)

  # `constructor(name, path)` takes a `name` string and a url `path`.
  # The `path` is normalised to make string matching easier,
  # then a `binding_key` is created by using `path_to_routing_key` and adding the wild card `.#`
  constructor: (@name, @path) ->
    @path = @path.replace(/(^\/)|(\/$)/g, "") # normalise path by remove trailing and leading /
    @binding_key = "#{Resource.path_to_routing_key(@path)}.#"

  # #### Life Cycle
  #
  # Allowing a resource to override `start` and `stop` methods lets a resource:
  # * raise errors if required services (e.g. databases) are not available
  # * connect to services before being asked to process messages
  # * clean up connections when being asked to stop

  # `start` returns and empty promise by default
  start: () ->
    bb.try( -> )

  # `stop` returns and empty promise by default
  stop: () ->
    bb.try( -> )

  # #### Resource Methods
  #
  # A resource implementation can override these methods to implement its processing functions

  # `show` method will be called on a `GET`
  show: (context) ->
    throw Bam.method_not_allowed()

  # `create` method will be called on a `POST`
  create: (context) ->
    throw Bam.method_not_allowed()

  # `update` method will be called on a `PATCH`
  update: (context) ->
    throw Bam.method_not_allowed()

  # `delete` method will be called on a `DELETE`
  delete: (context) ->
    throw Bam.method_not_allowed()


module.exports = Resource
