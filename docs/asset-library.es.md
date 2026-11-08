# Cómo publicar Truss en la Asset Library de Godot

Guía paso a paso para dar de alta Truss (y publicar versiones nuevas) en la Asset Library. La referencia oficial
es [Submitting to the Asset Library](https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html).
Los campos en inglés y lo que se verificó antes de cada versión están en [asset-library.md](asset-library.md).

La Asset Library no aloja los archivos: guarda un enlace al repositorio de GitHub y a un commit concreto. Al
instalar, el editor descarga el ZIP de ese commit, que gracias a `.gitattributes` solo contiene `addons/truss`.

## Requisitos (Truss ya los cumple)

| Requisito | Estado en Truss |
|---|---|
| Funciona en la versión de Godot declarada | CI en 4.5.1 y 4.7.2 |
| `.gitignore` correcto | Sí |
| Sin submódulos | Sí |
| `LICENSE` en el repo con año y titular, igual a la licencia declarada | `Copyright (c) 2026 jsperez852`, MIT |
| Nombre y descripción en inglés correcto | Ver la descripción propuesta abajo |
| Icono con enlace directo (`raw.githubusercontent.com`), cuadrado, mínimo 128×128 | `icon.png`, 256×256 |

## 1. Crear la cuenta

1. Entra en https://godotengine.org/asset-library/asset.
2. Pulsa **Register** (arriba a la derecha) y crea una cuenta. Es una cuenta propia de la Asset Library, distinta de GitHub.
3. Inicia sesión con **Login**.

## 2. Abrir el formulario

Con la sesión iniciada, entra en **Submit Assets** (https://godotengine.org/asset-library/asset/submit).

## 3. Rellenar los campos

| Campo | Valor |
|---|---|
| **Asset Name** | `Truss` |
| **Category** | `Scripts` (grupo Addons: aparece en la pestaña AssetLib dentro de un proyecto) |
| **Godot version** | `4.5` |
| **Version** | la versión publicada, por ejemplo `0.6.1` |
| **Repository host** | `GitHub` |
| **Repository URL** | `https://github.com/jsperez852/truss` |
| **Issues URL** | `https://github.com/jsperez852/truss/issues` (opcional: es el mismo repositorio) |
| **Download Commit** | el hash completo del tag de esa versión: `git rev-list -n 1 v0.6.1` |
| **Icon URL** | `https://raw.githubusercontent.com/jsperez852/truss/v0.6.1/icon.png` (con la versión del tag) |
| **License** | `MIT` |
| **Description** | texto plano en inglés, sin Markdown (propuesta abajo) |

**Previews** (opcional, hasta tres). En cada una: marca **Enable**, **Type: Image**, y pon la misma URL en
**Image URL** y **Thumbnail URL**:

- `https://raw.githubusercontent.com/jsperez852/truss/v0.6.1/docs/images/debugger-tab.png`
- `https://raw.githubusercontent.com/jsperez852/truss/v0.6.1/docs/images/arena.png`

### Descripción propuesta

```
Truss brings structure to GDScript projects without fighting the editor. Every piece is optional:

- Typed events (TrEventBus) with priority and per-sender filtering
- Game phases in code (TrPhases) and node-based state machines (TrStateMachine)
- Content databases that work in exported builds (TrRegistry)
- Stats with modifiers (TrStats), wallets and per-level prices (TrWallet, TrCurve)
- Safe save files with versions and backups (TrSave)
- Pause tokens and hit stop, app lifecycle events
- For bigger games: dependency injection, feature modules, commands and queries, a layer linter
- A "Truss" tab in the editor's Debugger panel

Small game? Start with Truss Lite (levels 0 to 2). Getting started guide: https://github.com/jsperez852/truss/blob/main/docs/guide/getting-started.md

Pure GDScript, Godot 4.5+, tested on 4.5.1 and 4.7.2. MIT license.
```

## 4. Enviar y esperar la revisión

1. Pulsa **Submit**. El asset entra en la cola de revisión (visible en la web de la Asset Library).
2. La revisión es manual y puede tardar unos días. Te avisan cuando se acepta o, si se rechaza, del motivo;
   puedes corregir y volver a enviarlo.

## 5. Publicar una versión nueva

1. Publica la versión en GitHub (tag `vX.Y.Z`, CI en verde).
2. En la página del asset en la Asset Library, pulsa **Edit**.
3. Cambia **Version**, **Download Commit** (`git rev-list -n 1 vX.Y.Z`) y la versión en las URLs del icono y las previews.
4. Envía: la edición vuelve a pasar por revisión. Hasta que se apruebe, los usuarios siguen viendo la versión anterior.

## Comprobaciones antes de enviar

- CI en verde en el commit del tag.
- `git archive --format=tar vX.Y.Z | tar -t` lista solo rutas bajo `addons/` (la CI lo comprueba).
- En un proyecto vacío: instalar desde la pestaña AssetLib, activar **Truss** en Project Settings → Plugins,
  comprobar que aparece el autoload `Truss` en Project Settings → Globals, y ejecutar una escena con
  `TrPhases.new(&"test")` para ver la fase en la pestaña **Truss** del panel Debugger.
