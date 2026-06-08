/**
 * Markdown Reader — 主题展示交互
 * 33 套主题的筛选、色板展示、点击复制色值
 */
(function () {
  'use strict';

  // --- Theme Filter ---
  const filterBtns = document.querySelectorAll('.theme-filter-btn');
  const themeCards = document.querySelectorAll('.theme-card');

  filterBtns.forEach(function (btn) {
    btn.addEventListener('click', function () {
      // Update active button
      filterBtns.forEach(function (b) { b.classList.remove('active'); });
      btn.classList.add('active');

      var filter = btn.getAttribute('data-filter');

      themeCards.forEach(function (card) {
        if (filter === 'all' || card.getAttribute('data-type') === filter) {
          card.classList.remove('hidden');
        } else {
          card.classList.add('hidden');
        }
      });
    });
  });

  // --- Copy color on swatch click ---
  var swatches = document.querySelectorAll('.theme-color-swatch');

  swatches.forEach(function (swatch) {
    swatch.style.cursor = 'pointer';
    swatch.setAttribute('title', swatch.getAttribute('title') + ' — 点击复制');

    swatch.addEventListener('click', function (e) {
      e.stopPropagation();
      var color = rgbToHex(swatch.style.backgroundColor) || swatch.style.backgroundColor;

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(color).then(function () {
          showCopyToast(swatch, color);
        });
      } else {
        // Fallback for older browsers
        var ta = document.createElement('textarea');
        ta.value = color;
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        document.execCommand('copy');
        document.body.removeChild(ta);
        showCopyToast(swatch, color);
      }
    });
  });

  function rgbToHex(rgb) {
    if (!rgb || rgb.charAt(0) === '#') return rgb;
    var match = rgb.match(/^rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    if (!match) return rgb;
    return '#' +
      ('0' + parseInt(match[1], 10).toString(16)).slice(-2) +
      ('0' + parseInt(match[2], 10).toString(16)).slice(-2) +
      ('0' + parseInt(match[3], 10).toString(16)).slice(-2);
  }

  function showCopyToast(anchor, color) {
    var existing = anchor.querySelector('.copy-toast');
    if (existing) existing.remove();

    var toast = document.createElement('span');
    toast.className = 'copy-toast';
    toast.textContent = '已复制 ' + color;
    toast.style.cssText =
      'position:absolute;bottom:calc(100% + 6px);left:50%;transform:translateX(-50%);' +
      'background:#333;color:#fff;padding:4px 10px;border-radius:6px;font-size:0.75rem;' +
      'white-space:nowrap;pointer-events:none;z-index:10;opacity:0;transition:opacity 0.2s;';

    anchor.style.position = 'relative';
    anchor.appendChild(toast);

    // Trigger animation
    requestAnimationFrame(function () {
      toast.style.opacity = '1';
    });

    setTimeout(function () {
      toast.style.opacity = '0';
      setTimeout(function () { toast.remove(); }, 200);
    }, 1200);
  }

  // --- Smooth scroll for anchor links ---
  document.querySelectorAll('a[href^="#"]').forEach(function (link) {
    link.addEventListener('click', function (e) {
      var target = document.querySelector(link.getAttribute('href'));
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth' });
      }
    });
  });
})();
