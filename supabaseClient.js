// ==========================================
// SUPABASE CLIENT — Eldritch Dossier
// ==========================================
// SDK loaded via CDN: @supabase/supabase-js@2
// Exposes all data-layer functions as globals
// for consumption by the React app (Babel script).
// ==========================================

var SUPABASE_URL = 'https://cbcmcdqhtxbefsvyzszw.supabase.co';
var SUPABASE_ANON_KEY = 'sb_publishable_AjrJpf-3UPIOh8T-wlIAjQ_Ibi7yVyn';

// Singleton client — attached to window for global access
window._supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ============================================================
//  AUTH
// ============================================================

async function supaLogin(email, password) {
  var result = await window._supabase.auth.signInWithPassword({ email: email, password: password });
  if (result.error) throw result.error;
  return result.data;
}

async function supaSignup(email, password, username) {
  var result = await window._supabase.auth.signUp({
    email: email,
    password: password,
    options: { data: { username: username } }
  });
  if (result.error) throw result.error;
  return result.data;
}

async function supaLogout() {
  var result = await window._supabase.auth.signOut();
  if (result.error) throw result.error;
}

async function supaGetSession() {
  var result = await window._supabase.auth.getSession();
  if (result.error) throw result.error;
  return result.data.session;
}

async function supaGetProfile(userId) {
  var result = await window._supabase
    .from('tb_profiles')
    .select('id, username, role_id')
    .eq('id', userId)
    .single();
  if (result.error) throw result.error;
  return result.data;
}

async function supaResetPasswordForEmail(email) {
  // Envía el correo con el enlace que retornará a la página actual con hash #type=recovery
  var result = await window._supabase.auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin + window.location.pathname,
  });
  if (result.error) throw result.error;
}

async function supaUpdatePassword(newPassword) {
  var result = await window._supabase.auth.updateUser({ password: newPassword });
  if (result.error) throw result.error;
}

// ============================================================
//  LOAD CREATURES  (relational JOINs)
// ============================================================

async function supaLoadCreatures() {
  var result = await window._supabase
    .from('tb_creatures')
    .select([
      'id', 'nombre', 'imagen_url', 'historia', 'descripcion_fisica', 'periodo',
      'status', 'created_at', 'updated_at', 'created_by', 'last_edited_by',
      'danger_level_id',
      'ctl_dangerlevels ( id, name )',
      'tb_creaturemythologies ( ctl_mythologies ( id, name ) )',
      'tb_creaturecultures ( ctl_cultures ( id, name ) )',
      'tb_creaturetags ( ctl_tags ( id, name ) )',
      'tb_abilities ( id, description )'
    ].join(', '))
    .eq('status', 'active')
    .order('nombre');

  if (result.error) throw result.error;

  // DEBUG: ver datos crudos de Supabase (eliminar después de confirmar)
  if (result.data && result.data.length > 0) {
    console.log('[DEBUG] Primer criatura raw:', JSON.stringify(result.data[0], null, 2));
    console.log('[DEBUG] tb_creaturemythologies:', result.data[0].tb_creaturemythologies);
  }

  // Transform each row into the legacy frontend shape
  return (result.data || []).map(function (c) {
    return {
      id: c.id,
      nombre: c.nombre,
      imagen_url: c.imagen_url,
      origen: {
        cultura: (c.tb_creaturecultures || []).map(function (r) { return r.ctl_cultures ? r.ctl_cultures.name : null; }).filter(Boolean),
        mitologia: (c.tb_creaturemythologies || []).map(function (r) { return r.ctl_mythologies ? r.ctl_mythologies.name : null; }).filter(Boolean),
        periodo: c.periodo || ''
      },
      historia: c.historia,
      descripcion_fisica: c.descripcion_fisica,
      habilidades: (c.tb_abilities || []).map(function (a) { return a.description; }),
      nivel_peligro: c.ctl_dangerlevels ? c.ctl_dangerlevels.name : 'Insignificante',
      tags: (c.tb_creaturetags || []).map(function (r) { return r.ctl_tags ? r.ctl_tags.name : null; }).filter(Boolean),
      created_at: c.created_at,
      updated_at: c.updated_at,
      created_by: c.created_by,
      last_edited_by: c.last_edited_by,
      status: c.status
    };
  });
}

// ============================================================
//  CATALOG HELPERS
// ============================================================

async function supaFindOrCreateCatalog(table, name) {
  // Try to find existing entry
  var find = await window._supabase.from(table).select('id').eq('name', name).maybeSingle();
  if (find.data) return find.data.id;

  // Create new entry
  var create = await window._supabase.from(table).insert({ name: name }).select('id').single();
  if (create.error) throw create.error;
  return create.data.id;
}

