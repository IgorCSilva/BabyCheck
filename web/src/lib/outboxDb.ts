// A minimal promise wrapper around IndexedDB, just enough for the offline
// outbox queue (get all pending entries, add one, remove one) — not a
// general-purpose IndexedDB library. Raw IndexedDB rather than a dependency
// (e.g. idb) to match this app's existing lean-dependency style (the only
// other persistence here is plain localStorage, for locale and active baby).
const DB_NAME = "babycheck-outbox";
const DB_VERSION = 1;
const STORE_NAME = "pending_logs";

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = () => {
      request.result.createObjectStore(STORE_NAME, { keyPath: "tempId" });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function withStore<T>(
  mode: IDBTransactionMode,
  run: (store: IDBObjectStore) => IDBRequest<T>,
): Promise<T> {
  const db = await openDb();
  try {
    return await new Promise<T>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, mode);
      const request = run(tx.objectStore(STORE_NAME));
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  } finally {
    db.close();
  }
}

export const outboxDb = {
  getAll<T>(): Promise<T[]> {
    return withStore("readonly", (store) => store.getAll());
  },

  put<T>(entry: T): Promise<void> {
    return withStore("readwrite", (store) => store.put(entry)).then(() => undefined);
  },

  remove(tempId: number): Promise<void> {
    return withStore("readwrite", (store) => store.delete(tempId)).then(() => undefined);
  },
};
