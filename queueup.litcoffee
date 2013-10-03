
    EXT_RE = /\.([^.]+?)(\?.*)?$/

    class ImageLoader

The LoadQueue is the workhorse for queueup. It's the object responsible for
managing the timing of the loading of assets.

    class LoadQueue
      defaultOptions:
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
        if typeof urlOrOpts is 'object'
          opts = urlOrOpts
        else
          opts.url = urlOrOpts
        @queue[method](opts)
        @_loadNext() if @options.autostart
        this

      append: (urlOrOpts, opts) ->
        @_add 'push', urlOrOpts, opts

      prepend: (url, opts) ->
        @_add 'unshift', urlOrOpts, opts


    # TODO: Allow custom deferred base
    LoadDeferred


The queueup module itself is actually just the master LoadQueue. It's augmented
with a few extra properties.

    @queueup = new LoadQueue
    @queueup.LoadQueue = LoadQueue
