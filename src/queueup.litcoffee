    Promise = require './Promise'
    extend = require 'xtend/mutable'

The LoadQueue is the workhorse for queueup. It's the object responsible for
managing the timing of the loading of assets.

    class LoadQueue
      @defaultOptions =
        Promise: Promise
        autostart: false
        simultaneous: 6  # The maximum number of items to load at once
        loaders: {}
        extensions:
          image: ['png', 'jpg', 'jpeg', 'gif', 'svg']
          html: ['html']

      constructor: (opts) ->
        @loading = []
        @_options = extend {}, LoadQueue.defaultOptions, opts
        _queueGroup = @_createGroup()

      config: (opts) ->
        if opts? then extend @_options, opts
        extend {}, @_options

      registerLoader: (type, loader) ->
        @_options.loaders ?= {}
        @_options.loaders[type] = loader
        this

      startGroup: ->
        parent = @_getGroup()
        group = @_createGroup parent
        parent.append group
        @_currentGroup = group

      endGroup: ->
        oldGroup = @_getGroup()
        @_currentGroup = oldGroup.parent
        # Set up the group's promise resolution
        @_options.Promise.all(oldGroup._group)
          .then oldGroup._resolve, oldGroup._reject
        oldGroup

      # TODO: Take option to prepend instead of append?
      load: (args...) ->
        result = @_createLoadResult args...
        @_getGroup().append result
        @_loadNext() if @_options.autostart
        result

      start: ->
        @_loadNext()
        this

      _createGroup: (parent) ->
        deferred = new Deferred @_options.Promise
        new Group this, parent, deferred

      _createLoadResult: (urlOrOpts, opts) ->
        newOpts =
          if typeof urlOrOpts is 'object'
            extend {}, urlOrOpts
          else
            extend {}, opts, url: urlOrOpts
        deferred = new Deferred @_options.Promise
        onItemDone = =>
          if (index = @loading.indexOf opts) != 1
            # Remove the item from the list.
            @loading.splice index, 1
          # Load the next item.
          @_loadNext()
        deferred.promise.then onItemDone, onItemDone
        new LoadResult this, @_getGroup(), deferred, newOpts

      _getGroup: ->
        @_currentGroup ?= @_createGroup @_queueGroup

      _getLoader: (opts) ->
        loader = opts?.loader ? @_options.loaders[@_getType opts]
        unless loader
            throw new Error "A loader to handle #{opts.url} could not be found"
        loader

      _getType: (opts) ->
        return opts.type if opts?.type?
        ext = opts.url?.match(EXT_RE)?[1].toLowerCase()
        for k, v of @_options.extensions
          return k if ext in v
        throw new Error "Couldn't determine type of #{ opts.url }"

      _loadNext: =>
        return unless @loading.length < @_options.simultaneous
        if next = @_getGroup().next()
          try
            @_loadNow next
          catch err
            console?.warn? "Error: #{ err.message }"
            next._reject err

          # Keep calling recursively until we're loading the max we can.
          @_loadNext()

      _loadNow: (resultObj) ->
        opts = resultObj.loadOptions
        @loading.push opts
        loader = @_getLoader opts
        callback = (err, result) ->
          if err then resultObj._reject err
          else resultObj._resolve result
        loader(opts, callback)
          ?.then? resultObj._resolve, resultObj._reject  # If a promise is returned, use it.

The LoadResult is the result of calling `load()`. It implements a promise API.

    class LoadResult
      constructor: (loadQueue, @parent, deferred, @loadOptions) ->
        extend this, boundFns(loadQueue)
        {promise, resolve, reject} = deferred
        for fn in ['then', 'catch']
          do (fn) =>
            @[fn] = (args...) ->
              promise[fn] args...
              this
        @_resolve = (value) -> resolve value
        @_reject = (reason) -> reject reason
      promote: -> @parent._promote this
      cancel: -> throw new Error 'not implemented'

A Group is a type of LoadResult that groups other LoadResults.

    class Group extends LoadResult
      constructor: (loadQueue, parent, deferred) ->
        super loadQueue, parent, deferred
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


Utilities
---------

A Deferred is a utility object for dealing with promises. It encapsulates a
promise as well as `resolve`, and `reject` methods.

    class Deferred
      constructor: (Promise) ->
        unless Promise
          throw new Error "Environment doesn't support Promises; you must provide a Promise option."
        @promise = new Promise (a, b) => @resolve = a; @reject = b

This regular expression is used to extract extensions from a URL string.

    EXT_RE = /\.([^.]+?)(\?.*)?$/

Create a new object with bound versions of each of the functions of the provided
object.

    boundFns = (obj) ->
      result = {}
      for k, v of obj
        if typeof v is 'function' and k[0] != '_'
          do (v) ->
            result[k] = (args...) -> v.apply obj, args
      result

The queueup module itself is a factory for other load queues.

    queueup = (args...) -> new LoadQueue args...
    queueup.LoadQueue = LoadQueue

    module.exports = queueup
