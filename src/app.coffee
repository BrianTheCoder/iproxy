# Module dependencies.
# test url: https://d2pnn7clgn6qxc.cloudfront.net/bullet/02-mj-sl-13-vp-blk-blk-square/product_medium.jpg
# command: curl "http://127.0.0.1:5555?urls%5B%5D=https://d2pnn7clgn6qxc.cloudfront.net/bullet/02-mj-sl-13-vp-blk-blk-square/product_medium.jpg"

express = require 'express'
http = require 'http'
Memcached = require 'memcached'
crypto = require 'crypto'
request = require 'request'
_ = require 'underscore'

app = express()

memcached = new Memcached process.env.CACHE_SERVER || '127.0.0.1:11211',
  namespace: 'dstld:proxy'
  compressionThreshold: 10

# all environments
app.set 'port', process.env.PORT || 5555
app.use express.logger('dev')
app.use express.json()
app.use express.urlencoded()
app.use express.methodOverride()
app.use app.router

# development only
if 'development' == app.get('env')
  app.use express.errorHandler()

app.get '/', (req, res)->
  urls = req.query.urls
  map = {}
  urls.forEach (url)->
    shasum = crypto.createHash 'sha1'
    shasum.update url
    map[shasum.digest('hex')] = url

  done = (data)->
    if _.isEqual(_.keys(data), _.keys(map))
      res.json data

  memcached.getMulti _.keys(map), (err, data)->
    _.each map, (url, digest)->
      if !data[digest]
        request
          uri: url
          encoding: null
        , (err, resp, body)->
          dataUri = body.toString('base64')
          memcached.set digest, dataUri, 10000, (err, result)->
            if err then console.error err
          data[digest] = dataUri
          done(data)
      else
        done(data)

http.createServer(app).listen app.get('port'), ->
  console.log "Express server listening on port #{app.get('port')}"