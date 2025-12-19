import type { FileNode } from '$lib/types/files'

const DB_NAME = 'mdxport_db'
const DB_VERSION = 1
const STORE_NAME = 'files'

export async function openDB(): Promise<IDBDatabase> {
	return new Promise((resolve, reject) => {
		const request = indexedDB.open(DB_NAME, DB_VERSION)

		request.onerror = () => reject(request.error)
		request.onsuccess = () => resolve(request.result)

		request.onupgradeneeded = (event) => {
			const db = (event.target as IDBOpenDBRequest).result
			if (!db.objectStoreNames.contains(STORE_NAME)) {
				db.createObjectStore(STORE_NAME)
			}
		}
	})
}

export async function saveFileSystem(nodes: FileNode[]) {
	const db = await openDB()
	return new Promise<void>((resolve, reject) => {
		const transaction = db.transaction(STORE_NAME, 'readwrite')
		const store = transaction.objectStore(STORE_NAME)
		const request = store.put(nodes, 'file_tree')

		request.onerror = () => reject(request.error)
		request.onsuccess = () => resolve()
	})
}

export async function getFileSystem(): Promise<FileNode[] | null> {
	const db = await openDB()
	return new Promise((resolve, reject) => {
		const transaction = db.transaction(STORE_NAME, 'readonly')
		const store = transaction.objectStore(STORE_NAME)
		const request = store.get('file_tree')

		request.onerror = () => reject(request.error)
		request.onsuccess = () => resolve(request.result || null)
	})
}

// Migration from localStorage
export function getOldFileSystemFromLS(): FileNode[] | null {
	if (typeof window === 'undefined') return null
	const saved = localStorage.getItem('mdxport_fs_tree')
	if (saved) {
		try {
			return JSON.parse(saved)
		} catch {
			return null
		}
	}
	return null
}

export function clearOldLSData() {
	if (typeof window === 'undefined') return
	localStorage.removeItem('mdxport_fs_tree')
}
