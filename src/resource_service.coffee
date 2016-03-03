# # Resource Service
#
# ResourceService is an Alchemy Service to provides a place for many Resources to receive messages.

# ## Imports
# * `bluebird` is the promises library
# * `lodash` is used as a general purpose utility library
# * `Service` is used to communicate over the queue to handle messages
# * `Bam` is the error library used to generate errors if a method is not implemented
# * `MemcachedSessionClient` is used to handle sessions in memcached
# * `Resource` has useful methods to the resource service
bb = require "bluebird"
_ = require('lodash')
Service = require("alchemy-ether")
Bam = require('./bam')
MemcachedSessionClient = require('./memcached_session_client')
Resource = require ('./resource')

# ## Logging Functions

# `log(uuid, message)` writes consistent log messages to stdout
_log = (uuid, message) ->
  console.log "#{(new Date()).toISOString()} - ResourceService #{uuid} - #{message}"

# `_log_error(uuid, message, error)` writes consistent error messages to stderr
_log_error = (uuid, message, error = {stack: ''}) ->
  console.error "#{(new Date()).toISOString()} - ResourceService #{uuid} - #{message} - #{error.stack}"


# ## ResourceService
class ResourceService

  # `constructor(service_name, resource_list, options)` takes a name for the service,
  # a list of resources, and an object of options including:
  # * `logging_endpoint` the service queue name for logging
  # * `session_client` the resource requires a session client
  # * `memcached_uri` the uri of the memchaced host
  # * `memcached_session_namespace` the prefix for the session key in memcached
  # * `memcached_caller_namespace` the prefix for the caller key in memcached
  # * `amqp_uri` the uri for the RabbitMQ host
  # * `service_timeout` the timeout set for the resource service
  # * `service_queue` and `response_queue` options are passed to the internal alchemy-ether service
  #
  # The constructor:
  # 1. applies the defaults to the `@options` object.
  # 2. separates the resource list into a lookup object `@resources`
  # 3. builds the `@session_client` from the `@options`
  # 4. creates the Alchemy Ether service and sets `@_resource_service_fn` as the function to process messages.
  constructor: (@service_name, @resource_list = [], @options = {}) ->
    @options = _.defaults(
      @options,
      {
        logging_endpoint: 'platform.logging'
        session_client: true
        memcached_uri: 'localhost:11211'
        memcached_session_namespace: ''
        memcached_caller_namespace: ''
        amqp_uri: 'amqp://localhost'
        service_timeout: 1000
        service_queue: true
        response_queue: true
      }
    )

    @resources = {}
    resource_paths = []
    for r in @resource_list
      @resources[r.name] = r
      resource_paths.push r.path

    @session_client = new MemcachedSessionClient(@options) if @options.session_client

    @service = new Service(@service_name, {
      service_queue: @options.service_queue
      response_queue: @options.response_queue
      amqp_uri: @options.amqp_uri
      timeout: @options.service_timeout
      resource_paths: resource_paths
    }, @_resource_service_fn)

  # #### Session Client Methods
  # To make it easier to use the Resource Service some methods are wrapped

  set_session: (session_id, session) ->
    @session_client.set_session(session_id, session)

  get_session: (session_id) ->
    @session_client.get_session(session_id)

  set_caller: (caller_id, caller) ->
    @session_client.set_caller(caller_id, caller)

  get_caller: (caller_id) ->
    @session_client.get_caller(caller_id)

  # #### Life Cycle

  # `start`:
  # * starts all the resources,
  # * then connects the `session_client`,
  # * then starts the service connecting to RabbitMQ,
  # * then binds the resources to the `resources.exchange` to start receiving messages,
  # * then logs that the resource service has started
  start: ->
    bb.all(@resource_list.map( (resource) -> resource.start()))
    .then( =>
      @session_client.connect() if @session_client
    )
    .then ( =>
      @service.start()
    )
    .then( =>
      _log @service_name, "Started with #{JSON.stringify(@options)}"
    )

  # `stop`:
  # * stops the service to stop receiving messages (this will finish processing current messages),
  # * then disconnects the `session_client`,
  # * then stops all the resources disconnecting,
  # * then logs that the resource service has stopped
  stop: ->
    @service.stop()
    .then( =>
      @session_client.disconnect() if @session_client
    )
    .then( =>
      bb.all(@resource_list.map( (resource) -> resource.stop()))
    )
    .then( =>
      _log @service_name, "Stopped"
    )



  # #### Send Message


  add_interaction_id: (payload) ->
    payload.headers = {} if !payload.headers

    if !payload.headers['x-interaction-id']
      payload.headers['x-interaction-id'] = Service.generateUUID()

  # `send_message_to_service` wraps the method from alchemy-ether service for convenience
  send_message_to_service: (service, payload) ->
    @add_interaction_id(payload)
    @service.send_message_to_service( service, payload)

  # `send_request_to_service` wraps the method from alchemy-ether service for convenience
  send_message_to_resource: (payload) ->
    @add_interaction_id(payload)
    @service.send_message_to_resource( payload)

  # `send_request_to_service` wraps the method from alchemy-ether service for convenience
  send_request_to_service: (service, payload) ->
    @add_interaction_id(payload)
    @service.send_request_to_service( service, payload)

  # `send_request_to_service` wraps the method from alchemy-ether service for convenience
  send_request_to_resource: (payload) ->
    @add_interaction_id(payload)
    @service.send_request_to_resource(payload)


  # #### Process Message

  # `_resource_service_fn` receives a message payload from the alchemy-ether service
  # and processes it by first building the calls context with:
  # 1. `_get_resource_name`: finding the resource name
  # 2. `_get_interaction_id`: find the interaction id
  # 3. `_get_action`: get the action (e.g. `show`)
  # 4. `_get_body`: extract and parse the body
  # 5. `_get_query`: get the query
  # 6. `_get_path`: get the path
  #
  # Then it calls `_get_session_and_caller` to extract the session and caller from the session client.
  #
  # `_validate_context` is then used to check that the context is valid.
  #
  # `_is_permitted` is used to check the session/caller has permissions to call the resource
  #
  # `_call_resource_action` is the function that calls the implemented resource function
  #
  # Finally, this method catches all errors and sends them to `_log_error_and_respond`
  # which logs and returns a structured error
  _resource_service_fn: (payload) =>
    context = {
      resource:       @_get_resource_name(payload)
      interaction_id: @_get_interaction_id(payload)
      action:         @_get_action(payload)
      body:           @_get_body(payload)
      query:          @_get_query(payload)
      path:           @_get_path(payload)
    }

    @_get_session_and_caller(payload)
    .then((session_and_caller) =>
      context.session = session_and_caller.session
      context.caller = session_and_caller.caller

      @_validate_context(context)

      throw Bam.not_allowed(context) if not @_is_permitted(context)

      @_call_resource_action(context)
    )
    .catch( (err) =>
      _log_error @service_name, "Platform Error", err
      @_log_error_and_respond(err, context)
    )

  # `_get_resource_name` loops over and finds the resource that matches the path
  _get_resource_name: (payload) ->
    for resource in @resource_list
      return resource.name if resource.matches_path(payload.path)
    null

  # `_get_interaction_id` extracts the interaction_id header
  _get_interaction_id: (payload) ->
    payload.headers['x-interaction-id']

  # `_get_action` matches the HTTP method/verb to the resource action
  _get_action: (payload) ->
    switch payload.verb
      when "POST" then "create"
      when "PATCH" then "update"
      when "DELETE" then "delete"
      when "GET" then 'show'
      else null

  # `_get_body` tries to parse the message body from JSON
  # * if it fails returns null
  # * if no body is found return `{}`
  #
  # *This means that currently only JSON bodies are allowed.*
  _get_body: (payload) ->
    if payload.body
      try
        body = JSON.parse(payload.body) if typeof payload.body == 'string'
        return body
      catch
        return null
    else
      return {}


  # `_get_query` extracts the query
  _get_query: (payload) ->
    payload.query

  # `_get_path` extracts the path
  _get_path: (payload) ->
    payload.path

  # `_get_session_and_caller` uses the wrapped methods from session_client to find the session and caller.
  # * if no session id return
  # * fetch the session, if no session or no caller_id return
  # * fetch the caller, return
  #
  # This is designed to make the minimum amount of calls to memcached
  # while returning as much data as possible
  _get_session_and_caller: (payload) ->
    session_and_caller = {session: null, caller: null}
    session_id = payload.headers['x-session-id']
    return bb.try( => session_and_caller) if not session_id

    @get_session(session_id)
    .then( (session) =>
      session_and_caller.session = session
      return session_and_caller if not session || not session.caller_id

      @get_caller(session.caller_id)
      .then( (caller) ->
        session_and_caller.caller = caller
        session_and_caller
      )
    )


  # `_validate_context` throws errors if the context was not correctly constructed
  _validate_context: (context) ->
    throw Bam.not_found(context, context.path) if not context.resource
    throw Bam.no_interaction_id(context) if not context.interaction_id
    throw Bam.method_not_allowed(context) if not context.action
    throw Bam.malformed_body(context) if not context.body

  # `_is_permitted` checks that the caller is permitted to call the resource action
  #
  # The session and caller look like:
  #
  # ```json
  #       Session           |    Caller
  # {                       |  {
  #  caller_version: 1      |    version: 1
  #  caller_id: 1           |    permissions: {...}
  #  permissions: {         |  }
  #   resources: {          |
  #    "Person": {          |
  #     "show": "allow",    |
  #     "create": "deny",   |
  #     "else": "allow"     |
  #    }                    |
  #   }                     |
  #  }                      |
  # }                       |
  # ```
  #
  # The `permission` key is checked to see if the caller is permitted
  # and either the session or caller may store it.
  # In the above example the session is permitted to call the `Person` resources `show` action,
  # not permitted to call the `create` action,
  # and the `else` key permits the other actions `update` and `delete`.
  #
  # **Authentication**
  # For a caller to be permitted:
  # 1. The resource action has attribute `public` set to true (to allow methods that require no authentication)
  # 2. There must be a session and caller
  # 3. The `session.caller_version` must equal `caller.version` (ensures a session becomes invalid if the caller is updated)
  # 4. There must be explicitly declared permissions for the `context.resource`
  # 5. If the action has explicit permission it must be `allow`
  # 6. If the default `else` permission is `allow`
  _is_permitted: (context) ->
    return true if @resources[context.resource][context.action].public # check 1

    session = context.session
    caller = context.caller

    return false if !session || !caller # check 2

    return false if caller.version != session.caller_version # check 3

    permissions = caller.permissions || session.permissions
    resource_permissions = permissions?.resources[context.resource]
    return false if not resource_permissions # check 4

    action_permissions = resource_permissions[context.action]
    if action_permissions
      if action_permissions == 'allow' # check 5
        return true
      else
        return false

    default_resource_permissions = resource_permissions['else']
    if default_resource_permissions
      if default_resource_permissions == 'allow' # check 6
        return true
      else
        return false

    return false


  # `_call_resource_action` this method calls the resources action, logs the information, and handles resource errors
  #
  # 1. record the start time for the resource action
  # 2. log the 'inbound' request to the resource
  # 3. clone the context to be passed to the resource to stops the resource modifications impacting the resource service
  # 4. wrap the call the the resource in a promise, and call the resources action passing it the context
  # 5. when the resource action returns the response
  #    add the response and response_time to the context, log the `outbound` context and return the response
  # 6. If the service causes an error log the error and respond
  _call_resource_action: (context) ->
    start_time = new Date().getTime()
    @_log_interaction(context, 'inbound')

    resource_context = _.cloneDeep(context)
    bb.try( => @resources[context.resource][context.action](resource_context))
    .then( (resource_response) =>

      context.response = resource_response
      context.response_time = (new Date().getTime()) - start_time

      @_log_interaction(context, 'outbound')

      resource_response
    )
    .catch( (err) =>
      _log_error(@service_name, "Service Error", err)
      @_log_error_and_respond(err, context)
    )

  # `_log_error_and_respond` takes an error and the context that created it and generates the correct response body
  #
  # First it convert the error to a Bam error if it is not already one.
  # Then it assigns the error to the context.
  # Then by assigning the reference of the error as the id of the context,
  # both the caller and the log will have the same reference to identify the problem.
  # Finally, the context is logged as an `outbound` `error` and the Bam error is returned to the caller.
  _log_error_and_respond: (err, context) ->
    err = Bam.error(context, err) if not err.bam

    context.errors = err
    context.id = err.body.reference
    @_log_interaction(context, 'outbound', 'error')
    return err

  # `_log_interaction` constructs a log event message and from a context, code and level
  # and sends it to the logging endpoint queue
  _log_interaction: (context, code, level) ->
    logging_event = {
      id:                   context.id || Service.generateUUID()
      interaction_id:       context.interaction_id
      level:                level || context.level || 'info'
      component:            context.resource
      code:                 code || context.code
      reported_at:          (new Date()).toISOString()
      data:                 context
      caller_identity_name: context.caller_identity_name
      caller_id:            context.caller_id
      resource:             context.resource
      action:               context.action
    }

    @send_message_to_service(@options.logging_endpoint, {body: JSON.stringify(logging_event)})


# ## Errors
# Include the errors on alchemy-ether Service onto the ResourceService
# Further information available [here](http://loyaltynz.github.io/alchemy-ether/docs/src/service.html)
ResourceService.NAckError = Service.NAckError
ResourceService.MessageNotDeliveredError = Service.MessageNotDeliveredError
ResourceService.TimeoutError = Service.TimeoutError

module.exports = ResourceService
