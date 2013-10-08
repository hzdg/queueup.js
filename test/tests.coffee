describe 'the master queue', ->

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
