module.exports = (grunt) ->

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
    mocha:
      all:
        src: ['test/**/*.html', '!test/assets/**'],
        options:
          run: true
          log: true
          reporter: 'Spec'
    watch:
      options:
        atBegin: true
      coffee:
        files: ['queueup.litcoffee', 'test/tests.coffee']
        tasks: ['coffee']


  # Load grunt plugins
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-mocha'

  # Define tasks.
  grunt.registerTask 'build', ['coffee']
  grunt.registerTask 'default', ['build']
  grunt.registerTask 'test', ['mocha']
