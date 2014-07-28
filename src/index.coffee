fs = require 'fs'
url = require 'url'
join = require('path').join
http = require 'http'
mime = require 'mime'
async = require 'async'

# Ranges request for audio/video seeks
handleRanges = (path, type, stats, request, response) ->
  range = request.headers.range
  size = stats.size
  positions = range.replace('bytes=', '').split('-');
  start = parseInt(positions[0], 10) || 0
  end = parseInt(positions[1], 10)
  if isNaN end then end = size - 1
  chunksize = end - start + 1

  response.writeHead 206,
    'Accept-Ranges': 'bytes'
    'Content-Length': chunksize
    'Content-Type': type
    'Content-Range': 'bytes ' + start + '-' + end + '/' + size

  fs.createReadStream(path,
    start: start
    end: end
  ).pipe(response)

handleFile = (path, stats, request, response) ->
  type = mime.lookup path

  if request.headers.range
    handleRanges path, type, stats, request, response
    return

  response.writeHead 200, 'content-type': type
  fs.createReadStream(path).pipe(response)

server = http.createServer (request, response) ->
  pathname = decodeURIComponent(url.parse(request.url).pathname)
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
      handleFile path, stats, request, response

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
