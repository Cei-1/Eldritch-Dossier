# 🌌 Eldritch Dossier — Compendio Enciclopédico

> “Lo más misericordioso del mundo es la incapacidad de la mente humana para
> relacionar todos sus contenidos.” — Inspirado en el horror cósmico de
> H. P. Lovecraft.

Aplicación web progresiva para consultar y administrar expedientes de criaturas
mitológicas con una interfaz inspirada en terminales CRT.

![Emblema de Eldritch Dossier](assets/img/Eldritch-Dossier-logo.jpg)

## Funciones

- Consulta pública de expedientes activos.
- Búsqueda, filtros, clasificación y navegación paginada.
- Registro e inicio de sesión mediante Supabase Auth.
- Roles: Archivista (administración), Erudito (creación y edición) e Iniciado
  (lectura).
- Catálogos relacionales de culturas, mitologías, etiquetas, habilidades y
  niveles de peligro.
- PWA instalable con acceso offline de solo lectura a recursos previamente
  visitados.
- Interfaz adaptable a móvil y preferencias de movimiento reducido.

## Arquitectura

- Frontend: React 18, JSX, Tailwind CSS y estilos propios.
- Backend: Supabase Auth, Postgres y Row Level Security.
- PWA: Web App Manifest y Service Worker.

La clave incluida en `supabaseClient.js` es una clave pública/publishable. La
protección de los datos depende de las políticas RLS; nunca se debe colocar una
clave `service_role` en el frontend.

## Preparación de Supabase

1. Crea las tablas y catálogos base.
2. Ejecuta `database/migrations/001_secure_schema.sql` en Supabase SQL Editor.
3. Ejecuta `database/migrations/002_creature_locations.sql` para habilitar el atlas con ubicaciones precisas.
4. Comprueba que los usuarios nuevos reciben el rol `Iniciado`.
5. Asigna manualmente el rol `Archivista` o `Erudito` únicamente a usuarios de
   confianza.

La migración corrige las políticas solapadas, habilita lectura de relaciones y
añade `save_creature`, una función transaccional que evita expedientes
parcialmente guardados. Mientras no se aplique, el frontend conserva un flujo
heredado de compatibilidad, pero no ofrece las mismas garantías.

## Desarrollo local

El Service Worker requiere HTTP; abrir directamente `index.html` mediante
`file://` no permite probar correctamente la PWA.

```powershell
python -m http.server 4173 --bind 127.0.0.1
```

Después abre `http://127.0.0.1:4173`.

## Permisos

| Operación | Público/Iniciado | Erudito | Archivista |
| --- | ---: | ---: | ---: |
| Ver expedientes activos | Sí | Sí | Sí |
| Crear y editar | No | Sí | Sí |
| Eliminar | No | No | Sí |

El modo offline es deliberadamente de solo lectura. Las escrituras requieren
conexión para que Supabase valide la sesión y las políticas RLS.

---

Desarrollado por **Brian Aguirre** — explorando los límites de la web y el
horror cósmico.
