module.exports = (grunt) ->
  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json')

    coffee: {
      compileJoined: {
        options: {
          join: true
          bare: true
        }

        files: {
          'app.js': ['src/aaa.coffee', 'src/*.coffee', 'src/zapp.coffee']
        }
      }
    }

    'sftp-deploy': {
      app: {
        auth: {
          host: 'spaeti.pavo.uberspace.de',
          authKey: 'key1'
        },
        src: './app.js',
        dest: '/home/spaeti/node/kings'
      }

      all: {
        auth: {
          host: 'spaeti.pavo.uberspace.de',
          authKey: 'key1'
        },
        src: './',
        dest: '/home/spaeti/node/kings'
        exclusions: ['*.log', '.DS_Store', '.ftppass', 'node_modules', '.git']
      }
    }

    notify: {
      deploy: {
        options: {
          message: 'Deployed to Server!'
        }
      }
    }
  })

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-sftp-deploy'
  grunt.loadNpmTasks 'grunt-notify'

  grunt.registerTask('default', ['coffee'])
  grunt.registerTask('deploy', ['coffee', 'sftp-deploy:app', 'notify:deploy'])
  grunt.registerTask('deploy-all', ['coffee', 'sftp-deploy:all', 'notify:deploy'])
