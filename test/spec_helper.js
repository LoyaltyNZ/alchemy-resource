process.env.NODE_ENV = 'test';

// Require test packages
const chai = require('chai');

global._ = require('lodash');

// Require packages
global.bb = require('bluebird');
bb.config({ longStackTraces: true });
bb.onPossiblyUnhandledRejection(() => {});
bb.onUnhandledRejectionHandled(() => {});

global.msgpack = require('msgpack');

global.expect = chai.expect;
global.assert = chai.assert;

// Local files
global.Service = require('../src/alchemy-resource');

AlchemyResource = require("../src/alchemy-resource")

global.Service = require('alchemy-ether')
global.Resource = AlchemyResource.Resource
global.ResourceService = AlchemyResource.ResourceService
global.MemcachedSessionClient = AlchemyResource.MemcachedSessionClient

global.random_name = function(prefix) {
    return `${prefix}_${_.random(0, 99999999)}`;
};

global.random_resource = function() {
    return random_name("resource");
};

global.random_service = function() {
    return random_name("random_service");
};