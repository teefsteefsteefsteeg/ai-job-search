using System;
using System.Collections.Generic;
using UnityEngine;

namespace NongTrai
{
    /// Loads the Kenney FBX models from Resources/Models, normalises their size and tints materials.
    public static class Models
    {
        static readonly Dictionary<string, GameObject> prefabs = new Dictionary<string, GameObject>();
        static readonly Dictionary<string, Material> tints = new Dictionary<string, Material>();
        static readonly Dictionary<string, float> unitHeights = new Dictionary<string, float>();
        static Material baseMat;

        public static GameObject Prefab(string path)
        {
            if (prefabs.TryGetValue(path, out var p)) return p;
            p = Resources.Load<GameObject>("Models/" + path);
            if (p == null) Debug.LogWarning("[NongTrai] Missing model: " + path);
            prefabs[path] = p; return p;
        }

        public static Bounds MeasureLocal(GameObject go)
        {
            var rs = go.GetComponentsInChildren<Renderer>();
            if (rs.Length == 0) return new Bounds(go.transform.position, Vector3.one);
            var b = rs[0].bounds; foreach (var r in rs) b.Encapsulate(r.bounds); return b;
        }

        /// Height (in import units) of a reference model; used so kit models keep their relative sizes.
        static float UnitHeight(string refPath, float expected)
        {
            if (unitHeights.TryGetValue(refPath, out var u)) return u;
            u = 1f; var p = Prefab(refPath);
            if (p != null) { var g = UnityEngine.Object.Instantiate(p); g.transform.position = new Vector3(0, -500, 0); var h = MeasureLocal(g).size.y; UnityEngine.Object.DestroyImmediate(g); if (h > 0.0001f) u = h / expected; }
            unitHeights[refPath] = u; return u;
        }

        /// Spawns a model wrapped in an empty root. mode "h": scale so height == size; "kit": scale relative to the kit's units.
        public static GameObject Spawn(string path, float size, bool byHeight, Transform parent = null)
        {
            var root = new GameObject(path);
            if (parent) root.transform.SetParent(parent, false);
            var p = Prefab(path);
            if (p == null) { var c = Primitive(PrimitiveType.Cube, new Color(.8f, .3f, .8f)); c.transform.SetParent(root.transform, false); c.transform.localScale = Vector3.one * .5f * size; c.transform.localPosition = Vector3.up * .25f * size; return root; }
            var g = UnityEngine.Object.Instantiate(p, root.transform, false);
            g.name = "model";
            float s;
            if (byHeight) { var h = MeasureLocal(g).size.y; s = h > 0.0001f ? size / h : 1f; }
            else
            {
                var kit = path.Substring(0, path.IndexOf('/'));
                float unit = kit == "nature" ? UnitHeight("nature/tree_default", 1.708f) : kit == "survival" ? UnitHeight("survival/chest", .257f) : 1f;
                s = size / unit;
            }
            g.transform.localScale *= s;
            foreach (var r in g.GetComponentsInChildren<Renderer>()) { r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On; r.receiveShadows = true; }
            foreach (var col in g.GetComponentsInChildren<Collider>()) UnityEngine.Object.Destroy(col);
            return root;
        }

        /// Replace materials whose name passes the test with a tinted (cached, shared) copy.
        public static void Tint(GameObject go, Func<string, bool> test, Color c, float amt)
        {
            if (amt <= 0f) return;
            foreach (var r in go.GetComponentsInChildren<Renderer>())
            {
                var mats = r.sharedMaterials;
                for (int k = 0; k < mats.Length; k++)
                {
                    var m = mats[k]; if (m == null || !test(m.name)) continue;
                    var key = m.GetInstanceID() + "_" + ColorUtility.ToHtmlStringRGB(c) + "_" + amt;
                    if (!tints.TryGetValue(key, out var t)) { t = new Material(m) { name = m.name }; t.color = Color.Lerp(m.color, c, amt); tints[key] = t; }
                    mats[k] = t;
                }
                r.sharedMaterials = mats;
            }
        }
        public static bool Leafy(string n) { n = n.ToLowerInvariant(); return n.Contains("leaf") || n.Contains("grass") || n.Contains("flower") || n.Contains("plant"); }

        /// Unique material instances so a single creature can flash or be recoloured.
        public static List<Material> OwnMaterials(GameObject go)
        {
            var list = new List<Material>();
            foreach (var r in go.GetComponentsInChildren<Renderer>()) { var ms = r.materials; list.AddRange(ms); }
            return list;
        }
        public static void SetEmission(List<Material> mats, Color c)
        {
            foreach (var m in mats)
            {
                if (m == null || !m.HasProperty("_EmissionColor")) continue;
                if (c.maxColorComponent > 0.001f) m.EnableKeyword("_EMISSION"); else m.DisableKeyword("_EMISSION");
                m.SetColor("_EmissionColor", c);
            }
        }

