# Making 3D models for Forge of the Eight Stones

A practical guide: what to build, what file format Godot wants, and which tool
to use.

---

## 1. What you can design

Everything in the game is built from simple shapes right now — which means
**any model you make will fit** as long as it is low-poly.

The characters have a strict **cubes and triangles** style: the player, the six
monsters and the six bosses use nothing else (`scripts/shapes.gd`). Keep your
models in that spirit — flat faces, sharp corners, no smooth spheres.

| Where | Objects that would fit |
| --- | --- |
| **Player** | a humanoid character (with idle / walk / jump animations), a cape, a hat |
| **Weapons** | pickaxe, sword, dagger, katana, spear, bow, shuriken (one per element) |
| **Ore** | stone rock, copper rock, iron rock, magic crystal cluster |
| **Trees** | forest tree, snowy pine, dead tree, giant mushroom |
| **Temples** | pillars, obelisks, crystal spires, fountain, mushroom caps |
| **Bosses** | rock golem, ember golem, vine beast, frost golem, tide serpent, spore beast |
| **Cave** | stalagmites, glowing crystals, chest, ladder, old bones |
| **Village** | huts, market stall, barrels, crates, banners, cart |
| **Forge** | anvil, bellows, weapon rack, glowing braziers |
| **Little things** | coins, signposts, fences, bridges, flower pots |

Start with something small and static (a rock, a barrel, a sword). Characters
with animation are the hardest, so save them for later.

---

## 2. The format: use `.glb`

Godot 4 reads these:

| Format | Good for | Notes |
| --- | --- | --- |
| **`.glb`** | everything | **Use this.** One file, model + materials + animations inside |
| `.gltf` + files | same as glb | many files, easier to lose one |
| `.blend` | Blender users | Godot opens it directly **if Blender is installed** |
| `.obj` | simple props | no rig, no animation, no materials setup |
| `.fbx` | Mixamo characters | needs the FBX2glTF add-on (Godot offers to download it) |
| `.dae` | old tools | works, but old |

**Recommendation: export `.glb`.** Everything (mesh, colours, animations) is in
one file, so nothing gets lost.

---

## 3. The tools

| Tool | Free? | Best for | Exports |
| --- | --- | --- | --- |
| **Blender** | yes | everything: characters, weapons, props | `.glb` |
| **Blockbench** | yes | Minecraft-style models, very kid-friendly | `.glb`, `.obj` |
| **MagicaVoxel** | yes | blocky voxel props (rocks, trees, houses) | `.obj`, `.glb` |
| **Kenney.nl** | yes | ready-made packs (no modelling needed) | `.glb`, `.obj` |
| **Quaternius** | yes | low-poly packs in the same style as this game | `.glb` |

If you have never modelled before: **Blockbench** is the easiest. If you want to
learn real 3D: **Blender** (it is the standard, and there are thousands of
tutorials).

---

## 4. Rules for this game

1. **Scale: 1 unit = 1 metre.** Your character should be about 1.7 m tall, a
   rock 1 m, a tree 4 m.
2. **Put the origin at the bottom** of the model (between the feet), so it sits
   on the ground when placed at height 0.
3. **Facing: -Z is forward.** In Blender that is "front view" (numpad 1). The
   game turns models with `-Z` as their face.
4. **Low poly:** 200–2000 triangles per prop is plenty. This game's style is
   simple, flat-coloured shapes.
5. **Colours, not textures:** use plain materials with a base colour. If you do
   use a texture, 512×512 is enough.
6. **Apply transforms** in Blender before exporting (`Ctrl+A` → All Transforms),
   and export with **+Y Up** (the default).
7. **Collision is separate.** The game adds a simple box or capsule collider —
   never use a detailed mesh as a collider.

---

## 5. How to put a model in the game

1. Save the file in `assets/models/`, for example
   `assets/models/props/barrel.glb`.
2. Open Godot — it imports it automatically and you see it in the FileSystem panel.
3. Two ways to use it:

   **In the editor:** drag the `.glb` into a scene. It becomes a `Node3D` with
   the mesh inside. Add a `StaticBody3D` + `CollisionShape3D` next to it if it
   should be solid.

   **In code** (how this game does it):
   ```gdscript
   const BARREL = preload("res://assets/models/props/barrel.glb")

   var barrel = BARREL.instantiate()
   barrel.position = Vector3(5, 0, 3)
   add_child(barrel)
   ```

4. To replace the **player**, put your model under the `Visuals` node in
   `scenes/player.tscn` and hide the old capsule/head meshes.
5. To replace the **weapon**, swap the `Weapon` mesh in `scenes/player.tscn`.

---

## 6. Animations (characters)

The game's own character is animated **in code** with pivots (see `_animate()`
in `scripts/player.gd`): the legs and arms are children of pivot nodes, so
rotating a pivot swings the whole limb from the hip or shoulder.

If you bring your own model with animations:

- Make the animations in Blender / Blockbench, then export the `.glb` **with
  animations included**.
- Godot imports them into an `AnimationPlayer` inside the imported scene.
- Name them clearly: `idle`, `walk`, `run`, `jump`, `attack`.
- In code, play them with:
  ```gdscript
  $Visuals/YourModel/AnimationPlayer.play("walk")
  ```

---

## 7. Where to start

Make one **rock**:
1. Blockbench → New Project → 1 cube, squash it a bit, colour it grey.
2. Export as `.glb` → `assets/models/props/rock.glb`.
3. In the editor, drag it onto the scene and look at it next to the existing rocks.
4. Once it looks right, we can swap it into the ore node so every rock in the
   game uses your model.

Then move on to: barrel → tree → weapon → character.
