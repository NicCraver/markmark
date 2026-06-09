(function() {
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
        MR._searchHighlights = [];
        MR.renderMermaid();
        MR.renderPlantUML();
        MR.renderKaTeX();
        MR.renderAdmonitions();
        MR.addCopyButtons();
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

    getTopVisibleLine() {
      const elements = document.querySelectorAll('[data-line]');
      const threshold = 120;
      let best = null;
      let minDiff = Infinity;
      for (let i = elements.length - 1; i >= 0; i--) {
        const rect = elements[i].getBoundingClientRect();
        const diff = threshold - rect.top;
        if (diff >= 0 && diff < minDiff) {
          minDiff = diff;
          best = elements[i];
        }
      }
      if (best) {
        return parseInt(best.dataset.line) || 1;
      }
      return 1;
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

      // Canvas fillStyle converts CSS colors to #rrggbb but drops the alpha channel.
      // For rgba() values (common in theme borders/muted text), blend with the
      // surface background first so the result matches what users see on screen.
      const toHex = (cssColor) => {
        if (!cssColor || cssColor.startsWith('#')) return cssColor;
        const ctx = document.createElement('canvas').getContext('2d');
        ctx.fillStyle = cssColor;
        const result = ctx.fillStyle;
        // If rgba was converted to #rrggbb, alpha was lost — pre-blend it
        if (result.startsWith('#') && cssColor.includes('rgba')) {
          const match = cssColor.match(/rgba?\(\s*(\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)/);
          if (match) {
            const r = parseInt(match[1]), g = parseInt(match[2]), b = parseInt(match[3]), a = parseFloat(match[4]);
            const surface = isDark ? [24, 24, 26] : [255, 255, 255];
            const blended = [
              Math.round(surface[0] * (1 - a) + r * a),
              Math.round(surface[1] * (1 - a) + g * a),
              Math.round(surface[2] * (1 - a) + b * a)
            ];
            return '#' + blended.map(c => c.toString(16).padStart(2, '0')).join('');
          }
        }
        return result;
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

    async _encodePlantUML(text) {
      const encoder = new TextEncoder();
      const data = encoder.encode(text);

      const cs = new CompressionStream('deflate-raw');
      const writer = cs.writable.getWriter();
      writer.write(data);
      writer.close();

      const reader = cs.readable.getReader();
      const chunks = [];
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        chunks.push(value);
      }
      const compressed = new Uint8Array(chunks.reduce((acc, c) => acc + c.length, 0));
      let offset = 0;
      for (const chunk of chunks) {
        compressed.set(chunk, offset);
        offset += chunk.length;
      }

      const map = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_';
      let result = '';
      for (let i = 0; i < compressed.length; i += 3) {
        const b1 = compressed[i];
        const b2 = i + 1 < compressed.length ? compressed[i + 1] : 0;
        const b3 = i + 2 < compressed.length ? compressed[i + 2] : 0;
        result += map[b1 >> 2];
        result += map[((b1 & 0x3) << 4) | (b2 >> 4)];
        result += map[((b2 & 0xF) << 2) | (b3 >> 6)];
        result += map[b3 & 0x3F];
      }
      return result;
    },

    _showPlantUMLError(container, msg) {
      container.innerHTML = '';
      const errBox = document.createElement('div');
      errBox.className = 'plantuml-error';
      errBox.innerHTML = '<strong>PlantUML</strong> — ' + msg;
      container.appendChild(errBox);
    },

    renderMermaid() {
      const mermaidBlocks = document.querySelectorAll('code.language-mermaid, pre code.language-mermaid');
      if (mermaidBlocks.length === 0) return;
      if (typeof mermaid === 'undefined') return;

      const { isDark, themeVariables } = MR._resolveThemeColors();

      mermaid.initialize({
        startOnLoad: false,
        securityLevel: 'loose',
        theme: isDark ? 'dark' : 'default',
        themeVariables
      });

      let idx = 0;
      mermaidBlocks.forEach(block => {
        const pre = block.parentElement;
        if (!pre || pre.tagName !== 'PRE') return;
        const source = block.textContent;
        const container = document.createElement('div');
        container.className = 'mermaid-container';
        container.dataset.mermaidSource = source;
        const id = 'mermaid-' + (++idx) + '-' + Math.random().toString(36).slice(2);
        mermaid.render(id, source).then(({ svg, bindFunctions }) => {
          container.innerHTML = svg;
          if (bindFunctions) bindFunctions(container);
        }).catch(err => {
          console.error('[MarkdownReader] mermaid.render error:', err);
          const detail = (err && err.message) ? String(err.message).substring(0, 200) : String(err).substring(0, 200);
          MR._showMermaidError(container, '渲染失败：' + detail);
        });
        pre.replaceWith(container);
      });
    },

    rerenderMermaid() {
      const containers = document.querySelectorAll('.mermaid-container');
      if (containers.length === 0) return;
      if (typeof mermaid === 'undefined') return;

      const { isDark, themeVariables } = MR._resolveThemeColors();

      mermaid.initialize({
        startOnLoad: false,
        securityLevel: 'loose',
        theme: isDark ? 'dark' : 'default',
        themeVariables
      });

      containers.forEach((container, idx) => {
        const source = container.dataset.mermaidSource;
        if (!source) return;
        const id = 'mermaid-re-' + idx + '-' + Math.random().toString(36).slice(2);
        container.innerHTML = '';
        mermaid.render(id, source).then(({ svg, bindFunctions }) => {
          container.innerHTML = svg;
          if (bindFunctions) bindFunctions(container);
        }).catch(err => {
          console.error('[MarkdownReader] mermaid rerender error:', err);
          const detail = (err && err.message) ? String(err.message).substring(0, 200) : String(err).substring(0, 200);
          MR._showMermaidError(container, '渲染失败：' + detail);
        });
      });
    },

    async _fetchPlantUMLSVG(source, serverUrl) {
      const encoded = await MR._encodePlantUML(source);
      const svgUrl = `${serverUrl}/svg/~1${encoded}`;
      const response = await fetch(svgUrl);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const text = await response.text();
      if (!text.trim().startsWith('<svg')) {
        throw new Error('服务器返回了无效的 SVG 内容');
      }
      return text;
    },

    _applyPlantUMLSVG(container, svgText) {
      container.innerHTML = svgText;
      const svgEl = container.querySelector('svg');
      if (svgEl) {
        svgEl.removeAttribute('width');
        svgEl.removeAttribute('height');
        svgEl.style.maxWidth = '100%';
        svgEl.style.height = 'auto';
      }
    },

    async renderPlantUML() {
      const plantumlBlocks = document.querySelectorAll('code.language-plantuml, pre code.language-plantuml, code.language-puml, pre code.language-puml');
      if (plantumlBlocks.length === 0) return;

      const serverUrl = 'https://www.plantuml.com/plantuml';

      const tasks = Array.from(plantumlBlocks).map(block => {
        const pre = block.parentElement;
        if (!pre || pre.tagName !== 'PRE') return Promise.resolve();

        const source = block.textContent;
        const container = document.createElement('div');
        container.className = 'plantuml-container';
        container.dataset.plantumlSource = source;

        container.innerHTML = '<div class="plantuml-loading">PlantUML...</div>';
        pre.replaceWith(container);

        return MR._fetchPlantUMLSVG(source, serverUrl)
          .then(svg => { MR._applyPlantUMLSVG(container, svg); })
          .catch(err => {
            console.error('[MarkdownReader] PlantUML render error:', err);
            MR._showPlantUMLError(container, '渲染失败：' + (err.message || String(err)).substring(0, 200));
          });
      });

      await Promise.all(tasks);
    },

    async rerenderPlantUML() {
      const containers = document.querySelectorAll('.plantuml-container');
      if (containers.length === 0) return;

      const serverUrl = 'https://www.plantuml.com/plantuml';

      const tasks = Array.from(containers).map(container => {
        const source = container.dataset.plantumlSource;
        if (!source) return Promise.resolve();
        container.innerHTML = '<div class="plantuml-loading">PlantUML...</div>';

        return MR._fetchPlantUMLSVG(source, serverUrl)
          .then(svg => { MR._applyPlantUMLSVG(container, svg); })
          .catch(err => {
            console.error('[MarkdownReader] PlantUML rerender error:', err);
            MR._showPlantUMLError(container, '渲染失败：' + (err.message || String(err)).substring(0, 200));
          });
      });

      await Promise.all(tasks);
    },

    renderKaTeX() {
      const mathElements = document.querySelectorAll('code.language-math, code.language-latex, code.language-katex');
      if (mathElements.length === 0) return;
      if (typeof katex === 'undefined') return;

      mathElements.forEach(block => {
        const pre = block.parentElement;
        const isInline = !pre || pre.tagName !== 'PRE';
        const mathContent = block.textContent;

        if (isInline) {
          const span = document.createElement('span');
          span.className = 'katex-inline';
          try {
            katex.render(mathContent, span, {
              displayMode: false,
              throwOnError: false,
              output: 'html'
            });
          } catch (e) {
            span.textContent = mathContent;
          }
          block.replaceWith(span);
        } else {
          const container = document.createElement('div');
          container.className = 'katex-display';
          try {
            katex.render(mathContent, container, {
              displayMode: true,
              throwOnError: false,
              output: 'html'
            });
          } catch (e) {
            container.textContent = mathContent;
          }
          pre.replaceWith(container);
        }
      });
    },

    renderAdmonitions() {
      const blockquotes = document.querySelectorAll('blockquote');
      const types = {
        'note': { icon: 'ℹ', label: 'Note' },
        'tip': { icon: '💡', label: 'Tip' },
        'warning': { icon: '⚠', label: 'Warning' },
        'caution': { icon: '🔥', label: 'Caution' },
        'important': { icon: '❗', label: 'Important' }
      };
      blockquotes.forEach(bq => {
        const firstP = bq.querySelector('p');
        if (!firstP) return;
        const text = firstP.textContent.trim();
        for (const [type, config] of Object.entries(types)) {
          const prefix = '[' + type.charAt(0).toUpperCase() + type.slice(1) + ']';
          if (text.startsWith(prefix)) {
            bq.classList.add('admonition', 'admonition-' + type);
            const titleSpan = document.createElement('span');
            titleSpan.className = 'admonition-title';
            titleSpan.textContent = config.label;
            const rest = text.slice(prefix.length).trim();
            if (rest) {
              firstP.textContent = rest;
            } else {
              firstP.remove();
            }
            bq.insertBefore(titleSpan, bq.firstChild);
            break;
          }
        }
      });
    },

    addCopyButtons() {
      const preBlocks = document.querySelectorAll('pre');
      preBlocks.forEach(pre => {
        if (pre.querySelector('.mr-copy-btn')) return;
        pre.style.position = 'relative';

        const btn = document.createElement('button');
        btn.className = 'mr-copy-btn';
        btn.type = 'button';
        btn.title = 'Copy';
        btn.innerHTML = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="5" width="9" height="9" rx="1.5"/><path d="M3 11V3a1.5 1.5 0 0 1 1.5-1.5H11"/></svg>';

        btn.addEventListener('click', function() {
          const code = pre.querySelector('code');
          const text = code ? code.textContent : pre.textContent;
          navigator.clipboard.writeText(text).then(() => {
            btn.classList.add('mr-copy-btn-copied');
            btn.innerHTML = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="3.5 8.5 6.5 11.5 12.5 5.5"/></svg>';
            setTimeout(() => {
              btn.classList.remove('mr-copy-btn-copied');
              btn.innerHTML = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="5" width="9" height="9" rx="1.5"/><path d="M3 11V3a1.5 1.5 0 0 1 1.5-1.5H11"/></svg>';
            }, 2000);
          }).catch(() => {
            const textarea = document.createElement('textarea');
            textarea.value = text;
            textarea.style.position = 'fixed';
            textarea.style.opacity = '0';
            document.body.appendChild(textarea);
            textarea.select();
            document.execCommand('copy');
            document.body.removeChild(textarea);
            btn.classList.add('mr-copy-btn-copied');
            btn.innerHTML = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="3.5 8.5 6.5 11.5 12.5 5.5"/></svg>';
            setTimeout(() => {
              btn.classList.remove('mr-copy-btn-copied');
              btn.innerHTML = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="5" width="9" height="9" rx="1.5"/><path d="M3 11V3a1.5 1.5 0 0 1 1.5-1.5H11"/></svg>';
            }, 2000);
          });
        });

        pre.appendChild(btn);
      });
    },

    _searchHighlights: [],

    highlightSearch(query, caseSensitive, wholeWord, currentIndex) {
      MR.clearSearchHighlight();
      if (!query) return 0;

      const content = document.getElementById('mr-content');
      if (!content) return 0;

      const flags = caseSensitive ? 'g' : 'gi';
      let pattern = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      if (wholeWord) pattern = '\\b' + pattern + '\\b';

      let regex;
      try {
        regex = new RegExp(pattern, flags);
      } catch (e) {
        return 0;
      }

      const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT, null);
      const textNodes = [];
      while (walker.nextNode()) {
        textNodes.push(walker.currentNode);
      }

      const allMatches = [];

      textNodes.forEach(node => {
        const text = node.textContent;
        let match;
        while ((match = regex.exec(text)) !== null) {
          allMatches.push({
            node: node,
            index: match.index,
            length: match[0].length
          });
        }
      });

      // Sort by document position in REVERSE order for safe insertion.
      // Processing from end to start prevents surroundContents from
      // splitting text nodes and invalidating later match offsets.
      const sortedAllMatches = allMatches.slice().sort((a, b) => {
        const cmp = a.node.compareDocumentPosition(b.node);
        if (cmp & Node.DOCUMENT_POSITION_FOLLOWING) return 1;  // b comes first → process b before a
        if (cmp & Node.DOCUMENT_POSITION_PRECEDING) return -1; // a comes first → process a before b
        return b.index - a.index; // same node: higher index first
      });

      // Collect mark elements in document order for indexing
      const markElements = [];

      // Use Range API to wrap matches in <mark> elements
      for (const m of sortedAllMatches) {
        const range = document.createRange();
        try {
          range.setStart(m.node, m.index);
          range.setEnd(m.node, m.index + m.length);
        } catch (e) {
          continue;
        }

        const mark = document.createElement('mark');
        mark.className = 'mr-search-highlight';

        try {
          range.surroundContents(mark);
          markElements.unshift(mark); // prepend to maintain document order
        } catch (e) {
          // surroundContents fails when range crosses element boundaries — skip
          continue;
        }
      }

      // Assign sequential indices in document order
      markElements.forEach((mark, i) => {
        mark.dataset.searchIndex = i;
      });
      MR._searchHighlights = markElements;

      const matchCount = markElements.length;

      // Highlight current match
      if (currentIndex >= 0 && currentIndex < matchCount) {
        const currentMark = content.querySelector(`mark[data-search-index="${currentIndex}"]`);
        if (currentMark) {
          currentMark.classList.add('mr-search-current');
          currentMark.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      }

      return matchCount;
    },

    setSearchCurrent(currentIndex) {
      const content = document.getElementById('mr-content');
      if (!content) return;
      const prev = content.querySelector('.mr-search-current');
      if (prev) prev.classList.remove('mr-search-current');
      if (currentIndex >= 0) {
        const mark = content.querySelector(`mark[data-search-index="${currentIndex}"]`);
        if (mark) {
          mark.classList.add('mr-search-current');
          mark.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      }
    },

    clearSearchHighlight() {
      for (const mark of MR._searchHighlights) {
        const parent = mark.parentNode;
        if (parent) {
          while (mark.firstChild) {
            parent.insertBefore(mark.firstChild, mark);
          }
          parent.removeChild(mark);
          parent.normalize();
        }
      }
      MR._searchHighlights = [];
    },

    // ===== CriticMarkup 选词标注 =====

    criticLabels: {
      delete: 'Delete', highlight: 'Highlight', comment: 'Comment', replace: 'Replace',
      confirm: 'Apply', cancel: 'Cancel', edit: 'Edit',
      commentHint: 'Add a comment…', replaceHint: 'Replace with…'
    },

    setCriticLabels(labels) {
      if (labels && typeof labels === 'object') {
        MR.criticLabels = Object.assign({}, MR.criticLabels, labels);
      }
    },

    // 用 CSS Custom Highlight API 给「正在标注」的选区上一层持久高亮，
    // 这样即使原生选区因为点击工具条/聚焦输入框而消失，用户也能看到刚选的位置。
    _setPendingHighlight(range) {
      try {
        if (!window.CSS || !CSS.highlights || typeof Highlight === 'undefined' || !range) return;
        MR._clearPendingHighlight();
        const hl = new Highlight(range.cloneRange());
        CSS.highlights.set('critic-pending', hl);
      } catch (e) { /* no-op */ }
    },

    _clearPendingHighlight() {
      try { if (window.CSS && CSS.highlights) CSS.highlights.delete('critic-pending'); } catch (e) { /* no-op */ }
    },

    _postCriticAction(op, text, line, payload) {
      try {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.criticAction) {
          window.webkit.messageHandlers.criticAction.postMessage({
            op: op, text: text, line: line, payload: payload || null
          });
        }
      } catch (e) { /* no-op */ }
    },

    _criticLineFor(node) {
      let el = (node && node.nodeType === 3) ? node.parentElement : node;
      while (el && el !== document.body) {
        if (el.dataset && el.dataset.line) {
          return parseInt(el.dataset.line) || 0;
        }
        el = el.parentElement;
      }
      return 0;
    },

    _ensureCriticToolbar() {
      let bar = document.getElementById('mr-critic-toolbar');
      if (bar) return bar;
      bar = document.createElement('div');
      bar.id = 'mr-critic-toolbar';
      document.body.appendChild(bar);
      // 普通模式下防止点击工具条按钮清除选区；输入模式（评论/替换）需允许聚焦输入框
      bar.addEventListener('mousedown', function(e) {
        if (!bar.classList.contains('critic-input-mode')) e.preventDefault();
      });
      return bar;
    },

    _hideCriticToolbar() {
      const bar = document.getElementById('mr-critic-toolbar');
      if (bar) bar.classList.remove('visible');
      MR._criticPending = null;
      MR._clearPendingHighlight();
    },

    _showCriticToolbar(range, text, line) {
      const bar = MR._ensureCriticToolbar();
      MR._criticPending = { text: text, line: line };
      MR._setPendingHighlight(range);
      const L = MR.criticLabels;
      bar.innerHTML = '';

      const mkBtn = (label, handler, primary) => {
        const b = document.createElement('button');
        b.textContent = label;
        if (primary) b.className = 'critic-primary';
        b.addEventListener('click', handler);
        return b;
      };

      bar.appendChild(mkBtn(L.delete, () => MR._commitCritic('delete')));
      bar.appendChild(mkBtn(L.highlight, () => MR._commitCritic('highlight')));
      bar.appendChild(mkBtn(L.comment, () => MR._promptCritic('comment', L.commentHint, true)));
      bar.appendChild(mkBtn(L.replace, () => MR._promptCritic('replace', L.replaceHint, false)));

      bar.classList.add('visible');
      MR._positionCriticToolbar(bar, range.getBoundingClientRect());
    },

    _positionCriticToolbar(bar, rect) {
      const barRect = bar.getBoundingClientRect();
      let top = rect.top - barRect.height - 8;
      if (top < 4) top = rect.bottom + 8;
      let left = rect.left + (rect.width / 2) - (barRect.width / 2);
      left = Math.max(4, Math.min(left, window.innerWidth - barRect.width - 4));
      bar.style.top = top + 'px';
      bar.style.left = left + 'px';
    },

    // op: 'comment'(多行 textarea) / 'replace'(单行 input)
    _promptCritic(op, hint, multiline) {
      const bar = document.getElementById('mr-critic-toolbar');
      if (!bar || !MR._criticPending) return;
      const L = MR.criticLabels;
      bar.classList.add('critic-input-mode');
      bar.innerHTML = '';

      const field = document.createElement(multiline ? 'textarea' : 'input');
      if (!multiline) field.type = 'text';
      field.className = 'critic-field';
      field.placeholder = hint;
      if (multiline) field.rows = 3;

      const confirm = document.createElement('button');
      confirm.textContent = L.confirm;
      confirm.className = 'critic-primary';
      const cancel = document.createElement('button');
      cancel.textContent = L.cancel;

      const submit = () => {
        const v = field.value.trim();
        if (op === 'comment' && !v) { MR._hideCriticToolbar(); return; }
        MR._commitCritic(op, field.value);
      };
      confirm.addEventListener('click', submit);
      cancel.addEventListener('click', () => MR._hideCriticToolbar());
      field.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); submit(); }
        else if (e.key === 'Enter' && !multiline) { e.preventDefault(); submit(); }
        else if (e.key === 'Escape') { e.preventDefault(); MR._hideCriticToolbar(); }
      });

      const row = document.createElement('div');
      row.className = 'critic-input-row';
      row.appendChild(field);
      const btns = document.createElement('div');
      btns.className = 'critic-input-btns';
      btns.appendChild(cancel);
      btns.appendChild(confirm);
      bar.appendChild(row);
      bar.appendChild(btns);
      // 重新定位（输入态尺寸变化）+ 聚焦
      if (MR._criticRange) MR._positionCriticToolbar(bar, MR._criticRange.getBoundingClientRect());
      setTimeout(() => field.focus(), 0);
    },

    _commitCritic(op, payload) {
      const p = MR._criticPending;
      if (!p) return;
      MR._postCriticAction(op, p.text, p.line, payload);
      const sel = window.getSelection();
      if (sel) sel.removeAllRanges();
      const bar = document.getElementById('mr-critic-toolbar');
      if (bar) bar.classList.remove('critic-input-mode');
      MR._hideCriticToolbar();
    },

    // ===== 已有评论：查看 / 编辑 / 删除 =====

    _ensureCommentPopover() {
      let pop = document.getElementById('mr-critic-popover');
      if (pop) return pop;
      pop = document.createElement('div');
      pop.id = 'mr-critic-popover';
      document.body.appendChild(pop);
      pop.addEventListener('mousedown', (e) => { e.stopPropagation(); });
      return pop;
    },

    _hideCommentPopover() {
      const pop = document.getElementById('mr-critic-popover');
      if (pop) pop.classList.remove('visible');
      MR._criticPopoverEl = null;
    },

    _positionCriticPopover(pop, rect) {
      const r = pop.getBoundingClientRect();
      let top = rect.bottom + 6;
      if (top + r.height > window.innerHeight - 4) top = Math.max(4, rect.top - r.height - 6);
      let left = rect.left + (rect.width / 2) - (r.width / 2);
      left = Math.max(4, Math.min(left, window.innerWidth - r.width - 4));
      pop.style.top = top + 'px';
      pop.style.left = left + 'px';
    },

    _showCommentPopover(el) {
      const pop = MR._ensureCommentPopover();
      MR._criticPopoverEl = el;
      const L = MR.criticLabels;
      const comment = el.dataset.comment || '';
      const line = MR._criticLineFor(el);
      pop.innerHTML = '';
      pop.classList.remove('critic-input-mode');

      const textBox = document.createElement('div');
      textBox.className = 'critic-popover-text';
      textBox.textContent = comment;

      const btns = document.createElement('div');
      btns.className = 'critic-input-btns';
      const editBtn = document.createElement('button');
      editBtn.textContent = L.edit;
      editBtn.className = 'critic-primary';
      const delBtn = document.createElement('button');
      delBtn.textContent = L.delete;
      delBtn.className = 'critic-danger';

      editBtn.addEventListener('click', () => MR._editCommentPopover(el, comment, line));
      delBtn.addEventListener('click', () => {
        MR._postCriticAction('deleteComment', comment, line, null);
        MR._hideCommentPopover();
      });

      btns.appendChild(delBtn);
      btns.appendChild(editBtn);
      pop.appendChild(textBox);
      pop.appendChild(btns);
      pop.classList.add('visible');
      MR._positionCriticPopover(pop, el.getBoundingClientRect());
    },

    _editCommentPopover(el, oldComment, line) {
      const pop = MR._ensureCommentPopover();
      const L = MR.criticLabels;
      pop.innerHTML = '';
      pop.classList.add('critic-input-mode');

      const field = document.createElement('textarea');
      field.className = 'critic-field';
      field.rows = 3;
      field.value = oldComment;

      const btns = document.createElement('div');
      btns.className = 'critic-input-btns';
      const cancel = document.createElement('button');
      cancel.textContent = L.cancel;
      const save = document.createElement('button');
      save.textContent = L.confirm;
      save.className = 'critic-primary';

      const submit = () => {
        const v = field.value.trim();
        if (!v) {
          MR._postCriticAction('deleteComment', oldComment, line, null);
        } else if (v !== oldComment) {
          MR._postCriticAction('editComment', oldComment, line, field.value);
        }
        MR._hideCommentPopover();
      };
      cancel.addEventListener('click', () => MR._hideCommentPopover());
      save.addEventListener('click', submit);
      field.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) { e.preventDefault(); submit(); }
        else if (e.key === 'Escape') { e.preventDefault(); MR._hideCommentPopover(); }
      });

      const row = document.createElement('div');
      row.className = 'critic-input-row';
      row.appendChild(field);
      btns.appendChild(cancel);
      btns.appendChild(save);
      pop.appendChild(row);
      pop.appendChild(btns);
      MR._positionCriticPopover(pop, el.getBoundingClientRect());
      setTimeout(() => { field.focus(); field.select(); }, 0);
    },

    _initCriticSelection() {
      const onSelectionChange = () => {
        // 输入态（评论/替换正在输入）时不刷新工具条
        const bar = document.getElementById('mr-critic-toolbar');
        if (bar && bar.classList.contains('critic-input-mode')) return;

        const sel = window.getSelection();
        if (!sel || sel.isCollapsed || sel.rangeCount === 0) {
          MR._hideCriticToolbar();
          return;
        }
        const text = sel.toString();
        if (!text || !text.trim()) { MR._hideCriticToolbar(); return; }

        const range = sel.getRangeAt(0);
        const content = document.getElementById('mr-content');
        if (!content || !content.contains(range.commonAncestorContainer)) {
          MR._hideCriticToolbar();
          return;
        }
        const rect = range.getBoundingClientRect();
        if (rect.width === 0 && rect.height === 0) { MR._hideCriticToolbar(); return; }
        MR._criticRange = range.cloneRange();
        const line = MR._criticLineFor(range.startContainer);
        MR._showCriticToolbar(range, text, line);
      };

      document.addEventListener('selectionchange', () => {
        clearTimeout(MR._criticSelTimer);
        MR._criticSelTimer = setTimeout(onSelectionChange, 120);
      });

      // 点击已有评论气泡 → 查看/编辑/删除
      document.addEventListener('click', (e) => {
        const bubble = e.target.closest && e.target.closest('.critic-comment');
        if (bubble) {
          e.preventDefault();
          e.stopPropagation();
          MR._showCommentPopover(bubble);
        }
      });

      // 点击空白处隐藏评论弹窗（点工具条/弹窗内部不隐藏）
      document.addEventListener('mousedown', (e) => {
        const pop = document.getElementById('mr-critic-popover');
        const bar = document.getElementById('mr-critic-toolbar');
        const inPop = pop && pop.contains(e.target);
        const inBar = bar && bar.contains(e.target);
        const onBubble = e.target.closest && e.target.closest('.critic-comment');
        if (!inPop && !onBubble) MR._hideCommentPopover();
        if (!inBar && !inPop) { /* 选区工具条由 selectionchange 控制 */ }
      });
    },

    init() {
      MR.renderMermaid();
      MR.renderPlantUML();
      MR.renderKaTeX();
      MR.renderAdmonitions();
      MR.addCopyButtons();
      MR._initCriticSelection();
      if (typeof Prism !== 'undefined') {
        Prism.highlightAll();
      }
    }
  };

  window.MR = MR;

  // ---- 滚动同步：通过 WKScriptMessageHandler 上报可见行 / 标题（替代旧 SwiftUI scrollGeometry 回调）----
  function postScrollSync() {
    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.scrollSync) {
        window.webkit.messageHandlers.scrollSync.postMessage({
          line: MR.getTopVisibleLine(),
          heading: MR.getVisibleHeading()
        });
      }
    } catch (e) { /* no-op */ }
  }

  let _mrScrollTimer = null;
  window.addEventListener('scroll', function() {
    if (_mrScrollTimer) clearTimeout(_mrScrollTimer);
    _mrScrollTimer = setTimeout(postScrollSync, 200);
  }, { passive: true });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', MR.init);
  } else {
    MR.init();
  }
})();