        /// A lit material compatible with whatever pipeline the imported models use (URP Lit in a URP project).
        public static Material BaseMaterial
        {
            get
            {
                if (baseMat != null) return baseMat;
                var p = Prefab("survival/chest");
                if (p != null) { var r = p.GetComponentInChildren<Renderer>(); if (r != null && r.sharedMaterial != null) baseMat = new Material(r.sharedMaterial); }
                if (baseMat == null)
                {
                    var sh = Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard");
                    baseMat = new Material(sh);
                }
                baseMat.mainTexture = null; baseMat.color = Color.white; baseMat.name = "NT_Base";
                return baseMat;
            }
        }
        static readonly Dictionary<Color, Material> solid = new Dictionary<Color, Material>();
        public static Material Solid(Color c, float smooth = .15f)
        {
            if (solid.TryGetValue(c, out var m)) return m;
            m = new Material(BaseMaterial) { color = c, name = "NT_" + ColorUtility.ToHtmlStringRGB(c) };
            if (m.HasProperty("_Smoothness")) m.SetFloat("_Smoothness", smooth);
            if (m.HasProperty("_Glossiness")) m.SetFloat("_Glossiness", smooth);
            solid[c] = m; return m;
        }
        public static GameObject Primitive(PrimitiveType t, Color c)
        {
            var g = GameObject.CreatePrimitive(t);
            var col = g.GetComponent<Collider>(); if (col) UnityEngine.Object.Destroy(col);
            g.GetComponent<Renderer>().sharedMaterial = Solid(c);
            return g;
        }
        public static GameObject Box(Transform parent, Color c, Vector3 pos, Vector3 scale, Vector3 euler = default)
        {
            var g = Primitive(PrimitiveType.Cube, c); g.transform.SetParent(parent, false);
            g.transform.localPosition = pos; g.transform.localScale = scale; g.transform.localEulerAngles = euler; return g;
        }

        /// Four-sided pyramid mesh for roofs.
        public static Mesh Pyramid()
        {
            var m = new Mesh { name = "pyramid" };
            Vector3 a = new Vector3(-.5f, 0, -.5f), b = new Vector3(.5f, 0, -.5f), c = new Vector3(.5f, 0, .5f), d = new Vector3(-.5f, 0, .5f), top = new Vector3(0, 1, 0);
            var v = new List<Vector3>(); var tri = new List<int>();
            void Face(Vector3 p0, Vector3 p1, Vector3 p2) { int n = v.Count; v.Add(p0); v.Add(p1); v.Add(p2); tri.Add(n); tri.Add(n + 1); tri.Add(n + 2); }
            Face(a, top, b); Face(b, top, c); Face(c, top, d); Face(d, top, a); Face(a, b, c); Face(a, c, d);
            m.SetVertices(v); m.SetTriangles(tri, 0); m.RecalculateNormals(); m.RecalculateBounds(); return m;
        }

        static Texture2D softDot;
        public static Texture2D SoftDot
        {
            get
            {
                if (softDot != null) return softDot;
                softDot = new Texture2D(32, 32, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
                for (int y = 0; y < 32; y++) for (int x = 0; x < 32; x++)
                {
                    float d = Vector2.Distance(new Vector2(x, y), new Vector2(15.5f, 15.5f)) / 15.5f;
                    softDot.SetPixel(x, y, new Color(1, 1, 1, Mathf.Clamp01(1 - d) * Mathf.Clamp01(1 - d)));
                }
                softDot.Apply(); return softDot;
            }
        }
        public static Material ParticleMaterial(Color tint)
        {
            var sh = Shader.Find("Universal Render Pipeline/Particles/Unlit") ?? Shader.Find("Particles/Standard Unlit") ?? Shader.Find("Sprites/Default");
            var m = new Material(sh) { name = "NT_Particles" };
            m.mainTexture = SoftDot;
            if (m.HasProperty("_BaseColor")) m.SetColor("_BaseColor", tint); else m.color = tint;
            // additive blending where the URP particle shader supports it
            if (m.HasProperty("_Surface")) { m.SetFloat("_Surface", 1); m.SetFloat("_Blend", 2); m.SetOverrideTag("RenderType", "Transparent"); m.renderQueue = 3000;
                m.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha); m.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.One); m.SetInt("_ZWrite", 0); m.EnableKeyword("_SURFACE_TYPE_TRANSPARENT"); }
            return m;
        }
    }

    /// Plays the legacy animation clips that ship inside the Kenney FBX files (idle, walk, run, sit…).
    public class AnimCtl
    {
        readonly Animation anim; string cur; float lockT;
        public bool Valid => anim != null;
        public float Lock => lockT;
        public AnimCtl(GameObject root)
        {
            anim = root.GetComponentInChildren<Animation>();
            if (anim != null) { anim.cullingType = AnimationCullingType.AlwaysAnimate; anim.playAutomatically = false; }
        }
        string Find(string n)
        {
            if (anim == null) return null;
            foreach (AnimationState s in anim) if (string.Equals(s.name, n, StringComparison.OrdinalIgnoreCase)) return s.name;
            foreach (AnimationState s in anim)
            {
                var low = s.name.ToLowerInvariant();
                if (low.EndsWith("|" + n) || low.EndsWith("/" + n) || low.EndsWith("_" + n)) return s.name;
            }
            return null;
        }
        public bool Has(string n) => Find(n) != null;
        public void Loop(string n, float speed = 1f)
        {
            if (anim == null || lockT > 0f) return;
            var c = Find(n); if (c == null) return;
            var st = anim[c]; st.speed = speed;
            if (c == cur) return;
            st.wrapMode = WrapMode.Loop; anim.CrossFade(c, .15f); cur = c;
        }
        public float Once(string n, float speed = 1f)
        {
            if (anim == null) return 0f;
            var c = Find(n); if (c == null) return 0f;
            var st = anim[c]; st.wrapMode = WrapMode.ClampForever; st.speed = speed; st.time = 0f;
            anim.CrossFade(c, .08f); cur = c; lockT = st.length / Mathf.Max(.01f, speed); return lockT;
        }
        public void Unlock() { lockT = 0f; cur = null; }
        public void Tick(float dt) { if (lockT > 0f) { lockT -= dt; if (lockT <= 0f) cur = null; } }
    }
}
