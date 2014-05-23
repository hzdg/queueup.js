    Promise = require './Promise'


    createPromise = (Promise) ->
      unless Promise
        throw new Error "Environment doesn't support Promises; you must provide a Promise option."
      resolve = reject = null
      promise = new Promise (a, b) -> resolve = a; reject = b
      [promise, resolve, reject]

    groupPromises = (Promise, promises...) ->
      count = 0
      failed = false
      [promise, resolve, reject] = createPromise Promise
      results = new Array promises.length
      checkDeferred = ->
        return if failed
        if count == promises.length
          resolve results...
      for p, i in promises
        do (i) ->
          p.then (args...) ->
            results[i] = args
            count += 1
            checkDeferred()
          p.catch (args...) ->
            failed = true
            count += 1
            reject args...
      promise


    EXT_RE = /\.([^.]+?)(\?.*)?$/

    counter = 0

    extend = (target, sources...) ->
      for source in sources by -1
        for own k, v of source
          target[k] = v
      target

    loadImage = (opts, done, fail) ->
      img = new Image
      img.onload = ->
        if ('naturalWidth' of this and (@naturalWidth + @naturalHeight == 0)) or (@width + @height == 0)
          fail new Error "Image <#{ opts.url }> could not be loaded."
        else
          done img
      img.onerror = fail
      img.src = opts.url
      return

    loadHtml = (opts, done, fail) ->
      xhr = new XMLHttpRequest
      xhr.onreadystatechange = ->
        if xhr.readyState == 4
          if xhr.status == 200
            done xhr.responseText
          else
            fail new Error "URL <#{ opts.url }> failed with status #{ xhr.status }."
      xhr.open 'GET', opts.url, true
      xhr.send()
      return

    boundFns = (obj) ->
      result = {}
      for k, v of obj
        if typeof v is 'function' and k[0] != '_'
          do (v) ->
            result[k] = (args...) -> v.apply obj, args
      result

The LoadResult is the result of calling `load()`. It implements a promise API.

    class LoadResult
      constructor: (loadQueue, @parent, promise, resolve, reject, @loadOptions) ->
        extend this, boundFns(loadQueue)
        for k, v of {then: 'then', catch: 'catch', fail: 'catch', done: 'then'} # FIXME: Remove `done`, `fail`
          do (k, v) =>
            @[k] = (args...) ->
              promise[v] args...
              this
        @_done = (args...) -> resolve args...
        @_fail = (args...) -> reject args...
        # @state = -> promise.state() # FIXME: Do we need this?
      promote: -> @parent._promote this
      cancel: -> throw new Error 'not implemented'

A Group is a type of LoadResult that groups other LoadResults.

    class Group extends LoadResult
      constructor: (loadQueue, parent, promise, @resolve, @reject) ->
        super loadQueue, parent, promise
        @_group = []

      append: (loadResult) -> @_group.push loadResult

      prepend: (loadResult) -> @_group.unshift loadResult

      next: ->
        if @_group.length and @_group[0].next
          # If next is a nested group, return its next item, if it has one.
          return next if next = @_group[0].next()
          # TODO: resolve nested group?
          # If the nested group was empty, discard it and call next again.
          @_group.shift()
          return @next()
        @_group.shift()

      # Promote an asset in the group.
      # If the asset is already at the 'head' or already loaded, this is a noop.
      _promote: (loadResult) ->
        if (index = @_group.indexOf loadResult) > 0
          @_group.splice index, 1
          @_group.unshift loadResult
        loadResult

The LoadQueue is the workhorse for queueup. It's the object responsible for
managing the timing of the loading of assets.

    class LoadQueue
      defaultOptions:
        Promise: Promise
        autostart: false
        simultaneous: 6  # The maximum number of items to load at once
        loaders:
          image: loadImage
          html: loadHtml
        extensions:
          image: ['png', 'jpg', 'jpeg', 'gif', 'svg']
          html: ['html']

      constructor: (opts) ->
        @loading = []
        @config opts
        @_queueGroup = @_createGroup()

      config: (opts) ->
        unless @options
          @options ?= {}
          for own k, v of @defaultOptions
            @options[k] = v
        for own k, v of opts
          @options[k] = v
        this

      group: ->
        parent = @_getGroup()
        group = @_createGroup parent
        parent.append group
        @_currentGroup = group

      endGroup: ->
        oldGroup = @_getGroup()
        @_currentGroup = oldGroup.parent
        # Set up the group's promise resolution
        groupPromises(@options.Promise, oldGroup._group...)
          .then oldGroup.resolve, oldGroup.reject
        oldGroup

      # TODO: Take option to prepend instead of append?
      load: (args...) ->
        result = @_createLoadResult args...
        @_getGroup().append result
        @_loadNext() if @options.autostart
        result

      start: ->
        @_loadNext()
        this

      _createGroup: (parent) ->
        [promise, resolve, reject] = createPromise @options.Promise
        new Group this, parent, promise, resolve, reject

      _createLoadResult: (urlOrOpts, opts) ->
        newOpts =
          if typeof urlOrOpts is 'object'
            extend {}, urlOrOpts
          else
            extend {}, opts, url: urlOrOpts
        [promise, resolve, reject] = createPromise @options.Promise
        onItemDone = =>
          if (index = @loading.indexOf opts) != 1
            # Remove the item from the list.
            @loading.splice index, 1
          # Load the next item.
          @_loadNext()
        promise.then onItemDone, onItemDone
        new LoadResult this, @_getGroup(), promise, resolve, reject, newOpts

      _getGroup: ->
        @_currentGroup ?= @_createGroup @_queueGroup

      _getLoader: (opts) -> opts.loader ? @options.loaders[@_getType opts]

      _getType: (opts) ->
        return opts.type if opts?.type?
        ext = opts.url?.match(EXT_RE)?[1].toLowerCase()
        for k, v of @options.extensions
          return k if ext in v
        throw new Error "Couldn't determine type of #{ opts.url }"

      _loadNext: =>
        return unless @loading.length < @options.simultaneous
        if next = @_getGroup().next()
          try
            @_loadNow next
          catch err
            console?.warn? "Error: #{ err.message }"
            next._fail err

          # Keep calling recursively until we're loading the max we can.
          @_loadNext()

      _loadNow: (resultObj) ->
        opts = resultObj.loadOptions
        @loading.push opts
        loader = @_getLoader opts
        loader(opts, resultObj._done, resultObj._fail)
          ?.then? resultObj._done, resultObj._fail  # If a promise is returned, use it.


The queueup module itself is a factory for other load queues.


    queueup = (args...) -> new LoadQueue args...
    queueup.LoadQueue = LoadQueue

    module.exports = queueup
