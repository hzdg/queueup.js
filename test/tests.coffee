assert = chai.assert


t = new Date().getTime()
count = 0
mockLoader = (opts, cb) -> setTimeout cb, 0


describe 'the module', ->
  it 'should have a reference to the LoadQueue constructor', ->
    assert typeof queueup.LoadQueue is 'function'
  it 'should be a load queue factory', ->
    assert.instanceOf queueup(), queueup.LoadQueue
  it 'should create a queue when called', ->
    queueup().constructor is queueup.LoadQueue
  it 'should create unique instances', ->
    assert.notEqual queueup(), queueup()


describe 'a LoadResult', ->
  loadResult = queueup().load 'test'

  it 'should be a promise', ->
    assert.typeOf loadResult.then, 'function'
  it 'should expose the LoadQueue API', ->
    assert.typeOf loadResult.start, 'function'
  it 'should be chainable', ->
    assert.equal loadResult, loadResult.then $.noop
  it 'has a default priority of 0', ->
    assert.equal loadResult.priority(), 0


describe 'a queue', ->
  loadQueue = null
  beforeEach ->
    loadQueue = queueup().registerLoader 'image', mockLoader

  it 'should detect image extensions', ->
    assert.equal loadQueue._getType(test), 'image' for test in [
      {url: 'test.png'}
      {url: 'test.jpg'}
      {url: 'test.jpeg'}
      {url: 'test.gif'}
      {url: 'test.svg'}
      {type: 'image'}
    ]

  it 'should detect html extensions', ->
    assert.equal loadQueue._getType(test), 'html' for test in [
      {url: 'my_file.html'}
      {type: 'html'}
    ]

  it 'should error when extension cannot be matched to a type', ->
    fn = => loadQueue._getType(url: 'something')
    assert.Throw fn, "Couldn't determine type of something"

  it "should error when a loader isn't registered for a type", ->
    fn = => loadQueue._getLoader type: 'fake', url: 'thing.fake'
    assert.Throw fn, 'A loader to handle thing.fake could not be found'

  it 'should use a loader for a given type', ->
    loadQueue.registerLoader 'image', loader = ->
    assert.equal loadQueue._getLoader(url: 'thing.png'), loader

  it 'should handle errors from loaders', (done) -> do (loadQueue) ->
    loadQueue
      .registerLoader('image', (opts, cb) -> cb(new Error 'test'))
      .load 'assets/DOES-NOT-EXIST.jpg'
      .then ->
        done new Error 'Promise was resolved'
      .catch (error) =>
        assert.equal error.message, 'test'
        loadQueue
          .registerLoader('image', (opts, cb) -> throw new Error 'test2')
          .load 'assets/DOES-NOT-EXIST.jpg'
          .then ->
            done new Error 'Promise was resolved'
          .catch (error) ->
            done assert.equal error.message, 'test2'
          .start()
      .start()

  it 'should load in the correct order', (done) ->
    complete = {}
    loadQueue.config simultaneous: 1
    loadQueue
      .load 'assets/1.png'
        .then ->
          if complete.asset2
            done new Error 'Second asset loaded first.'
          complete.asset1 = true
      .load 'assets/2.png'
        .then ->
          unless complete.asset1
            done new Error 'First asset not loaded.'
          done()
      .start()

  it 'should be able to promote assets', (done) ->
    complete = {}
    loadQueue.config simultaneous: 1
    loadQueue
      .load 'assets/1.png'
        .then ->
          complete.asset1 = true
      .load 'assets/2.png'
        .then ->
          if complete.asset1
            done new Error "Promoted asset didn't load first"
          done()
        .promote()
      .start()

  it 'should autostart from load', (done) ->
    loadQueue.config autostart: true
    loadQueue
      .load 'assets/1.png'
        .then -> done()

  it 'should autostart from enqueue', (done) ->
    loadQueue.config autostart: true
    loader = (cb) ->
      loader = loadQueue._getLoader type: 'image'
      loader url: 'assets/1.png', cb
    loadQueue
      .enqueue loader
        .then -> done()

  it 'abides by priority', (done) ->
    complete = {}
    loadQueue.config simultaneous: 1
    loadQueue
      .load 'assets/2.png'
        .then ->
          unless complete.asset1
            done new Error 'First asset not loaded.'
          done()
      .load 'assets/1.png', priority: 1
        .then ->
          if complete.asset2
            done new Error 'Second asset loaded first.'
          complete.asset1 = true
      .start()

describe 'a group', ->
  loadQueue = null

  beforeEach ->
    loadQueue = queueup().registerLoader 'image', mockLoader

  it 'should error when you close the last group', ->
    assert.Throw -> loadQueue.endGroup()

  it 'should complete when its assets complete', (done) ->
    complete = {}
    loadQueue
      .startGroup()
        .load 'assets/1.png'
          .then -> complete.asset1 = true
        .load 'assets/2.png'
          .then -> complete.asset2 = true
      .endGroup()
        .then ->
          if complete.asset1 and complete.asset2
            done()
          else
            done new Error 'Group completed before assets.'
      .start()

  it 'should yield control to its parent', (done) ->
    complete = {}
    loadQueue.config simultaneous: 1
    loadQueue
      .startGroup()
        .load 'assets/1.png'
          .then -> complete.asset1 = true
        .load 'assets/2.png'
          .then ->
            complete.asset2 = true
            unless complete.asset3
              done new Error 'Second asset loaded before promoted group.'
        .endGroup()
          .then ->
            if complete.asset3
              done()
            else
              done new Error 'First group loaded first.'
      .startGroup()
        .load 'assets/3.png'
          .then -> complete.asset3 = true
        .endGroup()
        .promote()
      .start()
