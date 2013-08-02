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

  respond = (body) ->
    response.write """<!doctype html>
    <head>
      <meta name="viewport" content="initial-scale=1.0,maximum-scale=1.0"/>
      <meta charset="utf-8"/>
    </head>
    <body>#{body}</body>"""

  fs.stat path, (err, stats) ->
    if err
      response.writeHead 404
      respond '<h1>404 - Not Found</h1>'
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

          body = "<h1>Directory #{path}</h1>"
          files.forEach (name) ->
            file = join path, name

            dir = if types[file] then '/' else ''
            body += "<li><a href=\"/#{file}\">#{name}#{dir}</a></li>"

          respond body
          response.end()

module.exports = server
