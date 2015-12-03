
process.env.NODE_ENV = 'test'

#Require test packages
chai = require 'chai'

global._ = require 'lodash'

#require packages
global.bb = require 'bluebird'
bb.longStackTraces()

bb.onUnhandledRejectionHandled( -> )
bb.onPossiblyUnhandledRejection( -> )

global.expect = chai.expect;
global.assert = chai.assert;

#local files
AlchemyResource = require("../src/alchemy-resource")

global.Service = require('alchemy-ether')
global.Resource = AlchemyResource.Resource
global.ResourceService = AlchemyResource.ResourceService
global.MemcachedSessionClient = AlchemyResource.MemcachedSessionClient


global.random_name = (prefix) ->
  "#{prefix}_#{_.random(0, 99999999)}"

global.random_resource = ->
  random_name("resource")

global.random_service = ->
  random_name("random_service")