async function supaLoadDangerLevels() {
  var result = await window._supabase
    .from('ctl_dangerlevels')
    .select('id, name, risk_score')
    .order('risk_score');
  if (result.error) throw result.error;
  return result.data || [];
}

async function supaLoadMythologies() {
  var result = await window._supabase
    .from('ctl_mythologies')
    .select('id, name')
    .order('name');
  if (result.error) throw result.error;
  return (result.data || []).map(function (m) { return m.name; });
}

// ============================================================
//  UPSERT CREATURE  (+ relational cascade)
// ============================================================

async function supaUpsertCreature(creatureData, isEditing, currentUsername) {
  var nowIso = new Date().toISOString();

  // 1. Resolve danger_level_id from the human-readable name
  var dangerLevels = await supaLoadDangerLevels();
  var dl = dangerLevels.find(function (d) { return d.name === creatureData.nivel_peligro; });
  if (!dl) throw new Error('Nivel de peligro inválido: ' + creatureData.nivel_peligro);

  // 2. Generate creature ID if creating a new record
  var creatureId = creatureData.id;
  if (!isEditing || !creatureId) {
    var now = new Date();
    var dd = String(now.getDate()).padStart(2, '0');
    var mm = String(now.getMonth() + 1).padStart(2, '0');
    var yyyy = now.getFullYear();
    var prefix = 'ED-' + dd + mm + yyyy + '-';

    // Find the highest sequence number for today
    var existing = await window._supabase
      .from('tb_creatures')
      .select('id')
      .like('id', prefix + '%');

    var maxSeq = (existing.data || []).reduce(function (max, c) {
      var seq = parseInt(c.id.split('-').pop(), 10);
      return seq > max ? seq : max;
    }, 0);

    creatureId = prefix + String(maxSeq + 1).padStart(3, '0');
  }

  // 3. Upsert main creature record
  var row = {
    id: creatureId,
    nombre: creatureData.nombre,
    imagen_url: creatureData.imagen_url,
    historia: creatureData.historia || '',
    descripcion_fisica: creatureData.descripcion_fisica || '',
    danger_level_id: dl.id,
    periodo: (creatureData.origen && creatureData.origen.periodo) ? creatureData.origen.periodo : '',
    status: 'active',
    updated_at: nowIso,
    last_edited_by: currentUsername
  };

  if (!isEditing) {
    row.created_at = nowIso;
    row.created_by = currentUsername;
  }

  var upsert = await window._supabase.from('tb_creatures').upsert(row);
  if (upsert.error) throw upsert.error;

  // 4. Rebuild many-to-many relations (delete + re-insert)

  // --- Cultures ---
  await window._supabase.from('tb_creaturecultures').delete().eq('creature_id', creatureId);
  var cultures = (creatureData.origen && creatureData.origen.cultura) || [];
  for (var ci = 0; ci < cultures.length; ci++) {
    var cultureId = await supaFindOrCreateCatalog('ctl_cultures', cultures[ci]);
    await window._supabase.from('tb_creaturecultures').insert({ creature_id: creatureId, culture_id: cultureId });
  }

  // --- Mythologies ---
  await window._supabase.from('tb_creaturemythologies').delete().eq('creature_id', creatureId);
  var mythologies = (creatureData.origen && creatureData.origen.mitologia) || [];
  for (var mi = 0; mi < mythologies.length; mi++) {
    var mythologyId = await supaFindOrCreateCatalog('ctl_mythologies', mythologies[mi]);
    await window._supabase.from('tb_creaturemythologies').insert({ creature_id: creatureId, mythology_id: mythologyId });
  }

  // --- Tags ---
  await window._supabase.from('tb_creaturetags').delete().eq('creature_id', creatureId);
  var tags = creatureData.tags || [];
  for (var ti = 0; ti < tags.length; ti++) {
    var tagId = await supaFindOrCreateCatalog('ctl_tags', tags[ti]);
    await window._supabase.from('tb_creaturetags').insert({ creature_id: creatureId, tag_id: tagId });
  }

  // --- Abilities (1:N) ---
  await window._supabase.from('tb_abilities').delete().eq('creature_id', creatureId);
  var abilities = creatureData.habilidades || [];
  for (var ai = 0; ai < abilities.length; ai++) {
    await window._supabase.from('tb_abilities').insert({ creature_id: creatureId, description: abilities[ai] });
  }

  return creatureId;
}

// ============================================================
//  DELETE CREATURE
// ============================================================

async function supaDeleteCreature(creatureId) {
  // Hard delete — ON DELETE CASCADE cleans up all junction rows + abilities
  var result = await window._supabase
    .from('tb_creatures')
    .delete()
    .eq('id', creatureId);
  if (result.error) throw result.error;
}
