
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
          item.reject()
        else
          item.resolve img
      img.onerror = item.reject
      img.src = item.url
      null

    loadHtml = (item) ->
      xhr = new XMLHttpRequest
      xhr.onreadystatechange = ->
        if xhr.readyState == 4
          if xhr.status == 200
            item.resolve xhr.responseText
          else
            item.reject xhr.status
      xhr.open 'GET', item.url, true
      xhr.send()
      null

    boundFns = (obj) ->
      result = {}
      for k, v of obj
        if typeof v is 'function' and k[0] != '_'
          do (v) ->
            result[k] = (args...) -> v.apply obj, args
      result

The LoadResult is the result of calling `load()`. It implements a promise API.

    class LoadResult
      constructor: (@loadQueue, promise, @item) ->
        extend this, boundFns(loadQueue)
        for fn in ['then', 'fail', 'done']
          do (fn) =>
            @[fn] = (args...) ->
              promise[fn] args...
              this
      promote: -> @loadQueue._promote @item
      cancel: ->

A Group is a type of LoadResult.

    class Group extends LoadResult
      constructor: (loadResults, loadQueue, promise, resolve, reject) ->
        super loadQueue, promise
        @group = loadResults
        $.when(@group...)
          .done(resolve)
          .fail(reject)


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

      _promote: (item) ->
        if (index = @queue.indexOf item) != -1
          @queue.splice index, 1
          @queue.unshift item
        else
          raise Error 'Item not in queue'
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
        throw new Error "Couldn't determine type of #{ item.url }"

      getLoader: (item) -> @options.loaders[@getType item]

      _add: (method, urlOrOpts, opts) ->
        item =
          if typeof urlOrOpts is 'object'
            extend {}, urlOrOpts
          else
            extend {}, opts, url: urlOrOpts
        deferred = @options.Deferred()
        extend item,
          assetId: counter += 1
          reject: (args...) -> deferred.reject args...
          resolve: (args...) -> deferred.resolve args...
        @queue[method] item
        promise = deferred.promise()
        promise.then =>
          if (index = @loading.indexOf item) != -1
            # Remove the item from the list.
            @loading.splice index, 1
          # Load the next item.
          @_loadNext()
        @_loadNext() if @options.autostart
        new LoadResult this, promise, item

      # TODO: Take option to prepend instead of append?
      load: (args...) -> @append args...

      append: (urlOrOpts, opts) -> @_add 'push', urlOrOpts, opts

      prepend: (url, opts) -> @_add 'unshift', urlOrOpts, opts

      start: ->
        @_loadNext()
        this


The queueup module itself is the master load queue, as well as a factory for
other load queues.


    @queueup = (args...) -> new LoadQueue args...
    extend @queueup, new LoadQueue, LoadQueue: LoadQueue
    LoadQueue.call @queueup
