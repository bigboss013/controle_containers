const API_KEY = 'AIzaSyCje8V9yQcgJ6LJL1AhyViKq8ArtjARsRA';
const PROJECT = 'santos-transportes';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

async function fetchWithRetry(url, options, retries = 3) {
  for (let i = 0; i < retries; i++) {
    const resp = await fetch(url, options);
    if (resp.status === 429) {
      const wait = 1000 * Math.pow(4, i);
      await new Promise(r => setTimeout(r, wait));
      continue;
    }
    return resp;
  }
  throw new Error('Servidor ocupado. Tente novamente em alguns segundos.');
}

const FirestoreRest = {
  async getDoc(collection, id) {
    const url = `${BASE}/${collection}/${id}?key=${API_KEY}`;
    const resp = await fetchWithRetry(url);
    if (resp.status === 404) return null;
    if (!resp.ok) throw new Error(`Firestore error ${resp.status}`);
    const doc = await resp.json();
    return this._parseDoc(doc);
  },

  async getCollection(collection) {
    const url = `${BASE}/${collection}?key=${API_KEY}`;
    const resp = await fetchWithRetry(url);
    if (!resp.ok) throw new Error(`Firestore error ${resp.status}`);
    const data = await resp.json();
    return (data.documents || []).map(d => this._parseDoc(d));
  },

  async addDoc(collection, data) {
    const url = `${BASE}/${collection}?key=${API_KEY}`;
    const resp = await fetchWithRetry(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(this._toFirestoreFields(data)),
    });
    if (!resp.ok) throw new Error(`Firestore error ${resp.status}`);
    return await resp.json();
  },

  async setDoc(collection, id, data) {
    const url = `${BASE}/${collection}/${id}?key=${API_KEY}`;
    const resp = await fetchWithRetry(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(this._toFirestoreFields(data)),
    });
    if (!resp.ok) throw new Error(`Firestore error ${resp.status}`);
    return await resp.json();
  },

  async deleteDoc(collection, id) {
    const url = `${BASE}/${collection}/${id}?key=${API_KEY}`;
    const resp = await fetchWithRetry(url, { method: 'DELETE' });
    if (!resp.ok) throw new Error(`Firestore error ${resp.status}`);
  },

  async queryCollection(collection, field, op, value) {
    const url = `${BASE}/${collection}?key=${API_KEY}`;
    const structuredQuery = {
      from: [{ collectionId: collection }],
      where: {
        fieldFilter: {
          field: { fieldPath: field },
          op: op,
          value: this._toFirestoreValue(value),
        },
      },
    };
    const resp = await fetchWithRetry(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ structuredQuery }),
    });
    if (!resp.ok) throw new Error(`Firestore error ${resp.status}`);
    const data = await resp.json();
    return (data.documents || []).map(d => this._parseDoc(d));
  },

  _parseDoc(doc) {
    const id = doc.name.split('/').pop();
    const fields = {};
    if (doc.fields) {
      for (const [k, v] of Object.entries(doc.fields)) {
        fields[k] = this._fromFirestoreValue(v);
      }
    }
    return { id, ...fields };
  },

  _fromFirestoreValue(v) {
    if (v.stringValue !== undefined) return v.stringValue;
    if (v.integerValue !== undefined) return parseInt(v.integerValue);
    if (v.doubleValue !== undefined) return parseFloat(v.doubleValue);
    if (v.booleanValue !== undefined) return v.booleanValue;
    if (v.timestampValue !== undefined) return new Date(v.timestampValue);
    if (v.nullValue !== undefined) return null;
    if (v.arrayValue) return (v.arrayValue.values || []).map(x => this._fromFirestoreValue(x));
    if (v.mapValue) {
      const obj = {};
      for (const [k, val] of Object.entries(v.mapValue.fields || {})) {
        obj[k] = this._fromFirestoreValue(val);
      }
      return obj;
    }
    return v;
  },

  _toFirestoreFields(obj) {
    const fields = {};
    for (const [k, v] of Object.entries(obj)) {
      fields[k] = this._toFirestoreValue(v);
    }
    return { fields };
  },

  _toFirestoreValue(v) {
    if (v === null || v === undefined) return { nullValue: null };
    if (typeof v === 'string') return { stringValue: v };
    if (typeof v === 'number') {
      return Number.isInteger(v) ? { integerValue: v } : { doubleValue: v };
    }
    if (typeof v === 'boolean') return { booleanValue: v };
    if (v instanceof Date) return { timestampValue: v.toISOString() };
    if (Array.isArray(v)) return { arrayValue: { values: v.map(x => this._toFirestoreValue(x)) } };
    if (typeof v === 'object') {
      const fields = {};
      for (const [k, val] of Object.entries(v)) {
        fields[k] = this._toFirestoreValue(val);
      }
      return { mapValue: { fields } };
    }
    return { stringValue: String(v) };
  },
};
