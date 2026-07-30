-- Eldritch Dossier: RLS coherente y guardado transaccional.
-- Ejecutar en Supabase SQL Editor. Puede ejecutarse más de una vez.

begin;

create index if not exists tb_creatures_status_idx on public.tb_creatures(status);
create index if not exists tb_creatures_danger_idx on public.tb_creatures(danger_level_id);
create index if not exists tb_abilities_creature_idx on public.tb_abilities(creature_id);
create index if not exists tb_profiles_role_idx on public.tb_profiles(role_id);

create or replace function public.current_user_role()
returns integer language sql stable security definer set search_path = public
as $$ select role_id from public.tb_profiles where id = auth.uid() $$;

revoke all on function public.current_user_role() from public;
grant execute on function public.current_user_role() to anon, authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.tb_profiles(id, username, role_id)
  values (new.id, nullif(btrim(new.raw_user_meta_data->>'username'), ''), 3)
  on conflict (id) do nothing;
  return new;
end;
$$;

alter table public.tb_profiles enable row level security;
alter table public.tb_creatures enable row level security;
alter table public.tb_abilities enable row level security;
alter table public.tb_creaturecultures enable row level security;
alter table public.tb_creaturemythologies enable row level security;
alter table public.tb_creaturetags enable row level security;
alter table public.ctl_dangerlevels enable row level security;
alter table public.ctl_mythologies enable row level security;
alter table public.ctl_cultures enable row level security;
alter table public.ctl_tags enable row level security;
alter table public.ctl_roles enable row level security;

drop policy if exists "Usuarios pueden ver su propio perfil" on public.tb_profiles;
drop policy if exists "Acceso de lectura para todos" on public.tb_creatures;
drop policy if exists "Eruditos y Archivistas pueden modificar" on public.tb_creatures;
drop policy if exists "Solo Archivistas eliminan" on public.tb_creatures;
drop policy if exists "Personal autorizado puede modificar criaturas" on public.tb_creatures;
drop policy if exists "Modificar relaciones de cultura" on public.tb_creaturecultures;
drop policy if exists "Modificar relaciones de mitología" on public.tb_creaturemythologies;
drop policy if exists "Modificar relaciones de tags" on public.tb_creaturetags;
drop policy if exists "Modificar habilidades" on public.tb_abilities;
drop policy if exists "Modificar niveles de peligro" on public.ctl_dangerlevels;

drop policy if exists profiles_read_own on public.tb_profiles;
create policy profiles_read_own on public.tb_profiles
  for select to authenticated using (id = auth.uid());

drop policy if exists creatures_read_active on public.tb_creatures;
create policy creatures_read_active on public.tb_creatures
  for select to anon, authenticated using (status = 'active');
drop policy if exists creatures_insert_staff on public.tb_creatures;
create policy creatures_insert_staff on public.tb_creatures
  for insert to authenticated with check (public.current_user_role() in (1, 2));
drop policy if exists creatures_update_staff on public.tb_creatures;
create policy creatures_update_staff on public.tb_creatures
  for update to authenticated using (public.current_user_role() in (1, 2))
  with check (public.current_user_role() in (1, 2));
drop policy if exists creatures_delete_archivist on public.tb_creatures;
create policy creatures_delete_archivist on public.tb_creatures
  for delete to authenticated using (public.current_user_role() = 1);

drop policy if exists abilities_read on public.tb_abilities;
create policy abilities_read on public.tb_abilities for select to anon, authenticated using (true);
drop policy if exists cultures_rel_read on public.tb_creaturecultures;
create policy cultures_rel_read on public.tb_creaturecultures for select to anon, authenticated using (true);
drop policy if exists mythologies_rel_read on public.tb_creaturemythologies;
create policy mythologies_rel_read on public.tb_creaturemythologies for select to anon, authenticated using (true);
drop policy if exists tags_rel_read on public.tb_creaturetags;
create policy tags_rel_read on public.tb_creaturetags for select to anon, authenticated using (true);
drop policy if exists danger_read on public.ctl_dangerlevels;
create policy danger_read on public.ctl_dangerlevels for select to anon, authenticated using (true);
drop policy if exists mythologies_read on public.ctl_mythologies;
create policy mythologies_read on public.ctl_mythologies for select to anon, authenticated using (true);
drop policy if exists cultures_read on public.ctl_cultures;
create policy cultures_read on public.ctl_cultures for select to anon, authenticated using (true);
drop policy if exists tags_read on public.ctl_tags;
create policy tags_read on public.ctl_tags for select to anon, authenticated using (true);
drop policy if exists roles_read on public.ctl_roles;
create policy roles_read on public.ctl_roles for select to authenticated using (true);

