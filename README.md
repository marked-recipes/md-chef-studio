# 👨‍🍳 MD Chef Studio (Markdown Recipe Studio)

A sleek Flutter Web application for maintaining, creating, editing, and deleting cooking recipes in the Markdown format of the official [`marked-recipes/recipes`](https://github.com/marked-recipes/recipes) repository (or any personal fork). "MD" stands for Markdown!

Includes an **AI Recipe Studio** that extracts structured recipes from **PDFs, HTML files, Web URLs (URIs), and text** using:
1. 🌐 **In-Browser WASM / WebGPU**: Run Google **Gemma 4 / 2B** or IBM **Granite 4.2 / 3B** models directly in your browser tab without sending recipe data to a server!
2. 💻 **Local AI (Ollama)**: Connect to your local Ollama instance (`http://localhost:11434`) running `gemma4`, `granite4.2`, `granite3-dense`, `llama3.2`, etc.
3. ☁️ **Remote Cloud AI**: Google Gemini API (`gemini-2.0-flash`, `gemini-1.5-flash`) or OpenAI / OpenRouter (`ibm/granite-3-8b-instruct`, `google/gemma-2-9b-it`).
4. 🚀 **Deployable to Netlify** with pre-configured `netlify.toml`, SPA redirects, and WASM/WebGPU cross-origin isolation headers.

---

## 🌟 Key Features

### 1. Direct Git & GitHub Repository Management
- **Connect any Repo or Fork**: Defaults to [`marked-recipes/recipes`](https://github.com/marked-recipes/recipes), or connect your own fork.
- **One-Click Forking**: Click "Fork to My Account" in the Git Settings dialog to instantly create a fork under your GitHub profile via the GitHub REST API.
- **Full CRUD with Git Commits**:
  - **Add Recipes**: Visual form editor with drag-and-drop reordering for ingredients, instructions, and section headers, or raw Markdown editor with auto-slug generation.
  - **Edit Recipes**: Modify frontmatter, drag-and-drop reorder ingredients, steps, or section headers, and push atomic commits.
  - **Delete Recipes**: Remove recipes from the repository with custom commit messages.
- **Personal Access Token (PAT) Integration**: Securely stored in browser LocalStorage (`SharedPreferences`). Supports fine-grained and classic tokens.

### 2. Format Conformance with `marked-recipes/recipes`
Recipes adhere strictly to the MarkedChef format, including support for **Markdown section headers** (`### Section Title`) in both Ingredients and Instructions:
```markdown
---
title: Pizza
prep_time: 24 hours+
cook_time: 7-10 minutes
servings: 4
difficulty: Medium
tags:
  - italian
  - pizza
credit: Carl
---

## Ingredients

### Dough
- [ ] 170g (6oz) 'zero zero' or all-purpose flour
- [ ] 100ml / 3.5 oz water
- [ ] 1 pinch fresh yeast (0.5g)

### Toppings
- [ ] 100g fresh mozzarella cheese
- [ ] 80g crushed San Marzano tomatoes
- [ ] Fresh basil leaves

## Instructions

### Dough
- [ ] Melt yeast in half a cup of water.
- [ ] Mix flour and water into a smooth, elastic ball and knead 10-15 minutes.
- [ ] Let rest covered for 24 hours at room temperature.

### Assembly & Baking
- [ ] Stretch dough by hand into a round with a thicker border.
- [ ] Spread crushed tomatoes, top with torn mozzarella, and bake at 500°F (260°C) for 7-10 minutes.
- [ ] Finish with fresh basil and extra virgin olive oil.

## Notes
* A pizza stone or steel preheated for 45 minutes yields the crispiest crust.
```

### 3. Local Caching & Git Delta-Sync Engine
- **Instant Offline-First Load**: All repository recipes are cached in browser local storage (`RecipeCacheService`). When opening the app or switching repositories, recipes render in **<10ms** with zero network delay.
- **Git Blob SHA Delta Sync**: During synchronization, the app fetches the remote Git tree (`GET /git/trees/{branch}?recursive=1`) and compares remote blob SHAs against the local cache manifest:
  - **Unchanged files**: Reused directly from local cache (**0 network bytes downloaded**).
  - **Modified or added files**: Only the specific changed recipes are downloaded and updated in the cache.
  - **Deleted files**: Cleaned from the local cache and view.
- **Offline Mode**: If the device loses internet or GitHub rate limits apply, the app seamlessly runs using the local offline cache.
- **Cache Controls**: Dedicated panel in Git Settings with cached recipe counts, "Check for Git Changes", "Force Full Re-read", and "Clear Local Cache".

### 4. Multi-Engine AI Recipe Extractor
- **Inputs Supported**:
  - 📄 **Cookbook PDFs**: Browser-native text extraction using Mozilla's PDF.js.
  - 🌐 **Web URIs / URLs**: Automatic URL fetching with built-in CORS proxy fallback (`corsproxy.io` and `allorigins`).
  - 📄 **HTML Pages & DOM**: Strips ads, navigation, and boilerplate, extracting clean recipes and Schema.org `Recipe` JSON-LD.
  - ✍️ **Raw Text / Transcripts**: Paste raw text, cooking notes, or OCR text.
- **AI Engines**:
  - **In-Browser WASM / WebGPU**: WebLLM engine executing **Gemma 4/2B** (`gemma-2-2b-it-q4f16_1-MLC`) and **Granite 4.2/3B** (`granite-3.0-2b-instruct-q4f16_1-MLC`) with WebGPU acceleration and download progress tracking.
  - **Local Ollama**: Fast local inference at `http://localhost:11434`.
  - **Remote Cloud AI**: Google Gemini & OpenRouter / OpenAI.
- **Review & Commit**: After extraction, preview the generated recipe and open it in the editor with one click to commit it to your Git repository.

### 5. Interactive Cooking Mode & Sleek Interface
- **Cuisine Dropdown with Recipe Counts**: Compact dropdown filter displaying dynamic counts (e.g. `All Cuisines (18)`, `Pasta (6)`, `Soup (4)`), matching `mdchef.moscait.com`.
- **Markdown Section Headers**: Renders grouped ingredient and instruction stages (`### Dough`, `### Sauce`) as headers without checkboxes, keeping checklist numbering and progress bars accurate.
- **Interactive Checklists**: Cross off ingredients as you prepare them.
- **Step-by-Step Instruction Tracking**: Interactive checkboxes with a real-time progress bar.
- **Instant Search**: Search by title, ingredient, category, or tag.
- **Exporting**: Download any recipe directly as a `.md` file or copy raw Markdown to clipboard.
- **Modern Culinary Theme**: Tailored Light and Dark themes with typography using Google Fonts (Outfit & Inter).

---

## 🚀 Running Locally

### Prerequisites
- Flutter SDK (3.24+ recommended, stable channel)
- Google Chrome or Chromium-based browser (for WebGPU and PDF.js support)

### Start Development Server
```bash
# Get dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome
```

### Run Tests
```bash
flutter test
```

---

## 🌐 Deploying to Netlify

The repository is pre-configured with [`netlify.toml`](netlify.toml) and [`build.sh`](build.sh).

### Option A: Connect GitHub to Netlify (Recommended)
1. Push this repository to GitHub:
   ```bash
   git remote add origin https://github.com/<your-username>/md-chef-studio.git
   git branch -M main
   git push -u origin main
   ```
2. Log in to [Netlify](https://app.netlify.com/) and click **"Add new site" > "Import an existing project"**.
3. Select your repository.
4. Netlify will automatically detect `netlify.toml`:
   - **Build command**: `./build.sh`
   - **Publish directory**: `build/web`
5. Click **"Deploy site"**!

### Option B: Deploy Pre-built Web Assets
You can build locally and deploy directly via the Netlify CLI:
```bash
# Build release web app
flutter build web --release

# Deploy with Netlify CLI
npx netlify-cli deploy --prod --dir=build/web
```

### WASM & WebGPU Headers
[`netlify.toml`](netlify.toml) automatically sets the required headers for WebAssembly multi-threading, `SharedArrayBuffer`, and WebGPU:
```toml
[[headers]]
  for = "/*"
  [headers.values]
    Cross-Origin-Embedder-Policy = "credentialless"
    Cross-Origin-Opener-Policy = "same-origin"
```

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point & MultiProvider setup
├── models/
│   ├── recipe.dart                    # MarkedChef Recipe model (parser & serializer)
│   ├── git_repo_config.dart           # Git repo settings & GitHub PAT config
│   └── ai_config.dart                 # AI engine configurations (WASM, Ollama, Cloud)
├── providers/
│   ├── recipe_provider.dart           # State management for repository recipes & CRUD
│   ├── extraction_provider.dart       # State management for AI extraction pipeline
│   └── settings_provider.dart         # User settings & GitHub auth verification
├── services/
│   ├── ai_service.dart                # Orchestrator & prompt craft for MarkedChef format
│   ├── github_service.dart            # GitHub REST API (tree, commits, delete, fork)
│   ├── recipe_cache_service.dart      # Offline local caching & Git blob SHA delta-sync
│   ├── content_extractor_service.dart # PDF, HTML, URL, & text extraction
│   ├── in_browser_wasm_service.dart   # In-browser WASM/WebLLM AI execution
│   ├── local_ollama_service.dart      # Local Ollama REST client
│   ├── remote_ai_service.dart         # Google Gemini & OpenRouter clients
│   ├── storage_service.dart           # LocalStorage / SharedPreferences persistence
│   └── web_interop/
│       ├── web_bridge.dart            # Conditional export for Web vs VM
│       ├── web_bridge_stub.dart       # VM stub for unit tests
│       └── web_bridge_web.dart        # Browser WebGPU, PDF.js, & DOM JS interop
├── theme/
│   └── app_theme.dart                 # Sleek dark and light culinary studio themes
└── ui/
    ├── home_page.dart                 # Responsive master-detail studio interface
    └── widgets/
        ├── ai_extractor_dialog.dart   # Studio dialog for extracting recipes from sources
        ├── ai_settings_dialog.dart    # AI provider configuration dialog
        ├── category_filter_bar.dart   # Cuisine dropdown with counts & search bar
        ├── commit_dialog.dart         # Commit message modal before pushing to Git
        ├── git_settings_dialog.dart   # GitHub connection, fork wizard & cache controls
        ├── recipe_card.dart           # Recipe preview card with metadata pills
        ├── recipe_editor_dialog.dart  # Form & raw Markdown dual-mode editor
        └── recipe_view_pane.dart      # Interactive cooking canvas with checklist
```

---

## 📄 License
MIT
