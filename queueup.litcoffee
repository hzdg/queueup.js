
    EXT_RE = /\.([^.]+?)(\?.*)?$/

    counter = 0

    extend = (target, sources...) ->
      for source in sources by -1
        for own k, v of source
          target[k] = v
      target

    class ImageLoader

    Deferred = (opts) ->
      factory = opts.factory
      loadQueue = opts.loadQueue
      assetId = opts.assetId
      extend factory(),
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
          image: ImageLoader
        extensions:
          image: ['png', 'jpg', 'jpeg', 'gif']

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
        @_remove(assetId)
        this

      _loadNext: ->
        return unless @loading.length < @options.simultaneous
        next = @queue.shift()
        @_loadNow next
        @_loadNext()  # Keep calling recursively until we're loading the max we can.

      _loadNow: (item) ->
        @loading.push item
        loader = @getLoader item
        # actually load it here

      getType: (item) ->
        unless type = item.type
          ext = item.url?.match(EXT_RE)?[1].toLowerCase()
          type = @extensions

      getLoader: (item) ->
        @options.loaders[@getType item]

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

      append: (urlOrOpts, opts) ->
        @_add 'push', urlOrOpts, opts

      prepend: (url, opts) ->
        @_add 'unshift', urlOrOpts, opts


The queueup module itself is also an alias for the master queue's `append()`
method.

    masterQueue = new LoadQueue
    @queueup = (args...) -> masterQueue.append.apply masterQueue, args...
    @queueup.LoadQueue = LoadQueue
