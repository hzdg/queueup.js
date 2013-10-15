assert = chai.assert


t = new Date().getTime()
count = 0
cb = (name) -> "#{ name }?#{ t }-#{ count += 1 }"


describe 'the module', ->
  it 'should be a load queue factory', ->
    assert.instanceOf queueup(), queueup.LoadQueue
  it 'should have a reference to the LoadQueue constructor', ->
    assert typeof queueup.LoadQueue is 'function'
  it 'should create a queue when called', ->
    queueup().constructor is queueup.LoadQueue
  it 'should create unique instances', ->
    assert.notEqual queueup(), queueup()


describe 'a LoadResult', ->
  loadResult = queueup()
    .load(cb 'assets/1.png')

  it 'should be a promise', ->
    assert.typeOf loadResult.then, 'function'
  it 'should expose the LoadQueue API', ->
    assert.typeOf loadResult.start, 'function'
  it 'should be chainable', ->
    assert.equal loadResult, loadResult.then $.noop


describe 'a queue', ->
  it 'should load a PNG', (done) ->
    queueup()
      .load(cb 'assets/1.png')
        .then(-> done())
      .start()

  it 'should error for nonexistent assets', (done) ->
    queueup()
      .load(cb 'assets/DOES-NOT-EXIST.jpg')
      .done ->
        done new Error 'Promise was resolved'
      .fail ->
        done()
      .start()

  it 'should load HTML', (done) ->
    queueup()
      .load(cb 'assets/1.html')
        .then(-> done())
      .start()

  it 'should load in the correct order', (done) ->
    complete = {}
    queueup(simultaneous: 1)
      .load(cb 'assets/1.png')
        .then ->
          if complete.asset2
            done new Error 'Second asset loaded first.'
          complete.asset1 = true
      .load(cb 'assets/2.png')
        .then ->
          unless complete.asset1
            done new Error 'First asset not loaded.'
          done()
      .start()

  it 'should be able to promote assets', (done) ->
    complete = {}
    queueup(simultaneous: 1)
      .load(cb 'assets/1.png')
        .then ->
          complete.asset1 = true
      .load(cb 'assets/2.png')
        .then ->
          if complete.asset1
            done new Error "Promoted asset didn't load first"
          done()
        .promote()
      .start()

  it 'should autostart', (done) ->
    queueup(autostart: true)
      .load(cb 'assets/1.png')
        .then(-> done())


describe 'a group', ->

  it 'should complete when its assets complete', (done) ->
    complete = {}
    queueup().group()
      .load(cb 'assets/1.png')
        .then(-> complete.asset1 = true)
      .load(cb 'assets/2.png')
        .then(-> complete.asset2 = true)
      .endGroup()
        .then ->
          if complete.asset1 and complete.asset2
            done()
          else
            done new Error 'Group completed before assets.'
      .start()

  it 'should make a new group after endGroup', ->
    g1 = queueup()
      .load(cb 'assets/1.png')
      .endGroup()
    g2 = g1
      .load(cb 'assets/2.png')
      .endGroup()
    g3 = g2
      .group()
        .load(cb 'assets/3.png')
        .endGroup()
    g4 = g3
      .load(cb 'assets/4.png')
      .endGroup()

    checked = []
    for g in [g1, g2, g3, g4]
      assert typeof g.append is 'function'
      assert g not in checked
      checked.push g
    return

  it 'should yield control to its parent', (done) ->
    complete = {}
    queueup(simultaneous: 1)
      .group()
        .load(cb 'assets/1.png')
          .then(-> complete.asset1 = true)
        .load(cb 'assets/2.png')
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
      .group()
        .load(cb 'assets/3.png')
          .then(-> complete.asset3 = true)
        .endGroup()
        .promote()
      .start()
