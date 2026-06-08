(function() {
  let _mermaidRenderId = 0;

  const MR = {
    version: '2.0.0',

    scrollToHeading(id) {
      const el = document.getElementById(id);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth', block: 'start' });
        el.classList.add('outline-highlight');
        setTimeout(() => {
          el.classList.add('fade-out');
          setTimeout(() => {
            el.classList.remove('outline-highlight', 'fade-out');
          }, 300);
        }, 1500);
      }
    },

    scrollToLine(lineNumber) {
      const target = document.querySelector(`[data-line="${lineNumber}"]`);
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'center' });
        return true;
      }
      let closest = null;
      let minDiff = Infinity;
      document.querySelectorAll('[data-line]').forEach(el => {
        const diff = Math.abs(parseInt(el.dataset.line) - lineNumber);
        if (diff < minDiff) {
          minDiff = diff;
          closest = el;
        }
      });
      if (closest) {
        closest.scrollIntoView({ behavior: 'smooth', block: 'center' });
        return true;
      }
      return false;
    },

    replaceContent(html) {
      const content = document.getElementById('mr-content');
      if (content) {
        content.innerHTML = html;
        MR.renderMermaid();
        MR.renderKaTeX();
        if (typeof Prism !== 'undefined') {
          Prism.highlightAll();
        }
      }
    },

    getVisibleHeading() {
      const headings = document.querySelectorAll('h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]');
      let visible = null;
      const scrollTop = window.scrollY || document.documentElement.scrollTop;
      const threshold = 100;
      for (let i = headings.length - 1; i >= 0; i--) {
        if (headings[i].getBoundingClientRect().top <= threshold) {
          visible = {
            id: headings[i].id,
            level: parseInt(headings[i].tagName.charAt(1)),
            title: headings[i].textContent.trim(),
            lineNumber: parseInt(headings[i].dataset.line || '0')
          };
          break;
        }
      }
      return visible;
    },

    getScrollPosition() {
      return {
        x: window.scrollX || document.documentElement.scrollLeft,
        y: window.scrollY || document.documentElement.scrollTop
      };
    },

    _resolveThemeColors() {
      const scriptTag = document.querySelector('script[src*="markdown-reader.js"]');
      const isDark = scriptTag ? scriptTag.dataset.isDark === 'true' : true;

      // Mermaid strips var() refs (sanitizeDirective) and khroma needs hex for adjust/darken/invert.
      const style = getComputedStyle(document.documentElement);
      const resolve = (v) => {
        if (!v || !v.startsWith('var(')) return v;
        const inner = v.slice(4, v.lastIndexOf(')')).trim();
        const name = inner.includes(',') ? inner.slice(0, inner.indexOf(',')).trim() : inner;
        let resolved = style.getPropertyValue(name).trim();
        if (resolved.startsWith('var(')) resolved = resolve(resolved);
        return resolved || v;
      };

      const toHex = (cssColor) => {
        if (!cssColor || cssColor.startsWith('#')) return cssColor;
        const ctx = document.createElement('canvas').getContext('2d');
        ctx.fillStyle = cssColor;
        return ctx.fillStyle;
      };

      return {
        isDark,
        themeVariables: {
          primaryColor: toHex(resolve('var(--accent)')),
          primaryTextColor: toHex(resolve('var(--ink)')),
          primaryBorderColor: toHex(resolve('var(--border)')),
          lineColor: toHex(resolve('var(--fg-muted)')),
          secondaryColor: toHex(resolve('var(--bg-elevated)')),
          tertiaryColor: toHex(resolve('var(--bg-subtle)'))
        }
      };
    },

    _showMermaidError(container, msg) {
      container.innerHTML = '';
      const errBox = document.createElement('div');
      errBox.className = 'mermaid-error';
      errBox.innerHTML = '<strong>Mermaid</strong> — ' + msg;
      container.appendChild(errBox);
    },

    renderMermaid() {
      const mermaidBlocks = document.querySelectorAll('code.language-mermaid, pre code.language-mermaid');
      if (mermaidBlocks.length === 0) return;
      if (typeof mermaid === 'undefined') return;

      const renderId = ++_mermaidRenderId;
      const { isDark, themeVariables } = MR._resolveThemeColors();

      mermaid.initialize({
        startOnLoad: false,
        theme: isDark ? 'dark' : 'default',
        themeVariables
      });

      mermaidBlocks.forEach(block => {
        const pre = block.parentElement;
        if (!pre || pre.tagName !== 'PRE') return;
        const container = document.createElement('div');
        container.className = 'mermaid-container';
        container.dataset.mermaidSource = block.textContent;
        const mermaidDiv = document.createElement('div');
        mermaidDiv.className = 'mermaid';
        mermaidDiv.textContent = block.textContent;
        container.appendChild(mermaidDiv);
        pre.replaceWith(container);
      });

      mermaid.run({ suppressErrors: true }).then(() => {
        if (renderId !== _mermaidRenderId) return;
        document.querySelectorAll('.mermaid-container').forEach(container => {
          const svg = container.querySelector('svg');
          if (svg) {
            const errorEl = svg.querySelector('.error-icon, [id*="error"]');
            if (errorEl) MR._showMermaidError(container, '图表语法错误，请检查语法是否正确。');
          } else {
            const unprocessed = container.querySelector('div.mermaid:not([data-processed])');
            if (unprocessed) MR._showMermaidError(container, '图表渲染失败。');
          }
        });
      }).catch(err => {
        if (renderId !== _mermaidRenderId) return;
        console.error('[MarkdownReader] Mermaid render error:', err);
        document.querySelectorAll('.mermaid-container').forEach(container => {
          if (!container.querySelector('svg')) {
            MR._showMermaidError(container, '图表渲染失败。');
          }
        });
      });
    },

    rerenderMermaid() {
      const containers = document.querySelectorAll('.mermaid-container');
      if (containers.length === 0) return;
      if (typeof mermaid === 'undefined') return;

      const renderId = ++_mermaidRenderId;
      const { isDark, themeVariables } = MR._resolveThemeColors();

      mermaid.initialize({
        startOnLoad: false,
        theme: isDark ? 'dark' : 'default',
        themeVariables
      });

      containers.forEach(container => {
        const source = container.dataset.mermaidSource;
        if (!source) return;
        container.innerHTML = '';
        const mermaidDiv = document.createElement('div');
        mermaidDiv.className = 'mermaid';
        mermaidDiv.textContent = source;
        container.appendChild(mermaidDiv);
      });

      mermaid.run({ suppressErrors: true }).then(() => {
        if (renderId !== _mermaidRenderId) return;
        document.querySelectorAll('.mermaid-container').forEach(container => {
          if (!container.querySelector('svg')) {
            MR._showMermaidError(container, '图表渲染失败。');
          }
        });
      }).catch(err => {
        if (renderId !== _mermaidRenderId) return;
        console.error('[MarkdownReader] Mermaid rerender error:', err);
      });
    },

    renderKaTeX() {
      const mathBlocks = document.querySelectorAll('code.language-math, code.language-latex, code.language-katex');
      if (mathBlocks.length === 0) return;
      if (typeof katex === 'undefined') return;

      mathBlocks.forEach(block => {
        const pre = block.parentElement;
        if (!pre || pre.tagName !== 'PRE') return;
        const mathContent = block.textContent;
        const isDisplay = true;
        const container = document.createElement('div');
        container.className = isDisplay ? 'katex-display' : 'katex-inline';
        try {
          katex.render(mathContent, container, {
            displayMode: isDisplay,
            throwOnError: false,
            output: 'html'
          });
        } catch (e) {
          container.textContent = mathContent;
        }
        pre.replaceWith(container);
      });
    },

    init() {
      MR.renderMermaid();
      MR.renderKaTeX();
      if (typeof Prism !== 'undefined') {
        Prism.highlightAll();
      }
    }
  };

  window.MR = MR;

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', MR.init);
  } else {
    MR.init();
  }
})();
