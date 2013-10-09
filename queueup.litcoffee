
    EXT_RE = /\.([^.]+?)(\?.*)?$/

    counter = 0

    extend = (target, sources...) ->
      for source in sources by -1
        for own k, v of source
          target[k] = v
      target

    loadImage = (item) ->
      img = new Image
      img.onload = ->
        if ('naturalWidth' of this and (@naturalWidth + @naturalHeight == 0)) or (@width + @height == 0)
          item.deferred.reject()
        else
          item.deferred.resolve img
      img.onerror = -> item.deferred.reject()
      img.src = item.url
      null

    loadHtml = (item) ->
      xhr = new XMLHttpRequest
      xhr.onreadystatechange = ->
        if xhr.readyState == 4
          if xhr.status == 200
            item.deferred.resolve xhr.responseText
          else
            item.deferred.reject xhr.status
      xhr.open 'GET', item.url, true
      xhr.send()
      null

    boundFns = (obj) ->
      result = {}
      for k, v of obj
        if typeof v is 'function' and k[0] != '_'
          result[k] = (args...) -> v.apply obj, args
      result

    extendPromise = (oldPromise, sources...) ->
      promise = extend oldPromise, sources...
      for fn in ['then', 'done', 'fail']
        do ->
          oldFn = oldPromise[fn]
          promise[fn] = (args...) ->
            extendPromise oldFn.apply(this, args), sources...
      promise

    Deferred = (opts) ->
      factory = opts.factory
      loadQueue = opts.loadQueue
      assetId = opts.assetId

      deferred = factory()
      oldPromise = deferred.promise
      extend deferred,
        promise: -> @_promise ?= extendPromise oldPromise.call(this), boundFns(loadQueue),
          promote: -> loadQueue._promote assetId
          cancel: -> loadQueue._cancel assetId


The LoadQueue is the workhorse for queueup. It's the object responsible for
managing the timing of the loading of assets.

    class LoadQueue
      defaultOptions:
        Deferred: $?.Deferred
        autostart: false
        simultaneous: 6  # The maximum number of items to load at once
        loaders:
          image: loadImage
          html: loadHtml
        extensions:
          image: ['png', 'jpg', 'jpeg', 'gif']
          html: ['html']

      constructor: (opts) ->
        @queue = []
        @loading = []
        @config opts

      config: (opts) ->
        unless @options
          @options ?= {}
          for own k, v of @defaultOptions
            @options[k] = v
        for own k, v of opts
          @options[k] = v
        this

      # Remove an asset from the queue and return it.
      _remove: (assetId) ->
        for asset, i in @queue
          if asset.assetId is assetId
            return @queue.splice(i, 1)[0]

      _promote: (assetId) ->
        if item = @_remove assetId
          @queue.unshift item
        this

      _cancel: (assetId) ->
        !!@_remove(assetId)

      _loadNext: ->
        return unless @loading.length < @options.simultaneous
        if next = @queue.shift()
          @_loadNow next
          @_loadNext()  # Keep calling recursively until we're loading the max we can.

      _loadNow: (item) ->
        @loading.push item
        loader = @getLoader item
        loader item

      getType: (item) ->
        return item.type if item?.type?
        ext = item.url?.match(EXT_RE)?[1].toLowerCase()
        for k, v of @options.extensions
          return k if ext in v

      getLoader: (item) -> @options.loaders[@getType item]

      _add: (method, urlOrOpts, opts) ->
        item =
          if typeof urlOrOpts is 'object'
            extend {}, urlOrOpts
          else
            extend {}, opts, url: urlOrOpts
        item.assetId = counter += 1
        @queue[method](item)
        item.deferred = Deferred
          assetId: item.assetId
          loadQueue: this
          factory: @options.Deferred
        @_loadNext() if @options.autostart
        item.deferred.promise()

      load: (args...) -> @append args...

      append: (urlOrOpts, opts) -> @_add 'push', urlOrOpts, opts

      prepend: (url, opts) -> @_add 'unshift', urlOrOpts, opts

      start: ->
        @_loadNext()
        this


The queueup module itself is the master load queue.


    @queueup = new LoadQueue
    @queueup.LoadQueue = LoadQueue
