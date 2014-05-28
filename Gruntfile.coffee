module.exports = (grunt) ->

  TEST_SERVER_PORT = 4000

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'
    coffee:
      compile:
        files: [
            expand: true
            cwd: 'src'
            src: '**/*.?(lit)coffee'
            dest: 'lib'
            ext: '.js'
          ,
            expand: true
            cwd: 'test'
            src: '**/*.?(lit)coffee'
            dest: 'test'
            ext: '.js'
        ]
    browserify:
      options:
        bundleOptions:
          standalone: 'queueup'
      standalone:
        files:
          'standalone/queueup.js': ['lib/queueup.js']
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
          mocha:
            grep: grunt.option 'grep'
    watch:
      options:
        atBegin: true
      coffee:
        files: ['src/**/*.?(lit)coffee', 'test/**/*.?(lit)coffee']
        tasks: ['coffee']
    bump:
      options:
        files: ['package.json', 'bower.json']
        commit: true
        commitFiles: ['-a']
        createTag: true
        push: false

  # Load grunt plugins
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-mocha'
  grunt.loadNpmTasks 'grunt-bump'
  grunt.loadNpmTasks 'grunt-browserify'

  # Define tasks.
  grunt.registerTask 'build', ['coffee', 'browserify']
  grunt.registerTask 'default', ['build']
  grunt.registerTask 'test', ['connect:tests', 'mocha']
  grunt.registerTask 'version:patch', ['build', 'bump:patch']
  grunt.registerTask 'version:minor', ['build', 'bump:minor']
  grunt.registerTask 'version:major', ['build', 'bump:major']
