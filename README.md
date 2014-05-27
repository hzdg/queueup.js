queueup.js
==========

queueup.js is a promise-based JavaScript asset loader.

```javascript
queueup().load('myimage.jpg').then(function (image) {
    document.body.appendChild(image);
});
```


Installation
------------

* Node, [browserify] and [webpack] users can `npm install queueup`
* [Bower] users can `bower install queueup`
* Or just grab the script from the "standalone" directory in the repo


[browserify]: http://browserify.org
[webpack]: http://webpack.github.io
[Bower]: http://bower.io
