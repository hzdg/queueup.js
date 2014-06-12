!function(e){if("object"==typeof exports&&"undefined"!=typeof module)module.exports=e();else if("function"==typeof define&&define.amd)define([],e);else{var f;"undefined"!=typeof window?f=window:"undefined"!=typeof global?f=global:"undefined"!=typeof self&&(f=self),f.queueup=e()}}(function(){var define,module,exports;return (function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);throw new Error("Cannot find module '"+o+"'")}var f=n[o]={exports:{}};t[o][0].call(f.exports,function(e){var n=t[o][1][e];return s(n?n:e)},f,f.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(_dereq_,module,exports){
(function() {
  module.exports = window.Promise;

}).call(this);

},{}],2:[function(_dereq_,module,exports){
(function() {
  var Deferred, EXT_RE, Group, LoadQueue, LoadResult, Promise, boundFns, extend, queueup,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __slice = [].slice,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Promise = _dereq_('./Promise');

  extend = _dereq_('xtend/mutable');

  LoadQueue = (function() {
    LoadQueue.defaultOptions = {
      Promise: Promise,
      autostart: false,
      simultaneous: 6,
      loaders: {},
      extensions: {
        image: ['png', 'jpg', 'jpeg', 'gif', 'svg'],
        html: ['html']
      }
    };

    function LoadQueue(opts) {
      this._loadNext = __bind(this._loadNext, this);
      this.loading = [];
      this._options = extend({}, LoadQueue.defaultOptions, opts);
      this.startGroup();
    }

    LoadQueue.prototype.config = function(opts) {
      if (opts != null) {
        extend(this._options, opts);
      }
      return extend({}, this._options);
    };

    LoadQueue.prototype.registerLoader = function(type, loader) {
      var _base;
      if ((_base = this._options).loaders == null) {
        _base.loaders = {};
      }
      this._options.loaders[type] = loader;
      return this;
    };

    LoadQueue.prototype.startGroup = function() {
      var group, parent;
      parent = this._getGroup();
      group = this._createGroup(parent);
      if (parent != null) {
        parent.add(group);
      }
      return this._currentGroup = group;
    };

    LoadQueue.prototype.endGroup = function() {
      var oldGroup;
      oldGroup = this._getGroup();
      this._currentGroup = oldGroup.parent;
      if (!this._currentGroup) {
        throw new Error('There is no open group.');
      }
      this._options.Promise.all(oldGroup._group).then(oldGroup._resolve, oldGroup._reject);
      return oldGroup;
    };

    LoadQueue.prototype.enqueue = function(fn, opts) {
      var deferred, loadResult, onItemDone, task;
      deferred = new Deferred(this._options.Promise);
      task = (function(_this) {
        return function() {
          var callback, _ref;
          callback = function(err, res) {
            if (err) {
              return deferred.reject(err);
            } else {
              return deferred.resolve(res);
            }
          };
          _this.loading.push(loadResult);
          return (_ref = fn(callback)) != null ? typeof _ref.then === "function" ? _ref.then(deferred.resolve, deferred.reject) : void 0 : void 0;
        };
      })(this);
      onItemDone = (function(_this) {
        return function() {
          var index;
          if ((index = _this.loading.indexOf(loadResult)) !== 1) {
            _this.loading.splice(index, 1);
          }
          return _this._loadNext();
        };
      })(this);
      deferred.promise.then(onItemDone, onItemDone);
      loadResult = new LoadResult(this, this._getGroup(), deferred, task, {
        priority: opts != null ? opts.priority : void 0
      });
      this._getGroup().add(loadResult);
      if (this._options.autostart) {
        this._loadNext();
      }
      return loadResult;
    };

    LoadQueue.prototype.load = function() {
      var args, loaderOpts, opts, queueOpts, resultObj, task, urlOrOpts;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      urlOrOpts = args[0], opts = args[1];
      opts = typeof urlOrOpts === 'object' ? extend({}, urlOrOpts) : extend({}, opts, {
        url: urlOrOpts
      });
      queueOpts = {
        priority: opts.priority
      };
      delete opts.priority;
      loaderOpts = opts;
      task = (function(_this) {
        return function(cb) {
          var loader;
          loader = _this._getLoader(loaderOpts);
          return loader(loaderOpts, cb);
        };
      })(this);
      return resultObj = this.enqueue(task, queueOpts);
    };

    LoadQueue.prototype.start = function() {
      this._loadNext();
      return this;
    };

    LoadQueue.prototype._createGroup = function(parent) {
      var deferred;
      deferred = new Deferred(this._options.Promise);
      return new Group(this, parent, deferred);
    };

    LoadQueue.prototype._getGroup = function() {
      return this._currentGroup;
    };

    LoadQueue.prototype._getLoader = function(opts) {
      var loader, _ref;
      loader = (_ref = opts != null ? opts.loader : void 0) != null ? _ref : this._options.loaders[this._getType(opts)];
      if (!loader) {
        throw new Error("A loader to handle " + opts.url + " could not be found");
      }
      return loader;
    };

    LoadQueue.prototype._getType = function(opts) {
      var ext, k, v, _ref, _ref1, _ref2;
      if ((opts != null ? opts.type : void 0) != null) {
        return opts.type;
      }
      ext = (_ref = opts.url) != null ? (_ref1 = _ref.match(EXT_RE)) != null ? _ref1[1].toLowerCase() : void 0 : void 0;
      _ref2 = this._options.extensions;
      for (k in _ref2) {
        v = _ref2[k];
        if (__indexOf.call(v, ext) >= 0) {
          return k;
        }
      }
      throw new Error("Couldn't determine type of " + opts.url);
    };

    LoadQueue.prototype._loadNext = function() {
      var err, next;
      if (!(this.loading.length < this._options.simultaneous)) {
        return;
      }
      if (next = this._getGroup().next()) {
        try {
          next.task();
        } catch (_error) {
          err = _error;
          if (typeof console !== "undefined" && console !== null) {
            if (typeof console.warn === "function") {
              console.warn("Error: " + err.message);
            }
          }
          next._reject(err);
        }
        return this._loadNext();
      }
    };

    return LoadQueue;

  })();

  LoadResult = (function() {
    function LoadResult(loadQueue, parent, deferred, task, options) {
      var fn, priority, promise, reject, resolve, _fn, _i, _len, _ref, _ref1;
      this.parent = parent;
      this.task = task;
      extend(this, boundFns(loadQueue));
      promise = deferred.promise, resolve = deferred.resolve, reject = deferred.reject;
      _ref = ['then', 'catch'];
      _fn = (function(_this) {
        return function(fn) {
          return _this[fn] = function() {
            var args;
            args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
            promise[fn].apply(promise, args);
            return this;
          };
        };
      })(this);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        fn = _ref[_i];
        _fn(fn);
      }
      this._resolve = function(value) {
        return resolve(value);
      };
      this._reject = function(reason) {
        return reject(reason);
      };
      priority = (_ref1 = options != null ? options.priority : void 0) != null ? _ref1 : 0;
      this.priority = function(value) {
        if (value != null) {
          return priority = value;
        } else {
          return priority;
        }
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

    function Group(loadQueue, parent, deferred) {
      Group.__super__.constructor.call(this, loadQueue, parent, deferred);
      this._group = [];
    }

    Group.prototype.add = function(loadResult) {
      return this._group.push(loadResult);
    };

    Group.prototype.next = function() {
      var i, item, itemPriority, next, nextItem, nextItemIndex, p, _i, _len, _ref;
      if (!this._group.length) {
        return;
      }
      nextItem = null;
      nextItemIndex = -1;
      p = 0;
      _ref = this._group;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        item = _ref[i];
        itemPriority = item.priority();
        if (!nextItem || itemPriority > p) {
          nextItem = item;
          p = itemPriority;
          nextItemIndex = i;
        }
      }
      if (nextItem.next) {
        if (next = nextItem.next()) {
          return next;
        }
        this._group.splice(nextItemIndex, 1);
        return this.next();
      } else if (nextItem) {
        this._group.splice(nextItemIndex, 1);
        return nextItem;
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

  Deferred = (function() {
    function Deferred(Promise) {
      if (!Promise) {
        throw new Error("Environment doesn't support Promises; you must provide a Promise option.");
      }
      this.promise = new Promise((function(_this) {
        return function(a, b) {
          _this.resolve = a;
          return _this.reject = b;
        };
      })(this));
    }

    return Deferred;

  })();

  EXT_RE = /\.([^.]+?)(\?.*)?$/;

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

  queueup = function() {
    var args;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    return (function(func, args, ctor) {
      ctor.prototype = func.prototype;
      var child = new ctor, result = func.apply(child, args);
      return Object(result) === result ? result : child;
    })(LoadQueue, args, function(){});
  };

  queueup.LoadQueue = LoadQueue;

  module.exports = queueup;

}).call(this);

},{"./Promise":1,"xtend/mutable":3}],3:[function(_dereq_,module,exports){
module.exports = extend

function extend(target) {
    for (var i = 1; i < arguments.length; i++) {
        var source = arguments[i]

        for (var key in source) {
            if (source.hasOwnProperty(key)) {
                target[key] = source[key]
            }
        }
    }

    return target
}

},{}]},{},[2])
(2)
});