Q = require 'q'
Ack = require '../lib/ack'

describe 'Ack', ->
    exchange = msg = info = headers = ack = _ack = undefined
    beforeEach ->
        exchange = { publish: stub().returns Q() }
        msg = { name: 'panda' }
        headers = {}
        info = { contentType: 'application/json' }
        _ack = { acknowledge: spy() }
        ack = new Ack Q(exchange), msg, headers, info, _ack
        
    describe '._mkopts()', ->
        
        it 'should copy relevant headers from deliveryInfo', ->
            opts = ack._mkopts {}, {
                contentType: 'text/panda',
                contentEncoding: 'us-ascii',
                myHeader: 'myValue' }
            opts.should.have.property 'contentType', 'text/panda'
            opts.should.have.property 'contentEncoding', 'us-ascii'
            opts.should.not.have.property 'myHeader'

        it 'should copy existing headers, and add a retryCount', ->
            opts = ack._mkopts { panda: 'cub' }, {}, 23
            opts.should.have.property 'headers'
            opts.headers.should.eql
                panda: 'cub'
                retryCount: 23

        it 'should set the retryCount even if there are no existing headers', ->
            opts = ack._mkopts undefined, {}, 23
            opts.should.have.property 'headers'
            opts.headers.should.eql
                retryCount: 23

    
    describe '._msgbody()', ->

        it 'should return the msg if this it a plain javascript object', ->
            msg = { name: 'panda' }
            ack._msgbody(msg, 'application/json').should.eql msg
        
        it 'should return the data part if it exists and is a Buffer', ->
            body = new Buffer('panda')
            msg =
                data: body
                contentType: 'application/octet-stream'
            ack._msgbody(msg, 'application/octet-stream').should.eql body

    describe '.retry()', ->

        it 'should queue the message for retry if allowed by retry count', ->
            ack.retry().then ->
                exchange.publish.should.have.been.calledWith 'retry', msg, { contentType: 'application/json', headers: retryCount: 1 }
                _ack.acknowledge.should.have.been.calledOnce

        it 'should queue the message as a failure if we have reached max number of retries', ->
            headers.retryCount = 3
            ack.retry().then ->
                exchange.publish.should.have.been.calledWith 'fail', msg, { contentType: 'application/json', headers: retryCount: 4 }
                _ack.acknowledge.should.have.been.calledOnce

    describe '.fail()', ->

        it 'should queue the message as a failure', ->
            msg.should.eql { name: 'panda' }
            ack.fail().then ->
                exchange.publish.should.have.been.calledWith 'fail', msg, { contentType: 'application/json', headers: { retryCount: 0 } }
                _ack.acknowledge.should.have.been.calledOnce