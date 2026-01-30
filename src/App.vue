<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue'

const API_BASE = (import.meta.env.VITE_API_BASE || 'http://127.0.0.1:8000').replace(
  /\/+$/,
  ''
)

const loading = ref(false)
const error = ref('')
const createError = ref('')
const editError = ref('')
const projects = ref([])
const selectedId = ref(null)
const selected = ref(null)
const showCreate = ref(false)
const showEdit = ref(false)

const form = reactive({
  name: '',
  description: '',
  git_url: '',
  pipeline_url: '',
  deploy_host: '',
  deploy_port: '',
  data_location: '',
  healthcheck_url: '',
  latency_check_url: '',
  extras: ''
})

const editForm = reactive({
  name: '',
  description: '',
  git_url: '',
  pipeline_url: '',
  deploy_host: '',
  deploy_port: '',
  data_location: '',
  healthcheck_url: '',
  latency_check_url: '',
  extras: ''
})

const detailTitle = computed(() => {
  if (!selected.value) return 'Select a project'
  return `${selected.value.name} (#${selected.value.id})`
})

const prettyExtras = computed(() => {
  if (!selected.value?.extras) return '-'
  try {
    return JSON.stringify(selected.value.extras, null, 2)
  } catch {
    return String(selected.value.extras)
  }
})

