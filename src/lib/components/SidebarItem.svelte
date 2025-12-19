<script lang="ts">
  import type { FileNode } from '$lib/types/files'

  interface Props {
    node: FileNode
    activeFileId: string | null
    level?: number
    onSelect: (node: FileNode) => void
    onToggleFolder: (node: FileNode) => void
    onCreateFile: (parentNode: FileNode) => void
    onCreateFolder: (parentNode: FileNode) => void
    onDelete: (node: FileNode) => void
    onRename: (node: FileNode, newName: string) => void
  }

  let {
    node,
    activeFileId,
    level = 0,
    onSelect,
    onToggleFolder,
    onCreateFile,
    onCreateFolder,
    onDelete,
    onRename,
  }: Props = $props()

  let isEditing = $state(false)
  let editName = $state(node.name)

  function handleRenameCommit() {
    if (editName.trim() && editName !== node.name) {
      onRename(node, editName.trim())
    }
    isEditing = false
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter') handleRenameCommit()
    if (e.key === 'Escape') {
      editName = node.name
      isEditing = false
    }
  }
</script>

<div class="sidebar-item-container" style="--level: {level}">
  <div
    class="sidebar-item"
    class:active={activeFileId === node.id}
    class:is-folder={node.type === 'folder'}
  >
    <button
      class="item-main"
      onclick={() =>
        node.type === 'folder' ? onToggleFolder(node) : onSelect(node)}
    >
      <span class="item-icon">
        {#if node.type === 'folder'}
          {node.isOpen ? '📂' : '📁'}
        {:else}
          📄
        {/if}
      </span>

      {#if isEditing && !node.isSystem}
        <input
          type="text"
          class="rename-input"
          bind:value={editName}
          onblur={handleRenameCommit}
          onkeydown={handleKeyDown}
          autofocus
        />
      {:else}
        <span class="item-name" class:system-name={node.isSystem}>
          {node.name}
          {#if node.isSystem}
            <span class="lock-icon" title="System Protected">🔒</span>
          {/if}
        </span>
      {/if}
    </button>

    <div class="item-actions">
      {#if node.type === 'folder' && !node.isSystem}
        <button title="New File" onclick={() => onCreateFile(node)}
          ><span>📄+</span></button
        >
        <button title="New Folder" onclick={() => onCreateFolder(node)}
          ><span>📁+</span></button
        >
      {/if}
      {#if !node.isSystem}
        <button title="Rename" onclick={() => (isEditing = true)}
          ><span>✏️</span></button
        >
        <button title="Delete" onclick={() => onDelete(node)}
          ><span>🗑️</span></button
        >
      {/if}
    </div>
  </div>

  {#if node.type === 'folder' && node.isOpen && node.children}
    <div class="children">
      {#each node.children as child (child.id)}
        <svelte:self
          node={child}
          {activeFileId}
          level={level + 1}
          {onSelect}
          {onToggleFolder}
          {onCreateFile}
          {onCreateFolder}
          {onDelete}
          {onRename}
        />
      {/each}
    </div>
  {/if}
</div>

<style>
  .sidebar-item-container {
    display: flex;
    flex-direction: column;
  }

  .sidebar-item {
    display: flex;
    align-items: center;
    padding: 0 8px;
    padding-left: calc(8px + var(--level) * 12px);
    gap: 4px;
    height: 28px;
    cursor: pointer;
    user-select: none;
    border-radius: 4px;
    margin: 1px 4px;
    transition: background-color 0.15s;
    box-sizing: border-box;
  }

  .sidebar-item:hover {
    background-color: var(--color-gray-100);
  }

  .sidebar-item.active {
    background-color: var(--color-white);
    box-shadow: var(--shadow-sm);
  }

  .item-main {
    display: flex;
    align-items: center;
    flex: 1;
    gap: 6px;
    background: none;
    border: none;
    padding: 0;
    text-align: left;
    font: inherit;
    color: inherit;
    cursor: pointer;
    overflow: hidden;
  }

  .item-icon {
    font-size: 14px;
    flex-shrink: 0;
  }

  .item-name {
    font-size: 13px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    color: var(--color-gray-700);
  }

  .active .item-name {
    color: var(--color-gray-900);
    font-weight: 500;
  }

  .item-actions {
    display: none;
    gap: 2px;
    align-items: center;
    height: 100%;
  }

  .sidebar-item:hover .item-actions {
    display: flex;
  }

  .item-actions button {
    background: none;
    border: none;
    padding: 2px;
    cursor: pointer;
    font-size: 12px;
    opacity: 0.5;
    transition: opacity 0.2s;
  }

  .item-actions button:hover {
    opacity: 1;
  }

  .system-name {
    color: var(--color-gray-500);
    /* font-style: italic; */
    position: relative;
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }

  .lock-icon {
    font-size: 10px;
    opacity: 0.6;
    filter: grayscale(1);
  }

  .rename-input {
    width: 100%;
    font-size: 13px;
    border: 1px solid var(--color-gray-300);
    border-radius: 2px;
    padding: 0 2px;
    outline: none;
  }

  .children {
    display: flex;
    flex-direction: column;
  }
</style>
