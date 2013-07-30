fs = require 'fs'
url = require 'url'
join = require('path').join
http = require 'http'
mime = require 'mime'
async = require 'async'

server = http.createServer (request, response) ->
  pathname = url.parse(request.url).pathname
  dirname = './'
  path = join dirname, pathname

  fs.stat path, (err, stats) ->
    if err
      response.writeHead 404
      response.write '<h1>404 - Not Found</h1>'
      response.end()
      return

    if stats.isFile()
      type = mime.lookup path

      response.writeHead 200, 'content-type': type
      fs.createReadStream(path).pipe(response)

    if stats.isDirectory()
      fs.readdir path, (err, files) ->
        return console.log 'internal server error?' if err # FIXME

        types = {}

        async.eachLimit files, 10, (file, done) ->
          file = join path, file
          fs.stat file, (err, stats) ->
            return done(err) if err

            types[file] = stats.isDirectory()
            done()
        , ->

          response.writeHead 200, 'content-type: text/html'

          response.write "<h1>Directory #{path}</h1>"
          files.forEach (name) ->
            file = join path, name

            dir = if types[file] then '/' else ''
            response.write "<li><a href=\"/#{file}\">#{name}#{dir}</a></li>"

          response.end()

module.exports = server
