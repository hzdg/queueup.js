describe 'a suite of tests', ->
  @timeout 5000

  it 'should take less than 500ms', (done) ->
    setTimeout done, 300

  it 'should take less than 500ms as well', (done) ->
    setTimeout done, 200
