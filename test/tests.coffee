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
