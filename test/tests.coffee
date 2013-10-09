assert = chai.assert


describe 'the master queue', ->

describe 'a queue', ->
  it 'should load a PNG', (done) ->
    queueup
      .load('hzlogo.png')
      .then(-> done())
      .start()

  it 'should load HTML', (done) ->
    queueup()
      .load('assets/1.html')
        .then(-> done())
      .start()

  it 'should be able to promote assets', (done) ->
    queueup()
      .load('assets/1.png')
        .then(-> done new Error 'First asset loaded first.')
      .load('assets/2.png')
        .then(-> done())
        .promote()
      .start()

  it 'should autostart', (done) ->
    queueup(autostart: true)
      .load('assets/1.png')
        .then(-> done())


describe 'a group', ->

  it 'should yield control to its parent', (done) ->
    complete = {}
    queueup()
      .group()
        .load('assets/1.png')
          .then(-> complete.asset1 = true)
        .load('assets/2.png')
          .then ->
            complete.asset2 = true
            unless complete.asset3
              done new Error 'Second asset loaded before promoted group.'
        .endGroup()
          .then ->
            done new Error 'First group loaded first.' unless complete.asset3
            done()
      .start()
      .group()
        .load('assets/3.png')
          .then(-> complete.asset3 = true)
        .endGroup()
        .promote()
