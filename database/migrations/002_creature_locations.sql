-- Ubicación cartográfica de expedientes.
-- Ejecutar después de 001_secure_schema.sql. Es seguro volver a ejecutarlo.

begin;

alter table public.tb_creatures
  add column if not exists location_kind text not null default 'cultural_origin',
  add column if not exists location_country text,
  add column if not exists location_region text,
  add column if not exists location_place text,
  add column if not exists latitude numeric(9,6),
  add column if not exists longitude numeric(9,6);

alter table public.tb_creatures
  drop constraint if exists tb_creatures_location_kind_check,
  add constraint tb_creatures_location_kind_check
    check (location_kind in ('cultural_origin', 'sighting', 'fictional', 'unknown')),
  drop constraint if exists tb_creatures_coordinates_check,
  add constraint tb_creatures_coordinates_check
    check (
      (latitude is null and longitude is null)
      or (latitude between -90 and 90 and longitude between -180 and 180)
    );

create index if not exists tb_creatures_location_country_idx
  on public.tb_creatures(location_country);

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
  v_latitude numeric(9,6);
  v_longitude numeric(9,6);
  v_location_kind text;
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

  v_latitude := nullif(payload#>>'{ubicacion,latitud}', '')::numeric;
  v_longitude := nullif(payload#>>'{ubicacion,longitud}', '')::numeric;
  v_location_kind := coalesce(nullif(payload#>>'{ubicacion,tipo}', ''), 'cultural_origin');
  if v_location_kind not in ('cultural_origin', 'sighting', 'fictional', 'unknown') then
    raise exception 'Tipo de ubicación inválido';
  end if;
  if (v_latitude is null) <> (v_longitude is null) then
    raise exception 'Latitud y longitud deben capturarse juntas';
  end if;
  if v_latitude is not null and (v_latitude not between -90 and 90 or v_longitude not between -180 and 180) then
    raise exception 'Las coordenadas están fuera de rango';
  end if;

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
    (id,nombre,imagen_url,historia,descripcion_fisica,danger_level_id,periodo,status,created_by,last_edited_by,
     location_kind,location_country,location_region,location_place,latitude,longitude)
  values
    (v_id,btrim(payload->>'nombre'),nullif(payload->>'imagen_url',''),
     coalesce(payload->>'historia',''),coalesce(payload->>'descripcion_fisica',''),
     v_danger_id,coalesce(payload#>>'{origen,periodo}',''),'active',v_actor,v_actor,
     v_location_kind,nullif(btrim(payload#>>'{ubicacion,pais}'),''),nullif(btrim(payload#>>'{ubicacion,region}'),''),
     nullif(btrim(payload#>>'{ubicacion,lugar}'),''),v_latitude,v_longitude)
  on conflict (id) do update set
    nombre=excluded.nombre, imagen_url=excluded.imagen_url, historia=excluded.historia,
    descripcion_fisica=excluded.descripcion_fisica, danger_level_id=excluded.danger_level_id,
    periodo=excluded.periodo, location_kind=excluded.location_kind,
    location_country=excluded.location_country, location_region=excluded.location_region,
    location_place=excluded.location_place, latitude=excluded.latitude, longitude=excluded.longitude,
    updated_at=now(), last_edited_by=excluded.last_edited_by;

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
