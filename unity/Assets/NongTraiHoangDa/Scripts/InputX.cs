using UnityEngine;
#if ENABLE_INPUT_SYSTEM && !ENABLE_LEGACY_INPUT_MANAGER
using UnityEngine.InputSystem;
#endif

namespace NongTrai
{
    /// Works with either the new Input System package or the legacy Input Manager,
    /// so the project runs whichever "Active Input Handling" the Unity project uses.
    public static class InputX
    {
#if ENABLE_INPUT_SYSTEM && !ENABLE_LEGACY_INPUT_MANAGER
        static Key Map(KeyCode k)
        {
            switch (k)
            {
                case KeyCode.W: return Key.W; case KeyCode.A: return Key.A; case KeyCode.S: return Key.S; case KeyCode.D: return Key.D;
                case KeyCode.E: return Key.E; case KeyCode.F: return Key.F; case KeyCode.R: return Key.R; case KeyCode.C: return Key.C;
                case KeyCode.H: return Key.H; case KeyCode.Z: return Key.Z; case KeyCode.X: return Key.X; case KeyCode.Q: return Key.Q;
                case KeyCode.UpArrow: return Key.UpArrow; case KeyCode.DownArrow: return Key.DownArrow;
                case KeyCode.LeftArrow: return Key.LeftArrow; case KeyCode.RightArrow: return Key.RightArrow;
                case KeyCode.Space: return Key.Space; case KeyCode.Return: return Key.Enter; case KeyCode.Escape: return Key.Escape;
                case KeyCode.Tab: return Key.Tab; case KeyCode.LeftShift: return Key.LeftShift;
                case KeyCode.Alpha1: return Key.Digit1; case KeyCode.Alpha2: return Key.Digit2; case KeyCode.Alpha3: return Key.Digit3;
                case KeyCode.Alpha4: return Key.Digit4; case KeyCode.Alpha5: return Key.Digit5; case KeyCode.Alpha6: return Key.Digit6;
                case KeyCode.Alpha7: return Key.Digit7; case KeyCode.Alpha8: return Key.Digit8; case KeyCode.Alpha9: return Key.Digit9;
            }
            return Key.None;
        }
        public static bool Held(KeyCode k) { var kb = Keyboard.current; var key = Map(k); return kb != null && key != Key.None && kb[key].isPressed; }
        public static bool Down(KeyCode k) { var kb = Keyboard.current; var key = Map(k); return kb != null && key != Key.None && kb[key].wasPressedThisFrame; }
        public static bool MouseDown(int b) { var m = Mouse.current; if (m == null) return false; return b == 0 ? m.leftButton.wasPressedThisFrame : m.rightButton.wasPressedThisFrame; }
        public static bool MouseHeld(int b) { var m = Mouse.current; if (m == null) return false; return b == 0 ? m.leftButton.isPressed : m.rightButton.isPressed; }
        public static Vector2 MouseDelta { get { var m = Mouse.current; return m == null ? Vector2.zero : m.delta.ReadValue() * 0.1f; } }
        public static float Scroll { get { var m = Mouse.current; return m == null ? 0f : m.scroll.ReadValue().y / 120f; } }
#else
        public static bool Held(KeyCode k) => Input.GetKey(k);
        public static bool Down(KeyCode k) => Input.GetKeyDown(k);
        public static bool MouseDown(int b) => Input.GetMouseButtonDown(b);
        public static bool MouseHeld(int b) => Input.GetMouseButton(b);
        public static Vector2 MouseDelta => new Vector2(Input.GetAxis("Mouse X"), Input.GetAxis("Mouse Y"));
        public static float Scroll => Input.mouseScrollDelta.y;
#endif
    }
}