async function fetchProjects() {
  loading.value = true
  error.value = ''
  try {
    const res = await fetch(`${API_BASE}/projects`)
    if (!res.ok) throw new Error(`Failed to load list (${res.status})`)
    projects.value = await res.json()
    if (projects.value.length && !selectedId.value) {
      selectProject(projects.value[0].id)
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
}

async function selectProject(id) {
  selectedId.value = id
  error.value = ''
  try {
    const res = await fetch(`${API_BASE}/projects/${id}`)
    if (!res.ok) throw new Error(`Failed to load details (${res.status})`)
    selected.value = await res.json()
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
  }
}

function openCreateModal() {
  createError.value = ''
  resetForm()
  showCreate.value = true
}

function openEditModal() {
  if (!selected.value) return
  editError.value = ''
  hydrateEditForm(selected.value)
  showEdit.value = true
}

function closeModals() {
  showCreate.value = false
  showEdit.value = false
}

async function createProject() {
  createError.value = ''
  const extras = parseExtras(form.extras, createError)
  if (createError.value) return

  const payload = {
    name: form.name.trim(),
    description: form.description.trim() || null,
    git_url: form.git_url.trim(),
    pipeline_url: form.pipeline_url.trim() || null,
    deploy_host: form.deploy_host.trim() || null,
    deploy_port: form.deploy_port ? Number(form.deploy_port) : null,
    data_location: form.data_location.trim() || null,
    healthcheck_url: form.healthcheck_url.trim() || null,
    latency_check_url: form.latency_check_url.trim() || null,
    extras
  }

  if (!payload.name || !payload.git_url) {
    createError.value = 'Name and Git URL are required.'
    return
  }

  try {
    const res = await fetch(`${API_BASE}/projects`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    })
    if (!res.ok) {
      const body = await safeText(res)
      throw new Error(`Create failed (${res.status}) ${body}`)
    }
    const created = await res.json()
    projects.value = [created, ...projects.value]
    selected.value = created
    selectedId.value = created.id
    resetForm()
    showCreate.value = false
  } catch (err) {
    createError.value = err instanceof Error ? err.message : String(err)
  }
}

async function updateProject() {
  if (!selectedId.value) return
  editError.value = ''
  const extras = parseExtras(editForm.extras, editError)
  if (editError.value) return

  const payload = {
    name: editForm.name.trim(),
    description: editForm.description.trim() || null,
    git_url: editForm.git_url.trim(),
    pipeline_url: editForm.pipeline_url.trim() || null,
    deploy_host: editForm.deploy_host.trim() || null,
    deploy_port: editForm.deploy_port ? Number(editForm.deploy_port) : null,
    data_location: editForm.data_location.trim() || null,
    healthcheck_url: editForm.healthcheck_url.trim() || null,
    latency_check_url: editForm.latency_check_url.trim() || null,
    extras
  }

  if (!payload.name || !payload.git_url) {
    editError.value = 'Name and Git URL are required.'
    return
  }

  try {
    const res = await fetch(`${API_BASE}/projects/${selectedId.value}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    })
    if (!res.ok) {
      const body = await safeText(res)
      throw new Error(`Update failed (${res.status}) ${body}`)
    }
    const updated = await res.json()
    projects.value = projects.value.map((item) => (item.id === updated.id ? updated : item))
    selected.value = updated
    showEdit.value = false
  } catch (err) {
    editError.value = err instanceof Error ? err.message : String(err)
  }
}

async function deleteProject() {
  if (!selectedId.value) return
  editError.value = ''
  const ok = window.confirm('Delete this project? This cannot be undone.')
  if (!ok) return

  try {
    const res = await fetch(`${API_BASE}/projects/${selectedId.value}`, { method: 'DELETE' })
    if (!res.ok) {
      const body = await safeText(res)
      throw new Error(`Delete failed (${res.status}) ${body}`)
    }
    projects.value = projects.value.filter((item) => item.id !== selectedId.value)
    selected.value = null
    selectedId.value = null
  } catch (err) {
    editError.value = err instanceof Error ? err.message : String(err)
  }
}

function parseExtras(raw, errorRef) {
  const text = raw.trim()
  if (!text) return null
  try {
    return JSON.parse(text)
  } catch {
    errorRef.value = 'Extras must be valid JSON.'
    return null
  }
}

function resetForm() {
  Object.assign(form, {
    name: '',
    description: '',
    git_url: '',
    pipeline_url: '',
    deploy_host: '',
    deploy_port: '',
    data_location: '',
    healthcheck_url: '',
    latency_check_url: '',
    extras: ''
  })
}

function resetEditForm() {
  Object.assign(editForm, {
    name: '',
    description: '',
    git_url: '',
    pipeline_url: '',
    deploy_host: '',
    deploy_port: '',
    data_location: '',
    healthcheck_url: '',
    latency_check_url: '',
    extras: ''
  })
}

function hydrateEditForm(project) {
  if (!project) {
    resetEditForm()
    return
  }

  Object.assign(editForm, {
    name: project.name || '',
    description: project.description || '',
    git_url: project.git_url || '',
    pipeline_url: project.pipeline_url || '',
    deploy_host: project.deploy_host || '',
    deploy_port: project.deploy_port ?? '',
    data_location: project.data_location || '',
    healthcheck_url: project.healthcheck_url || '',
    latency_check_url: project.latency_check_url || '',
    extras: project.extras ? JSON.stringify(project.extras, null, 2) : ''
  })
}

async function safeText(res) {
  try {
    return await res.text()
  } catch {
    return ''
  }
}

onMounted(fetchProjects)

watch(selected, (value) => hydrateEditForm(value))
</script>

<template>
  <div class="app">
    <header class="hero">
      <div class="hero__text">
        <p class="eyebrow">ProjectHub Front</p>
        <h1>Manage your deployments in one place</h1>
        <p class="sub">Fast CRUD for Git metadata, infra endpoints, and runtime checks.</p>
        <div class="hero__meta">
          <span>API: {{ API_BASE }}</span>
          <button @click="openCreateModal">Add Project</button>
          <button class="ghost" @click="fetchProjects" :disabled="loading">Refresh</button>
        </div>
      </div>
      <div class="hero__panel">
        <div class="stat">
          <span class="stat__label">Projects</span>
          <strong class="stat__value">{{ projects.length }}</strong>
        </div>
        <div class="stat">
          <span class="stat__label">Selected</span>
          <strong class="stat__value">{{ selected?.name || '-' }}</strong>
        </div>
      </div>
    </header>

    <main class="grid">
      <section class="card list">
        <div class="card__head">
          <h2>Project List</h2>
          <span v-if="loading" class="badge">Loading...</span>
        </div>
        <p v-if="!projects.length && !loading" class="muted">No projects yet.</p>
        <ul class="items">
          <li
            v-for="project in projects"
            :key="project.id"
            :class="['item', { active: project.id === selectedId }]"
            @click="selectProject(project.id)"
          >
            <div>
              <strong>{{ project.name }}</strong>
              <span class="meta">{{ project.git_url }}</span>
            </div>
            <span class="pill">#{{ project.id }}</span>
          </li>
        </ul>
      </section>

      <section class="card detail">
        <div class="card__head">
          <h2>{{ detailTitle }}</h2>
          <div class="actions">
            <button v-if="selected" class="ghost" @click="openEditModal">Edit</button>
            <button v-if="selected" class="danger" @click="deleteProject">Delete</button>
          </div>
        </div>
        <div v-if="selected" class="detail__body">
          <div class="detail__row">
            <span class="label">Description</span>
            <span>{{ selected.description || '-' }}</span>
          </div>
          <div class="detail__row">
            <span class="label">Git URL</span>
            <a :href="selected.git_url" target="_blank" rel="noreferrer">{{ selected.git_url }}</a>
          </div>
          <div class="detail__row">
            <span class="label">Pipeline</span>
            <span>{{ selected.pipeline_url || '-' }}</span>
          </div>
          <div class="detail__row">
            <span class="label">Deploy</span>
            <span>{{ selected.deploy_host || '-' }} {{ selected.deploy_port || '' }}</span>
          </div>
          <div class="detail__row">
            <span class="label">Data</span>
            <span>{{ selected.data_location || '-' }}</span>
          </div>
          <div class="detail__row">
            <span class="label">Healthcheck</span>
            <span>{{ selected.healthcheck_url || '-' }}</span>
          </div>
          <div class="detail__row">
            <span class="label">Latency</span>
            <span>{{ selected.latency_check_url || '-' }}</span>
          </div>
          <div class="detail__row">
            <span class="label">Extras</span>
            <pre class="json">{{ prettyExtras }}</pre>
          </div>
          <div class="detail__row">
            <span class="label">Created</span>
            <span>{{ selected.created_at }}</span>
          </div>
          <div class="detail__row">
            <span class="label">Updated</span>
            <span>{{ selected.updated_at }}</span>
          </div>
        </div>
        <p v-else class="muted">Pick a project from the list to see details.</p>
      </section>

    </main>

    <div v-if="showCreate" class="modal" @click.self="closeModals">
      <div class="modal__panel">
        <div class="modal__head">
          <h2>Add Project</h2>
          <div class="actions">
            <button class="ghost" @click="closeModals">Close</button>
          </div>
        </div>
        <span v-if="createError" class="error">{{ createError }}</span>
        <form @submit.prevent="createProject" class="form__body">
          <label>
            <span>Name *</span>
            <input v-model="form.name" placeholder="Project name" required />
          </label>
          <label>
            <span>Git URL *</span>
            <input v-model="form.git_url" placeholder="https://github.com/..." required />
          </label>
          <label>
            <span>Description</span>
            <input v-model="form.description" placeholder="Short summary" />
          </label>
          <label>
            <span>Pipeline URL</span>
            <input v-model="form.pipeline_url" placeholder="https://..." />
          </label>
          <label>
            <span>Deploy Host</span>
            <input v-model="form.deploy_host" placeholder="example.com" />
          </label>
          <label>
            <span>Deploy Port</span>
            <input v-model="form.deploy_port" type="number" min="1" max="65535" />
          </label>
          <label>
            <span>Data Location</span>
            <input v-model="form.data_location" placeholder="/data/path or s3://..." />
          </label>
          <label>
            <span>Healthcheck URL</span>
            <input v-model="form.healthcheck_url" placeholder="https://..." />
          </label>
          <label>
            <span>Latency URL</span>
            <input v-model="form.latency_check_url" placeholder="https://..." />
          </label>
          <label class="wide">
            <span>Extras (JSON)</span>
            <textarea v-model="form.extras" placeholder='{"owner":"me"}'></textarea>
          </label>
          <div class="form__actions">
            <button type="submit">Create</button>
            <button type="button" class="ghost" @click="resetForm">Reset</button>
          </div>
        </form>
      </div>
    </div>

    <div v-if="showEdit" class="modal" @click.self="closeModals">
      <div class="modal__panel">
        <div class="modal__head">
          <h2>Edit Project</h2>
          <div class="actions">
            <button class="ghost" @click="closeModals">Close</button>
          </div>
        </div>
        <span v-if="editError" class="error">{{ editError }}</span>
        <form @submit.prevent="updateProject" class="form__body">
          <label>
            <span>Name *</span>
            <input v-model="editForm.name" placeholder="Project name" required />
          </label>
          <label>
            <span>Git URL *</span>
            <input v-model="editForm.git_url" placeholder="https://github.com/..." required />
          </label>
          <label>
            <span>Description</span>
            <input v-model="editForm.description" placeholder="Short summary" />
          </label>
          <label>
            <span>Pipeline URL</span>
            <input v-model="editForm.pipeline_url" placeholder="https://..." />
          </label>
          <label>
            <span>Deploy Host</span>
            <input v-model="editForm.deploy_host" placeholder="example.com" />
          </label>
          <label>
            <span>Deploy Port</span>
            <input v-model="editForm.deploy_port" type="number" min="1" max="65535" />
          </label>
          <label>
            <span>Data Location</span>
            <input v-model="editForm.data_location" placeholder="/data/path or s3://..." />
          </label>
          <label>
            <span>Healthcheck URL</span>
            <input v-model="editForm.healthcheck_url" placeholder="https://..." />
          </label>
          <label>
            <span>Latency URL</span>
            <input v-model="editForm.latency_check_url" placeholder="https://..." />
          </label>
          <label class="wide">
            <span>Extras (JSON)</span>
            <textarea v-model="editForm.extras" placeholder='{"owner":"me"}'></textarea>
          </label>
          <div class="form__actions">
            <button type="submit">Update</button>
            <button type="button" class="ghost" @click="hydrateEditForm(selected)">
              Reset to current
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>
