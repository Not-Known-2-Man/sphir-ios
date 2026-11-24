// Runs inside Safari when the user shares a page (NSExtensionJavaScriptPreprocessingFile).
// Returns the page URL, a cleaned copy of <head> (meta/title only) and every JSON-LD
// block, so the extension can POST them to /api/v1/preview without a server fetch.
var SphirClip = function () {};

SphirClip.prototype = {
  run: function (arguments) {
    var head = "";
    try {
      var clone = document.head ? document.head.cloneNode(true) : null;
      if (clone) {
        // Keep meta + title; drop scripts, styles and links (large, irrelevant).
        var drop = clone.querySelectorAll("script, style, link, noscript");
        for (var i = 0; i < drop.length; i++) { drop[i].parentNode.removeChild(drop[i]); }
        head = clone.outerHTML;
      }
    } catch (e) { head = ""; }

    var jsonld = [];
    try {
      var nodes = document.querySelectorAll('script[type="application/ld+json"]');
      for (var j = 0; j < nodes.length; j++) {
        var text = nodes[j].textContent;
        if (text && text.length < 500000) { jsonld.push(text); }
      }
    } catch (e) { jsonld = []; }

    arguments.completionFunction({ url: document.URL, head: head, jsonld: jsonld });
  },
  finalize: function (arguments) {}
};

var ExtensionPreprocessingJS = new SphirClip();
