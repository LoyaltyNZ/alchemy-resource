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
    throw Bam.method_not_allowed(context)

  # `create` method will be called on a `POST`
  create: (context) ->
    throw Bam.method_not_allowed(context)

  # `update` method will be called on a `PATCH`
  update: (context) ->
    throw Bam.method_not_allowed(context)

  # `delete` method will be called on a `DELETE`
  delete: (context) ->
    throw Bam.method_not_allowed(context)


module.exports = Resource
