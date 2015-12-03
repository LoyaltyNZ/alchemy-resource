create_session_client = (options = {}) ->
  new MemcachedSessionClient(options)

describe 'MemcachedSessionClient', ->

  describe '#constructor', ->
    it 'should work', ->
      session_client = new MemcachedSessionClient()

    it 'should set the memcached host', ->
      session_client = new MemcachedSessionClient(memcached_uri: "blabla")
      expect(session_client.options.memcached_uri).to.equal("blabla")

  describe '#connect', ->
    it 'should correctly connect', ->
      session_client = create_session_client()
      session_client.connect()
      .finally( ->
        session_client.disconnect()
      )

  describe '#disconnect', ->
    it 'should remove memcached from session_clientance', ->
      session_client = create_session_client()
      session_client.connect()
      .then( ->
        expect(!!session_client._memcached).to.be.true
        session_client.disconnect()
      )
      .then( ->
        expect(!!session_client._memcached).to.be.false
      )

  describe '#get_session', ->
    it 'should return null for non session information', ->
      session_client = create_session_client()
      session_client.connect()
      .then( ->
        session_client.get_session("non_existant_session")
      )
      .then((session) ->
        expect(session).to.be.null
      )
      .finally( ->
        session_client.disconnect()
      )

    it 'should return stored session data', ->
      session_client = create_session_client()
      session_client.connect()
      .then( ->
        session_client.set_session("session_id", {hello: "world"})
      )
      .then( ->
        session_client.get_session("session_id")
      )
      .then((session) ->
        expect(session.hello).to.equal("world")
      )
      .finally( ->
        session_client.disconnect()
      )

  describe '#set_session', ->
    it 'should memcached_ttl out', ->
      session_client = create_session_client(memcached_ttl: 1)
      session_client.connect()
      .then( ->
        session_client.set_session("ttl_out", {hi: "world"})
      )
      .then( ->
        session_client.get_session("ttl_out")
      )
      .then((session) ->
        expect(session.hi).to.equal("world")
      )
      .delay(1500) #have to wait for 1.5seconds for message to ttl
      .then( ->
        session_client.get_session("ttl_out")
      )
      .then( (session)  ->
        expect(session).to.equal(null)
      )
      .finally( ->
        session_client.disconnect()
      )