
    groupPromises = (Deferred, promises...) ->
      count = 0
      failed = false
      deferred = Deferred()
      results = new Array promises.length
      checkDeferred = ->
        return if failed
        if count == promises.length
          deferred.resolve results...
      for p, i in promises
        do (i) ->
          p.then (args...) ->
            results[i] = args
            count += 1
            checkDeferred()
          p.fail (args...) ->
            failed = true
            count += 1
            deferred.reject args...
      deferred.promise()


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
      return

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
      constructor: (loadQueue, @parent, promise, @item) ->
        extend this, boundFns(loadQueue)
        for fn in ['then', 'fail', 'done']
          do (fn) =>
            @[fn] = (args...) ->
              promise[fn] args...
              this
        @state = -> promise.state()
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

      # Remove an asset from the group and return it.
      _remove: (assetId) ->
        for result, i in @_group
          if result.asset?.assetId is assetId
            return @_group.splice(i, 1)[0]

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
        Deferred: $?.Deferred
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
        groupPromises(@options.Deferred, oldGroup._group...)
          .done(oldGroup.resolve)
          .fail(oldGroup.reject)
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
        deferred = @options.Deferred()
        promise = deferred.promise()
        new Group this, parent, promise, deferred.resolve, deferred.reject

      _createLoadResult: (urlOrOpts, opts) ->
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
        promise = deferred.promise()
        onItemDone = =>
          if (index = @loading.indexOf item) != 1
            # Remove the item from the list.
            @loading.splice index, 1
          # Load the next item.
          @_loadNext()
        promise.then onItemDone, onItemDone
        new LoadResult this, @_getGroup(), promise, item

      _getGroup: ->
        @_currentGroup ?= @_createGroup @_queueGroup

      _getLoader: (item) -> item.loader ? @options.loaders[@_getType item]

      _getType: (item) ->
        return item.type if item?.type?
        ext = item.url?.match(EXT_RE)?[1].toLowerCase()
        for k, v of @options.extensions
          return k if ext in v
        throw new Error "Couldn't determine type of #{ item.url }"

      _loadNext: =>
        return unless @loading.length < @options.simultaneous
        if next = @_getGroup().next()
          try
            @_loadNow next.item
          catch err
            console?.warn? "Error: #{ err.message }"
            next.item.reject(err)

          # Keep calling recursively until we're loading the max we can.
          @_loadNext()

      _loadNow: (item) ->
        @loading.push item
        loader = @_getLoader item
        loader item


The queueup module itself is a factory for other load queues.


    @queueup = (args...) -> new LoadQueue args...
