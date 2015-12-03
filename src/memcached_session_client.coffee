# # Memcached Session Client

# ## Imports
# * `bluebird` is the promises library
# * `lodash` is used as a general purpose utility library
# * `memcached` is used to communicate with memcached
bb = require "bluebird"
_ = require 'lodash'
Memcached = require('memcached')

# ## Memcached Session Client
# This class is used to store session and caller keys in memcached for use in authentication.
class MemcachedSessionClient

  # `constructor(options)`
  # The keys for the `options` are:
  # 1. `memcached_uri`: the location of the memcached host
  # 2. `memcached_retries`: the number of retries to attempt if writing or reading fails
  # 3. `memcached_session_namespace`: the prefixed namespace added to session keys
  # 4. `memcached_caller_namespace`:  the prefixed namespace added to caller keys
  # 5. `memcached_ttl`: the length of time that a key will exist in memcached
  #
  constructor: (@options = {}) ->
    @options = _.defaults(
      @options,
      {
        memcached_uri: 'localhost:11211'
        memcached_retries: 2
        memcached_session_namespace: ''
        memcached_caller_namespace: ''
        memcached_ttl: 86400 # 24 hours for session to time out
      }
    )

  # `connect` created the memcached client and attempts to connect to the memcached host.
  # It returns a promise that it has connected successfully.
  connect: () =>
    @_memcached = new Memcached(@options.memcached_uri, {
      retries: @options.memcached_retries,
      timeout: 200,
      remove: true,
      failures:2
    })

    @_memcached = bb.promisifyAll(@_memcached)

    @_memcached.statsAsync()
    .then( (data) =>
      @
    )
    .catch( ->
      throw "Error Connecting to Memcached"
    )

  # `disconnect` deleted the connection to memcached and returns promise to disconnect
  disconnect: =>
    delete @['_memcached']
    bb.try( -> )

  # `get_session` returns a promise for the session from memcached using the `session_id`
  get_session: (session_id) =>
    @_memcached.getAsync("#{@options.memcached_session_namespace}#{session_id}")
    .then( (data) ->
      return null unless data?
      try
        return JSON.parse(data)
      catch e
        throw "Session is Corrupt (#{e})"
    )

  # `get_caller` returns a promise for the caller from memcached using the `caller_id`
  get_caller: (caller_id) =>
    @_memcached.getAsync("#{@options.memcached_caller_namespace}#{caller_id}")
    .then( (data) ->
      return null unless data?
      try
        return JSON.parse(data)
      catch e
        throw "Session is Corrupt (#{e})"
    )

  # `set_session` returns a promise to set the session to the session_id in memcached
  set_session: (session_id, session = {}) ->
    @_memcached.setAsync("#{@options.memcached_session_namespace}#{session_id}", JSON.stringify(session), @options.memcached_ttl)

  # `set_caller` returns a promise to set the caller to the caller_id in memcached
  set_caller: (caller_id, caller = {}) ->
    @_memcached.setAsync("#{@options.memcached_caller_namespace}#{caller_id}", JSON.stringify(caller), @options.memcached_ttl)


module.exports = MemcachedSessionClient