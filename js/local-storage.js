// Local persistence in IndexedDB (this browser only). Falls back to an
// in-memory store if IndexedDB is unavailable, and reports that to the UI.
//
// Stores:
//   settings  { key, value }
//   documents { docId, title, name, pageCount, lastOpened }
//   sessions  { id, docId, startedAt, endedAt, aggregate }   aggregate = ReadingAggregator#toJSON()
//   notes     { id, docId, page, text, quote, source, edited, origin, createdAt, updatedAt }
//   analyses  { docId, data, meta, updatedAt }

const STORES = {
  settings: { keyPath: 'key' },
  documents: { keyPath: 'docId' },
  sessions: { keyPath: 'id', index: 'docId' },
  notes: { keyPath: 'id', index: 'docId' },
  analyses: { keyPath: 'docId' },
};

export const NOTE_SOURCES = ['ai', 'manual', 'demo'];

const reqP = (req) => new Promise((resolve, reject) => {
  req.onsuccess = () => resolve(req.result);
  req.onerror = () => reject(req.error);
});

function openDb(name) {
  return new Promise((resolve, reject) => {
    if (!('indexedDB' in globalThis)) { reject(new Error('IndexedDB not supported')); return; }
    const req = indexedDB.open(name, 1);
    req.onupgradeneeded = () => {
      const db = req.result;
      for (const [store, def] of Object.entries(STORES)) {
        if (db.objectStoreNames.contains(store)) continue;
        const os = db.createObjectStore(store, { keyPath: def.keyPath });
        if (def.index) os.createIndex(def.index, def.index);
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
    req.onblocked = () => reject(new Error('Database upgrade blocked by another tab'));
  });
}

class MemoryBackend {
  constructor() { this.data = Object.fromEntries(Object.keys(STORES).map((s) => [s, new Map()])); }
  async get(store, key) { return structuredClone(this.data[store].get(key)); }
  async put(store, value) { this.data[store].set(value[STORES[store].keyPath], structuredClone(value)); }
  async delete(store, key) { this.data[store].delete(key); }
  async byIndex(store, index, value) { return [...this.data[store].values()].filter((v) => v[index] === value).map((v) => structuredClone(v)); }
  async clear(store) { this.data[store].clear(); }
}

class IdbBackend {
  constructor(db) { this.db = db; }
  _store(store, mode) { return this.db.transaction(store, mode).objectStore(store); }
  get(store, key) { return reqP(this._store(store, 'readonly').get(key)); }
  put(store, value) { return reqP(this._store(store, 'readwrite').put(value)); }
  delete(store, key) { return reqP(this._store(store, 'readwrite').delete(key)); }
  byIndex(store, index, value) { return reqP(this._store(store, 'readonly').index(index).getAll(value)); }
  clear(store) { return reqP(this._store(store, 'readwrite').clear()); }
}

export class Store {
  constructor(name = 'focusnote') {
    this.name = name;
    this.backend = null;
    this.persistent = false;
    this.error = null;
  }

  async open() {
    try {
      this.backend = new IdbBackend(await openDb(this.name));
      this.persistent = true;
    } catch (e) {
      this.backend = new MemoryBackend();
      this.persistent = false;
      this.error = e;
    }
    return this;
  }

  close() { this.backend?.db?.close(); }

  // settings
  async getSetting(key, fallback = null) { const r = await this.backend.get('settings', key); return r ? r.value : fallback; }
  setSetting(key, value) { return this.backend.put('settings', { key, value }); }

  // documents
  getDocument(docId) { return this.backend.get('documents', docId); }
  saveDocument(doc) { return this.backend.put('documents', { ...doc, lastOpened: new Date().toISOString() }); }

  // sessions
  saveSession(session) { return this.backend.put('sessions', session); }
  async listSessions(docId) {
    return (await this.backend.byIndex('sessions', 'docId', docId)).sort((a, b) => (a.startedAt < b.startedAt ? -1 : 1));
  }
  deleteSession(id) { return this.backend.delete('sessions', id); }

  // notes
  async listNotes(docId) {
    return (await this.backend.byIndex('notes', 'docId', docId)).sort((a, b) => (a.createdAt < b.createdAt ? -1 : 1));
  }
  async saveNote(note) {
    const errs = validateNote(note);
    if (errs.length) throw new Error(`Invalid note: ${errs.join('; ')}`);
    const saved = { ...note, updatedAt: new Date().toISOString() };
    await this.backend.put('notes', saved);
    return saved;
  }
  deleteNote(id) { return this.backend.delete('notes', id); }

  // analyses (latest per document)
  getAnalysis(docId) { return this.backend.get('analyses', docId); }
  saveAnalysis(docId, data, meta) { return this.backend.put('analyses', { docId, data, meta, updatedAt: new Date().toISOString() }); }

  /** Removes everything FocusNote stored about one document. */
  async deleteDocumentData(docId) {
    for (const s of await this.backend.byIndex('sessions', 'docId', docId)) await this.backend.delete('sessions', s.id);
    for (const n of await this.backend.byIndex('notes', 'docId', docId)) await this.backend.delete('notes', n.id);
    await this.backend.delete('analyses', docId);
    await this.backend.delete('documents', docId);
  }

  /** Removes all FocusNote data in this browser, including consent and settings. */
  async deleteAll() {
    for (const store of Object.keys(STORES)) await this.backend.clear(store);
  }
}

export function createNote({ docId, text, page = null, quote = '', source = 'manual', origin = null }) {
  const now = new Date().toISOString();
  return {
    id: globalThis.crypto?.randomUUID?.() ?? `n-${Date.now()}-${Math.random().toString(36).slice(2)}`,
    docId, page, text: String(text ?? '').trim(), quote: String(quote ?? '').trim(),
    source, edited: false, origin, createdAt: now, updatedAt: now,
  };
}

export function validateNote(n) {
  const errs = [];
  if (!n || typeof n !== 'object') return ['not an object'];
  if (typeof n.id !== 'string' || !n.id) errs.push('id required');
  if (typeof n.docId !== 'string' || !n.docId) errs.push('docId required');
  if (typeof n.text !== 'string' || !n.text.trim()) errs.push('text required');
  if (n.page != null && !(Number.isInteger(n.page) && n.page >= 1)) errs.push('page must be a positive integer or null');
  if (!NOTE_SOURCES.includes(n.source)) errs.push(`source must be one of ${NOTE_SOURCES.join(', ')}`);
  return errs;
}
