(function() {
  var EXT_RE, Group, LoadQueue, LoadResult, boundFns, counter, extend, groupPromises, loadHtml, loadImage,
    __slice = [].slice,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  groupPromises = function() {
    var Deferred, checkDeferred, count, deferred, failed, i, p, promises, results, _fn, _i, _len;
    Deferred = arguments[0], promises = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    count = 0;
    failed = false;
    deferred = Deferred();
    results = new Array(promises.length);
    checkDeferred = function() {
      if (failed) {
        return;
      }
      if (count === promises.length) {
        return deferred.resolve.apply(deferred, results);
      }
    };
    _fn = function(i) {
      p.then(function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        results[i] = args;
        count += 1;
        return checkDeferred();
      });
      return p.fail(function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        failed = true;
        count += 1;
        return deferred.reject.apply(deferred, args);
      });
    };
    for (i = _i = 0, _len = promises.length; _i < _len; i = ++_i) {
      p = promises[i];
      _fn(i);
    }
    return deferred.promise();
  };

  EXT_RE = /\.([^.]+?)(\?.*)?$/;

  counter = 0;

  extend = function() {
    var k, source, sources, target, v, _i;
    target = arguments[0], sources = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    for (_i = sources.length - 1; _i >= 0; _i += -1) {
      source = sources[_i];
      for (k in source) {
        if (!__hasProp.call(source, k)) continue;
        v = source[k];
        target[k] = v;
      }
    }
    return target;
  };

  loadImage = function(item) {
    var img;
    img = new Image;
    img.onload = function() {
      if (('naturalWidth' in this && (this.naturalWidth + this.naturalHeight === 0)) || (this.width + this.height === 0)) {
        return item.reject();
      } else {
        return item.resolve(img);
      }
    };
    img.onerror = item.reject;
    img.src = item.url;
    return null;
  };

  loadHtml = function(item) {
    var xhr;
    xhr = new XMLHttpRequest;
    xhr.onreadystatechange = function() {
      if (xhr.readyState === 4) {
        if (xhr.status === 200) {
          return item.resolve(xhr.responseText);
        } else {
          return item.reject(xhr.status);
        }
      }
    };
    xhr.open('GET', item.url, true);
    xhr.send();
    return null;
  };

  boundFns = function(obj) {
    var k, result, v;
    result = {};
    for (k in obj) {
      v = obj[k];
      if (typeof v === 'function' && k[0] !== '_') {
        (function(v) {
          return result[k] = function() {
            var args;
            args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
            return v.apply(obj, args);
          };
        })(v);
      }
    }
    return result;
  };

  LoadResult = (function() {
    function LoadResult(loadQueue, parent, promise, item) {
      var fn, _fn, _i, _len, _ref,
        _this = this;
      this.parent = parent;
      this.item = item;
      extend(this, boundFns(loadQueue));
      _ref = ['then', 'fail', 'done'];
      _fn = function(fn) {
        return _this[fn] = function() {
          var args;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          promise[fn].apply(promise, args);
          return this;
        };
      };
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        fn = _ref[_i];
        _fn(fn);
      }
      this.state = function() {
        return promise.state();
      };
    }

    LoadResult.prototype.promote = function() {
      return this.parent._promote(this);
    };

    LoadResult.prototype.cancel = function() {
      throw new Error('not implemented');
    };

    return LoadResult;

  })();

  Group = (function(_super) {
    __extends(Group, _super);

    function Group(loadQueue, parent, promise, resolve, reject) {
      this.resolve = resolve;
      this.reject = reject;
      Group.__super__.constructor.call(this, loadQueue, parent, promise);
      this._group = [];
    }

    Group.prototype.append = function(loadResult) {
      return this._group.push(loadResult);
    };

    Group.prototype.prepend = function(loadResult) {
      return this._group.unshift(loadResult);
    };

    Group.prototype.next = function() {
      var next;
      if (this._group.length && this._group[0].next) {
        if (next = this._group[0].next()) {
          return next;
        }
        this._group.shift();
        return this.next();
      }
      return this._group.shift();
    };

    Group.prototype._remove = function(assetId) {
      var i, result, _i, _len, _ref, _ref1;
      _ref = this._group;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        result = _ref[i];
        if (((_ref1 = result.asset) != null ? _ref1.assetId : void 0) === assetId) {
          return this._group.splice(i, 1)[0];
        }
      }
    };

    Group.prototype._promote = function(loadResult) {
      var index;
      if ((index = this._group.indexOf(loadResult)) > 0) {
        this._group.splice(index, 1);
        this._group.unshift(loadResult);
      }
      return loadResult;
    };

    return Group;

  })(LoadResult);

  LoadQueue = (function() {
    LoadQueue.prototype.defaultOptions = {
      Deferred: typeof $ !== "undefined" && $ !== null ? $.Deferred : void 0,
      autostart: false,
      simultaneous: 6,
      loaders: {
        image: loadImage,
        html: loadHtml
      },
      extensions: {
        image: ['png', 'jpg', 'jpeg', 'gif', 'svg'],
        html: ['html']
      }
    };

    function LoadQueue(opts) {
      this._loadNext = __bind(this._loadNext, this);
      this.loading = [];
      this.config(opts);
      this._queueGroup = this._createGroup();
    }

    LoadQueue.prototype.config = function(opts) {
      var k, v, _ref;
      if (!this.options) {
        if (this.options == null) {
          this.options = {};
        }
        _ref = this.defaultOptions;
        for (k in _ref) {
          if (!__hasProp.call(_ref, k)) continue;
          v = _ref[k];
          this.options[k] = v;
        }
      }
      for (k in opts) {
        if (!__hasProp.call(opts, k)) continue;
        v = opts[k];
        this.options[k] = v;
      }
      return this;
    };

    LoadQueue.prototype.group = function() {
      var group, parent;
      parent = this._getGroup();
      group = this._createGroup(parent);
      parent.append(group);
      return this._currentGroup = group;
    };

    LoadQueue.prototype.endGroup = function() {
      var oldGroup;
      oldGroup = this._getGroup();
      this._currentGroup = oldGroup.parent;
      groupPromises.apply(null, [this.options.Deferred].concat(__slice.call(oldGroup._group))).done(oldGroup.resolve).fail(oldGroup.reject);
      return oldGroup;
    };

    LoadQueue.prototype.load = function() {
      var args, result;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      result = this._createLoadResult.apply(this, args);
      this._getGroup().append(result);
      if (this.options.autostart) {
        this._loadNext();
      }
      return result;
    };

    LoadQueue.prototype.start = function() {
      this._loadNext();
      return this;
    };

    LoadQueue.prototype._createGroup = function(parent) {
      var deferred, promise;
      deferred = this.options.Deferred();
      promise = deferred.promise();
      return new Group(this, parent, promise, deferred.resolve, deferred.reject);
    };

    LoadQueue.prototype._createLoadResult = function(urlOrOpts, opts) {
      var deferred, item, onItemDone, promise,
        _this = this;
      item = typeof urlOrOpts === 'object' ? extend({}, urlOrOpts) : extend({}, opts, {
        url: urlOrOpts
      });
      deferred = this.options.Deferred();
      extend(item, {
        assetId: counter += 1,
        reject: function() {
          var args;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          return deferred.reject.apply(deferred, args);
        },
        resolve: function() {
          var args;
          args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          return deferred.resolve.apply(deferred, args);
        }
      });
      promise = deferred.promise();
      onItemDone = function() {
        var index;
        if ((index = _this.loading.indexOf(item)) !== 1) {
          _this.loading.splice(index, 1);
        }
        return _this._loadNext();
      };
      promise.then(onItemDone, onItemDone);
      return new LoadResult(this, this._getGroup(), promise, item);
    };

    LoadQueue.prototype._getGroup = function() {
      return this._currentGroup != null ? this._currentGroup : this._currentGroup = this._createGroup(this._queueGroup);
    };

    LoadQueue.prototype._getLoader = function(item) {
      var _ref;
      return (_ref = item.loader) != null ? _ref : this.options.loaders[this._getType(item)];
    };

    LoadQueue.prototype._getType = function(item) {
      var ext, k, v, _ref, _ref1, _ref2;
      if ((item != null ? item.type : void 0) != null) {
        return item.type;
      }
      ext = (_ref = item.url) != null ? (_ref1 = _ref.match(EXT_RE)) != null ? _ref1[1].toLowerCase() : void 0 : void 0;
      _ref2 = this.options.extensions;
      for (k in _ref2) {
        v = _ref2[k];
        if (__indexOf.call(v, ext) >= 0) {
          return k;
        }
      }
      throw new Error("Couldn't determine type of " + item.url);
    };

    LoadQueue.prototype._loadNext = function() {
      var err, next;
      if (!(this.loading.length < this.options.simultaneous)) {
        return;
      }
      if (next = this._getGroup().next()) {
        try {
          this._loadNow(next.item);
        } catch (_error) {
          err = _error;
          if (typeof console !== "undefined" && console !== null) {
            if (typeof console.warn === "function") {
              console.warn("Error: " + err.message);
            }
          }
          next.item.reject(err);
        }
        return this._loadNext();
      }
    };

    LoadQueue.prototype._loadNow = function(item) {
      var loader;
      this.loading.push(item);
      loader = this._getLoader(item);
      return loader(item);
    };

    return LoadQueue;

  })();

  this.queueup = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (function(func, args, ctor) {
      ctor.prototype = func.prototype;
      var child = new ctor, result = func.apply(child, args);
      return Object(result) === result ? result : child;
    })(LoadQueue, args, function(){});
  };

}).call(this);
