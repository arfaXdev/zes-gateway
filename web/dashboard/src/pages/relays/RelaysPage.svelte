<script>
  import { router } from "$lib/stores/router.svelte.js";
  import { auth } from "$lib/stores/auth.svelte.js";
  import Icon from "$lib/components/atoms/Icon.svelte";
  import EmptyState from "$lib/components/atoms/EmptyState.svelte";
  import VirtualModelEditor from "$pages/models/VirtualModelEditor.svelte";
  import { virtualModels } from "$pages/models/virtualModels.svelte.js";
  import { virtualModelEditor } from "$pages/models/virtualModelEditor.svelte.js";
  import { Plus, Pencil, Trash2, Network } from "lucide";

  $effect(() => {
    void auth.refreshTick;
    if (router.page === "relays") virtualModels.fetchVirtualModels();
  });

  const relays = $derived(virtualModels.aliases || []);
</script>

<div class="relays-page">
  <div class="page-header">
    <div><h2>Relays & Bridges</h2><p class="page-kicker">Route one public model name to one or more provider targets.</p></div>
    <button class="btn btn-primary btn-with-icon" onclick={() => virtualModelEditor.openVirtualModelCreate()}><Icon icon={Plus} class="table-icon-svg" /> Add relay</button>
  </div>

  {#if virtualModels.aliasError}<div class="alert alert-warning">{virtualModels.aliasError}</div>{/if}
  {#if relays.length === 0}
    <div class="frost-card relay-empty"><Icon icon={Network} class="relay-empty-icon" /><h3>No relays configured</h3><p>Create a bridge for fallback, balancing, or a stable model alias.</p></div>
  {:else}
    <div class="relay-grid">
      {#each relays as relay (relay.name)}
        <article class="frost-card relay-card">
          <div class="relay-head"><span class="relay-status"></span><span class="mono relay-name">{relay.name}</span><span class="glass-badge">{relay.strategy || (relay.targets?.length > 1 ? "balanced" : "relay")}</span></div>
          <div class="relay-flow"><span>{relay.name}</span><span class="relay-arrow">→</span><strong class="mono">{relay.target || relay.target_model || relay.targets?.map((t) => t.model).join(", ") || "target"}</strong></div>
          <div class="relay-actions">
            <button class="btn btn-with-icon" onclick={() => virtualModelEditor.openVirtualModelEditAlias(relay)}><Icon icon={Pencil} class="table-icon-svg" /> Edit</button>
            <button class="btn btn-danger btn-with-icon" disabled={Boolean(virtualModels.rowDeletingKey)} onclick={() => virtualModels.removeAliasRow({ key: `alias:${relay.name}`, is_alias: true, alias: relay })}><Icon icon={Trash2} class="table-icon-svg" /> Remove</button>
          </div>
        </article>
      {/each}
    </div>
  {/if}
  <VirtualModelEditor />
</div>

<style>
.page-kicker{color:var(--text-muted);font-size:13px;margin-top:5px}.relay-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px}.relay-card{padding:20px}.relay-head,.relay-actions{display:flex;align-items:center;gap:10px}.relay-name{font-weight:700;flex:1}.relay-status{width:9px;height:9px;border-radius:50%;background:var(--success);box-shadow:0 0 10px var(--success)}.relay-flow{margin:22px 0;padding:14px;border:1px solid var(--border);border-radius:10px;background:rgba(5,8,18,.35);display:flex;gap:10px;align-items:center;overflow:hidden}.relay-flow strong{overflow:hidden;text-overflow:ellipsis}.relay-arrow{color:var(--accent);font-size:20px}.relay-actions{justify-content:flex-end}.relay-empty{text-align:center;padding:60px 20px}.relay-empty p{color:var(--text-muted);margin-top:8px}.relay-empty-icon{width:38px;height:38px;color:var(--accent);margin-bottom:14px}@media(max-width:600px){.page-header .btn{width:100%;justify-content:center}.relay-grid{grid-template-columns:1fr}}
</style>