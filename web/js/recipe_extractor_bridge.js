/**
 * md-chef-studio Web Bridge
 * Handles PDF text extraction, HTML parsing, Web Fetching with CORS fallback,
 * and In-Browser WASM / WebLLM AI execution (Gemma & Granite models).
 */

(function () {
  console.log('[md-chef-studio] Initializing Web Bridge...');

  // Helper to extract text in visual reading order from PDF.js textContent
  function processPdfTextContent(textContent) {
    if (!textContent || !textContent.items || textContent.items.length === 0) {
      return '';
    }

    const items = textContent.items.filter((item) => item && typeof item.str === 'string');
    if (items.length === 0) return '';

    // Transform matrix: [scaleX, skewY, skewX, scaleY, tx, ty]
    // In PDF coordinates, (0,0) is at bottom-left. Larger ty is higher up on the page.
    const itemsWithCoords = items.map((item) => {
      const tx = item.transform ? item.transform[4] : 0;
      const ty = item.transform ? item.transform[5] : 0;
      const width = item.width || 0;
      const height = item.height || Math.abs(item.transform ? item.transform[3] : 0) || 12;
      return {
        str: item.str,
        x: tx,
        y: ty,
        width: width,
        height: height,
      };
    });

    // Sort primarily by Y descending (top to bottom), secondarily by X ascending (left to right)
    itemsWithCoords.sort((a, b) => {
      const yDiff = b.y - a.y;
      if (Math.abs(yDiff) <= 4.0) {
        return a.x - b.x;
      }
      return yDiff;
    });

    // Group items into visual lines
    const lines = [];
    let currentLine = [];
    let currentLineY = null;

    for (const item of itemsWithCoords) {
      if (item.str === '') continue;

      if (currentLineY === null) {
        currentLine.push(item);
        currentLineY = item.y;
      } else if (Math.abs(currentLineY - item.y) <= 4.0) {
        currentLine.push(item);
      } else {
        currentLine.sort((a, b) => a.x - b.x);
        lines.push({ y: currentLineY, items: currentLine });
        currentLine = [item];
        currentLineY = item.y;
      }
    }

    if (currentLine.length > 0) {
      currentLine.sort((a, b) => a.x - b.x);
      lines.push({ y: currentLineY, items: currentLine });
    }

    // Assemble text from lines with newline and paragraph gap detection
    let pageText = '';
    let prevY = null;

    for (let i = 0; i < lines.length; i++) {
      const lineObj = lines[i];
      let lineStr = '';
      let prevItemEnd = null;

      for (const item of lineObj.items) {
        if (lineStr.length > 0) {
          const needsSpace =
            !lineStr.endsWith(' ') &&
            !item.str.startsWith(' ') &&
            (prevItemEnd === null || item.x - prevItemEnd > 1.5);
          if (needsSpace) {
            lineStr += ' ';
          }
        }
        lineStr += item.str;
        prevItemEnd = item.x + item.width;
      }

      lineStr = lineStr.trim();
      if (lineStr.length === 0) continue;

      if (prevY !== null) {
        const yGap = prevY - lineObj.y;
        if (yGap > 22.0) {
          pageText += '\n\n';
        } else {
          pageText += '\n';
        }
      }

      pageText += lineStr;
      prevY = lineObj.y;
    }

    return pageText;
  }

  // 1. PDF Text Extraction using PDF.js
  window.extractTextFromPdfBytes = async function (uint8ArrayData) {
    try {
      if (typeof pdfjsLib === 'undefined') {
        throw new Error('PDF.js library is not loaded.');
      }
      const loadingTask = pdfjsLib.getDocument({ data: uint8ArrayData });
      const pdf = await loadingTask.promise;
      let fullText = '';

      for (let pageNum = 1; pageNum <= pdf.numPages; pageNum++) {
        const page = await pdf.getPage(pageNum);
        const textContent = await page.getTextContent();
        const pageText = processPdfTextContent(textContent);
        if (pageText.trim()) {
          fullText += `--- Page ${pageNum} ---\n` + pageText + '\n\n';
        }
      }

      return fullText.trim();
    } catch (err) {
      console.error('PDF extraction failed:', err);
      throw err;
    }
  };

  // 2. HTML Text and Content Extraction
  window.extractTextFromHtml = function (htmlContent) {
    try {
      const parser = new DOMParser();
      const doc = parser.parseFromString(htmlContent, 'text/html');

      // Remove unwanted elements
      const elementsToRemove = doc.querySelectorAll(
        'script, style, svg, noscript, nav, header, footer, iframe, ads, .advertisement, [aria-hidden="true"]'
      );
      elementsToRemove.forEach((el) => el.remove());

      // Attempt to look for recipe-specific microdata (schema.org/Recipe)
      const recipeJsonLd = doc.querySelectorAll('script[type="application/ld+json"]');
      let structuredRecipe = '';
      recipeJsonLd.forEach((tag) => {
        try {
          const data = JSON.parse(tag.textContent);
          const recipes = Array.isArray(data) ? data : [data];
          recipes.forEach((item) => {
            const recipeObj = item['@type'] === 'Recipe' ? item : (item['@graph'] ? item['@graph'].find(g => g['@type'] === 'Recipe') : null);
            if (recipeObj) {
              structuredRecipe += `\n[Structured Recipe Found]:\nTitle: ${recipeObj.name || ''}\nPrep: ${recipeObj.prepTime || ''}\nCook: ${recipeObj.cookTime || ''}\nServings: ${recipeObj.recipeYield || ''}\nIngredients: ${JSON.stringify(recipeObj.recipeIngredient || [])}\nInstructions: ${JSON.stringify(recipeObj.recipeInstructions || [])}\n`;
            }
          });
        } catch (e) {
          // ignore invalid json-ld
        }
      });

      // Get readable text from body or article
      const contentRoot = doc.querySelector('article, main, [role="main"]') || doc.body;
      let text = (contentRoot ? contentRoot.innerText || contentRoot.textContent : doc.body.innerText) || '';

      // Normalize multiple whitespace and linebreaks
      text = text.replace(/[ \t]+/g, ' ').replace(/\n\s*\n\s*\n+/g, '\n\n').trim();

      if (structuredRecipe) {
        return structuredRecipe + '\n\n=== Raw Page Content ===\n' + text;
      }
      return text;
    } catch (err) {
      console.error('HTML extraction error:', err);
      return htmlContent;
    }
  };

  // 3. Web Fetch with Transparent CORS Fallback Proxies
  window.fetchUrlContent = async function (url) {
    // Try direct fetch first
    try {
      const res = await fetch(url, { headers: { 'Accept': 'text/html,application/xhtml+xml,text/plain' } });
      if (res.ok) {
        const text = await res.text();
        return window.extractTextFromHtml(text);
      }
    } catch (e) {
      console.warn('Direct fetch failed due to CORS or network; attempting CORS fallback proxies...', e);
    }

    // Try CORS proxy 1: corsproxy.io
    try {
      const proxyUrl1 = `https://corsproxy.io/?${encodeURIComponent(url)}`;
      const res1 = await fetch(proxyUrl1);
      if (res1.ok) {
        const text = await res1.text();
        return window.extractTextFromHtml(text);
      }
    } catch (e1) {
      console.warn('CORS proxy 1 failed:', e1);
    }

    // Try CORS proxy 2: allorigins.win
    try {
      const proxyUrl2 = `https://api.allorigins.win/raw?url=${encodeURIComponent(url)}`;
      const res2 = await fetch(proxyUrl2);
      if (res2.ok) {
        const text = await res2.text();
        return window.extractTextFromHtml(text);
      }
    } catch (e2) {
      console.warn('CORS proxy 2 failed:', e2);
    }

    throw new Error('Failed to fetch the URL. The target site blocked proxy access or CORS is strictly enforced. You can paste the page text or HTML directly.');
  };

  // 4. In-Browser WASM / WebGPU / WebLLM Engine
  window.chefWebLLM = {
    engine: null,
    currentModelId: null,
    isInitializing: false,
    progressText: '',
    progressPercent: 0,

    isWebGPUSupported: function () {
      return !!(navigator.gpu);
    },

    loadModel: async function (modelId, onProgress) {
      this.currentModelId = modelId;
      this.isInitializing = true;
      this.progressText = 'Starting model loader...';
      this.progressPercent = 0.05;
      if (onProgress) onProgress(0.05, 'Checking WebGPU / WebAssembly support...');

      try {
        if (!navigator.gpu) {
          throw new Error('WebGPU is not enabled or supported in this browser. Please use Chrome 113+, Edge 113+, or enable WebGPU flags in browser settings.');
        }

        // Dynamically import WebLLM from esm
        const webllm = await import('https://esm.run/@mlc-ai/web-llm');

        const initProgressCallback = (report) => {
          console.log('[WebLLM Progress]:', report.text);
          this.progressText = report.text;
          const match = report.text.match(/\[(\d+)\/(\d+)\]/);
          if (match) {
            this.progressPercent = parseInt(match[1], 10) / parseInt(match[2], 10);
          } else if (report.progress) {
            this.progressPercent = report.progress;
          }
          if (onProgress) onProgress(this.progressPercent, report.text);

          // Dispatch event for Dart listener
          window.dispatchEvent(new CustomEvent('chef_webllm_progress', {
            detail: { progress: this.progressPercent, text: report.text }
          }));
        };

        this.engine = await webllm.CreateMLCEngine(modelId, {
          initProgressCallback: initProgressCallback,
        });

        this.isInitializing = false;
        this.progressText = 'Model loaded successfully';
        this.progressPercent = 1.0;
        if (onProgress) onProgress(1.0, 'Ready');
        return true;
      } catch (err) {
        this.isInitializing = false;
        console.error('Failed to load WebLLM model:', err);
        throw err;
      }
    },

    generate: async function (prompt, systemPrompt, temperature) {
      if (!this.engine) {
        throw new Error('WebLLM model is not loaded. Please initialize the model first.');
      }

      const messages = [];
      if (systemPrompt) {
        messages.push({ role: 'system', content: systemPrompt });
      }
      messages.push({ role: 'user', content: prompt });

      const reply = await this.engine.chat.completions.create({
        messages: messages,
        temperature: temperature || 0.3,
        max_tokens: 2048,
      });

      return reply.choices[0].message.content;
    }
  };

  console.log('[md-chef-studio] Web Bridge ready.');
})();
