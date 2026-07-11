/* Keys From Above — minimal progressive enhancement.
   The site works fully without JS; this only adds polish. */

(function () {
  'use strict';

  /* Current year in the footer. */
  var year = document.getElementById('year');
  if (year) year.textContent = new Date().getFullYear();

  /* Offset anchor jumps so the sticky nav doesn't cover the target.
     (CSS scroll-margin-top handles this, but we set it here so the value
     stays in sync with the actual rendered nav height.) */
  function syncScrollMargin() {
    var nav = document.querySelector('.nav');
    if (!nav) return;
    var h = nav.getBoundingClientRect().height + 12;
    document.querySelectorAll('section[id], .anchor-alias').forEach(function (el) {
      el.style.scrollMarginTop = h + 'px';
    });
  }
  syncScrollMargin();
  window.addEventListener('resize', syncScrollMargin);

  /* Some mobile browsers refuse the initial autoplay of the hero video.
     If it's paused after load, quietly retry once; if it still won't play,
     the poster image remains — which is a perfectly good fallback. */
  var hero = document.querySelector('.section--hero video');
  if (hero) {
    var tryPlay = function () {
      var p = hero.play();
      if (p && typeof p.catch === 'function') p.catch(function () { /* poster stands in */ });
    };
    if (hero.paused) tryPlay();
    document.addEventListener('visibilitychange', function () {
      if (!document.hidden && hero.paused) tryPlay();
    });
  }
})();