-- SECURITY DEFINER permite que esta única función controlada actualice todas
-- las tablas. La comprobación de rol ocurre antes de cualquier escritura.
create or replace function public.save_creature(payload jsonb, editing boolean default false)
returns text language plpgsql security definer set search_path = public
as $$
declare
  v_id text;
  v_danger_id integer;
  v_catalog_id integer;
  v_value text;
  v_prefix text;
  v_sequence integer;
  v_actor text;
begin
  if auth.uid() is null or public.current_user_role() not in (1, 2) then
    raise exception 'No tienes permisos para modificar expedientes';
  end if;
  if nullif(btrim(payload->>'nombre'), '') is null then
    raise exception 'El nombre de la criatura es obligatorio';
  end if;

  select id into v_danger_id from public.ctl_dangerlevels
   where name = payload->>'nivel_peligro';
  if v_danger_id is null then raise exception 'Nivel de peligro inválido'; end if;

  v_actor := coalesce(auth.jwt()->'user_metadata'->>'username', auth.jwt()->>'email');
  v_id := nullif(payload->>'id', '');
  if not editing or v_id is null then
    perform pg_advisory_xact_lock(hashtext('eldritch-creature-id'));
    v_prefix := 'ED-' || to_char(current_date, 'DDMMYYYY') || '-';
    select coalesce(max(substring(id from '[0-9]+$')::integer), 0) + 1
      into v_sequence from public.tb_creatures where id like v_prefix || '%';
    v_id := v_prefix || lpad(v_sequence::text, 3, '0');
  end if;

  insert into public.tb_creatures
    (id,nombre,imagen_url,historia,descripcion_fisica,danger_level_id,periodo,status,created_by,last_edited_by)
  values
    (v_id,btrim(payload->>'nombre'),nullif(payload->>'imagen_url',''),
     coalesce(payload->>'historia',''),coalesce(payload->>'descripcion_fisica',''),
     v_danger_id,coalesce(payload#>>'{origen,periodo}',''),'active',v_actor,v_actor)
  on conflict (id) do update set
    nombre=excluded.nombre, imagen_url=excluded.imagen_url, historia=excluded.historia,
    descripcion_fisica=excluded.descripcion_fisica, danger_level_id=excluded.danger_level_id,
    periodo=excluded.periodo, updated_at=now(), last_edited_by=excluded.last_edited_by;

  delete from public.tb_creaturecultures where creature_id=v_id;
  for v_value in select btrim(value) from jsonb_array_elements_text(coalesce(payload#>'{origen,cultura}','[]')) loop
    if v_value<>'' then
      select id into v_catalog_id from public.ctl_cultures where lower(name)=lower(v_value) limit 1;
      if v_catalog_id is null then insert into public.ctl_cultures(name) values(v_value) returning id into v_catalog_id; end if;
      insert into public.tb_creaturecultures values(v_id,v_catalog_id) on conflict do nothing;
    end if;
  end loop;

  delete from public.tb_creaturemythologies where creature_id=v_id;
  for v_value in select btrim(value) from jsonb_array_elements_text(coalesce(payload#>'{origen,mitologia}','[]')) loop
    if v_value<>'' then
      select id into v_catalog_id from public.ctl_mythologies where lower(name)=lower(v_value) limit 1;
      if v_catalog_id is null then insert into public.ctl_mythologies(name) values(v_value) returning id into v_catalog_id; end if;
      insert into public.tb_creaturemythologies values(v_id,v_catalog_id) on conflict do nothing;
    end if;
  end loop;

  delete from public.tb_creaturetags where creature_id=v_id;
  for v_value in select btrim(value) from jsonb_array_elements_text(coalesce(payload->'tags','[]')) loop
    if v_value<>'' then
      select id into v_catalog_id from public.ctl_tags where lower(name)=lower(v_value) limit 1;
      if v_catalog_id is null then insert into public.ctl_tags(name) values(v_value) returning id into v_catalog_id; end if;
      insert into public.tb_creaturetags values(v_id,v_catalog_id) on conflict do nothing;
    end if;
  end loop;

  delete from public.tb_abilities where creature_id=v_id;
  for v_value in select btrim(value) from jsonb_array_elements_text(coalesce(payload->'habilidades','[]')) loop
    if v_value<>'' then insert into public.tb_abilities(creature_id,description) values(v_id,v_value); end if;
  end loop;
  return v_id;
end;
$$;

revoke all on function public.save_creature(jsonb, boolean) from public;
grant execute on function public.save_creature(jsonb, boolean) to authenticated;

commit;
