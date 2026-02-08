/**
 * IndexedDB Data Store
 * Stores CSV/Excel datasets in the browser's IndexedDB.
 * Key: "userId_designId" or "userId_unassigned"
 * Value: { storeKey, columns, rows, totalRows, createdAt }
 *
 * Feature-detect: Falls back to in-memory Map if IndexedDB is unavailable.
 */

const DB_NAME = 'qr_label_data'
const DB_VERSION = 1
const STORE_NAME = 'datasets'

let db = null
let fallbackMap = null

function makeKey(userId, designId) {
  return `${userId}_${designId || 'unassigned'}`
}

function openDB() {
  if (db) return Promise.resolve(db)

  if (typeof indexedDB === 'undefined' || !indexedDB) {
    console.warn('IndexedDB not available, using in-memory fallback')
    fallbackMap = fallbackMap || new Map()
    return Promise.resolve(null)
  }

  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION)

    request.onupgradeneeded = (event) => {
      const idb = event.target.result
      if (!idb.objectStoreNames.contains(STORE_NAME)) {
        idb.createObjectStore(STORE_NAME, { keyPath: 'storeKey' })
      }
    }

    request.onsuccess = (event) => {
      db = event.target.result
      resolve(db)
    }

    request.onerror = (event) => {
      console.warn('IndexedDB open failed, using in-memory fallback:', event.target.error)
      fallbackMap = fallbackMap || new Map()
      resolve(null)
    }
  })
}

function idbPut(record) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite')
    const store = tx.objectStore(STORE_NAME)
    const request = store.put(record)
    request.onsuccess = () => resolve()
    request.onerror = (e) => reject(e.target.error)
  })
}

function idbGet(key) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readonly')
    const store = tx.objectStore(STORE_NAME)
    const request = store.get(key)
    request.onsuccess = () => resolve(request.result || null)
    request.onerror = (e) => reject(e.target.error)
  })
}

function idbDelete(key) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite')
    const store = tx.objectStore(STORE_NAME)
    const request = store.delete(key)
    request.onsuccess = () => resolve()
    request.onerror = (e) => reject(e.target.error)
  })
}

function idbClearAll() {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite')
    const store = tx.objectStore(STORE_NAME)
    const request = store.clear()
    request.onsuccess = () => resolve()
    request.onerror = (e) => reject(e.target.error)
  })
}

/**
 * Store a dataset for a user+design.
 */
export async function putDataset(userId, designId, columns, rows) {
  const idb = await openDB()
  const key = makeKey(userId, designId)
  const record = {
    storeKey: key,
    columns,
    rows,
    totalRows: rows.length,
    createdAt: Date.now()
  }

  if (idb) {
    await idbPut(record)
  } else {
    fallbackMap.set(key, record)
  }
}

/**
 * Get full dataset: { columns, rows, totalRows }
 */
export async function getDataset(userId, designId) {
  const idb = await openDB()
  const key = makeKey(userId, designId)

  let record
  if (idb) {
    record = await idbGet(key)
  } else {
    record = fallbackMap.get(key) || null
  }

  if (!record) return null
  return { columns: record.columns, rows: record.rows, totalRows: record.totalRows }
}

/**
 * Get a single row by index.
 */
export async function getRow(userId, designId, index) {
  const dataset = await getDataset(userId, designId)
  if (!dataset || index < 0 || index >= dataset.rows.length) return null
  return dataset.rows[index]
}

/**
 * Get metadata only (no rows): { columns, totalRows }
 */
export async function getMetadata(userId, designId) {
  const idb = await openDB()
  const key = makeKey(userId, designId)

  let record
  if (idb) {
    record = await idbGet(key)
  } else {
    record = fallbackMap.get(key) || null
  }

  if (!record) return null
  return { columns: record.columns, totalRows: record.totalRows }
}

/**
 * Check if a dataset exists.
 */
export async function hasDataset(userId, designId) {
  const meta = await getMetadata(userId, designId)
  return meta !== null && meta.totalRows > 0
}

/**
 * Move dataset from unassigned to a specific design ID.
 */
export async function associateDataset(userId, designId) {
  const idb = await openDB()
  const sourceKey = makeKey(userId, null)
  const targetKey = makeKey(userId, designId)

  if (idb) {
    const record = await idbGet(sourceKey)
    if (record) {
      record.storeKey = targetKey
      await idbPut(record)
      await idbDelete(sourceKey)
    }
  } else {
    const record = fallbackMap.get(sourceKey)
    if (record) {
      record.storeKey = targetKey
      fallbackMap.set(targetKey, record)
      fallbackMap.delete(sourceKey)
    }
  }
}

/**
 * Delete a dataset.
 */
export async function clearDataset(userId, designId) {
  const idb = await openDB()
  const key = makeKey(userId, designId)

  if (idb) {
    await idbDelete(key)
  } else {
    fallbackMap.delete(key)
  }
}

/**
 * Clear all datasets (e.g., on logout).
 */
export async function clearAll() {
  const idb = await openDB()

  if (idb) {
    await idbClearAll()
  } else {
    fallbackMap.clear()
  }
}
