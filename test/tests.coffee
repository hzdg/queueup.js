describe 'the master queue', ->

  it 'should load a PNG', (done) ->
    queueup
      .load('hzlogo.png')
      .then(-> done())
      .start()
