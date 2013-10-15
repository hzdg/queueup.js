module.exports = (grunt) ->

  TEST_SERVER_PORT = 4000

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    coffee:
      compile:
        files: [
          expand: true
          src: ['queueup.litcoffee', 'test/tests.coffee']
          ext: '.js'
        ]
    connect:
      # Because we're dealing with asset loading, we need to be running a
      # server for tests. Else, CORS.
      tests:
        options:
          port: TEST_SERVER_PORT
          base: '.'
      browser:
        options:
          port: TEST_SERVER_PORT
          base: '.'
          keepalive: true
    mocha:
      all:
        options:
          run: true
          log: true
          reporter: 'Spec'
          urls: ["http://localhost:#{ TEST_SERVER_PORT }/test/index.html"]
    watch:
      options:
        atBegin: true
      coffee:
        files: ['queueup.litcoffee', 'test/tests.coffee']
        tasks: ['coffee']


  # Load grunt plugins
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-mocha'

  # Define tasks.
  grunt.registerTask 'build', ['coffee']
  grunt.registerTask 'default', ['build']
  grunt.registerTask 'test', ['connect:tests', 'mocha']
