<script lang="ts">
  let message = 'Hello from Minimal Test'
</script>

<div class="test">
  <h1>{message}</h1>
  <p>If you can see this, the basic Svelte component works.</p>
</div>

<style>
  .test {
    padding: 2rem;
    background: #1e1e1e;
    color: white;
    min-height: 100vh;
  }
</style>
