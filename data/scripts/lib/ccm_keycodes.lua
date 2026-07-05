-- CCM Key Codes
--
-- Single source of truth for everything keybind-related: scancode constants,
-- modifier bit values, display labels, capture support, and the combo()
-- builder. Used both by manifest authors (k.F9, k.combo, k.LCTRL) and
-- internally by ccm.lua / cosmicconfigmenu.lua (unpack, nameForCombo, etc.).
--
-- Usage in a manifest:
--   package.path = package.path .. ";data/scripts/lib/?.lua"
--   local k = include("ccm_keycodes")
--
--   { key = "ping",  type = "keybind", default = k.F9                      }
--   { key = "boost", type = "keybind", default = k.combo(k.Space, k.SHIFT) }
--   { key = "open",  type = "keybind", default = k.combo(k.KeyH, k.LCTRL)  }
--   { key = "off",   type = "keybind"                                      } -- omit for unbound
--
-- Packed integer layout:
--   bits  0-15  scancode (SDL2)
--   bit   16    LCtrl   bit 17  RCtrl
--   bit   18    LShift  bit 19  RShift
--   bit   20    LAlt    bit 21  RAlt
--   value -1    unbound (sentinel; internal — manifests use nil/omit)

local M = {}

-- ============================================================================
-- Modifier bits — pass these (not strings) to combo()
-- ============================================================================

M.LCTRL  = 65536    -- 2^16
M.RCTRL  = 131072   -- 2^17
M.LSHIFT = 262144   -- 2^18
M.RSHIFT = 524288   -- 2^19
M.LALT   = 1048576  -- 2^20
M.RALT   = 2097152  -- 2^21

-- Left-side aliases (Avorion's keybinding UI convention)
M.CTRL  = M.LCTRL
M.SHIFT = M.LSHIFT
M.ALT   = M.LALT

-- ============================================================================
-- Modifier scancodes (the keys themselves, distinct from the bit values above)
-- ============================================================================

M.SC_LCTRL  = 224
M.SC_RCTRL  = 228
M.SC_LSHIFT = 225
M.SC_RSHIFT = 229
M.SC_LALT   = 226
M.SC_RALT   = 230

local MODIFIER_SCANCODES = {
    [M.SC_LCTRL]=true,  [M.SC_RCTRL]=true,
    [M.SC_LSHIFT]=true, [M.SC_RSHIFT]=true,
    [M.SC_LALT]=true,   [M.SC_RALT]=true,
}

-- ============================================================================
-- Internal sentinel — manifests just omit the default or pass nil
-- ============================================================================

M.UNBOUND = -1

-- ============================================================================
-- Scancode table (name → scancode), mirrored at the top of M for k.F9 access
-- ============================================================================

M.KEY = {
    -- Letters
    KeyA=4,  KeyB=5,  KeyC=6,  KeyD=7,  KeyE=8,  KeyF=9,  KeyG=10, KeyH=11, KeyI=12,
    KeyJ=13, KeyK=14, KeyL=15, KeyM=16, KeyN=17, KeyO=18, KeyP=19, KeyQ=20, KeyR=21,
    KeyS=22, KeyT=23, KeyU=24, KeyV=25, KeyW=26, KeyX=27, KeyY=28, KeyZ=29,

    -- Top-row digits
    Key1=30, Key2=31, Key3=32, Key4=33, Key5=34,
    Key6=35, Key7=36, Key8=37, Key9=38, Key0=39,

    -- Control / whitespace
    Enter=40, Escape=41, Backspace=42, Tab=43, Space=44,

    -- Punctuation
    Minus=45,     Equals=46,    LeftBracket=47, RightBracket=48,
    Backslash=49, Semicolon=51, Apostrophe=52,  Backtick=53,
    Comma=54,     Period=55,    Slash=56,

    CapsLock=57,

    -- Function keys
    F1=58, F2=59, F3=60, F4=61, F5=62,  F6=63,
    F7=64, F8=65, F9=66, F10=67, F11=68, F12=69,

    PrintScreen=70, ScrollLock=71, Pause=72,

    -- Navigation
    Insert=73, Home=74, PageUp=75,
    Delete=76, End=77,  PageDown=78,

    -- Arrows
    Right=79, Left=80, Down=81, Up=82,

    -- Numpad
    NumLock=83,
    NumpadDivide=84, NumpadMultiply=85, NumpadMinus=86,
    NumpadPlus=87,   NumpadEnter=88,
    Numpad1=89, Numpad2=90, Numpad3=91, Numpad4=92, Numpad5=93,
    Numpad6=94, Numpad7=95, Numpad8=96, Numpad9=97, Numpad0=98,
    NumpadDot=99,

    Menu=101,
}

for name, sc in pairs(M.KEY) do M[name] = sc end

-- ============================================================================
-- Display labels (scancode → UI-friendly name)
-- ============================================================================

local LABELS = {
    [4]="A",  [5]="B",  [6]="C",  [7]="D",  [8]="E",  [9]="F",  [10]="G",
    [11]="H", [12]="I", [13]="J", [14]="K", [15]="L", [16]="M", [17]="N",
    [18]="O", [19]="P", [20]="Q", [21]="R", [22]="S", [23]="T", [24]="U",
    [25]="V", [26]="W", [27]="X", [28]="Y", [29]="Z",

    [30]="1", [31]="2", [32]="3", [33]="4", [34]="5",
    [35]="6", [36]="7", [37]="8", [38]="9", [39]="0",

    [40]="Enter",     [41]="Esc",       [42]="Backspace", [43]="Tab",
    [44]="Space",     [45]="-",         [46]="=",         [47]="[",
    [48]="]",         [49]="\\",
    [51]=";",         [52]="'",         [53]="`",
    [54]=",",         [55]=".",         [56]="/",
    [57]="Caps Lock",

    [58]="F1",  [59]="F2",  [60]="F3",  [61]="F4",
    [62]="F5",  [63]="F6",  [64]="F7",  [65]="F8",
    [66]="F9",  [67]="F10", [68]="F11", [69]="F12",

    [70]="Print Screen", [71]="Scroll Lock", [72]="Pause",
    [73]="Insert",       [74]="Home",        [75]="Page Up",
    [76]="Delete",       [77]="End",         [78]="Page Down",
    [79]="Right Arrow",  [80]="Left Arrow",  [81]="Down Arrow", [82]="Up Arrow",

    [83]="Num Lock",
    [84]="Numpad /",     [85]="Numpad *",    [86]="Numpad -", [87]="Numpad +",
    [88]="Numpad Enter",
    [89]="Numpad 1",     [90]="Numpad 2",    [91]="Numpad 3",
    [92]="Numpad 4",     [93]="Numpad 5",    [94]="Numpad 6",
    [95]="Numpad 7",     [96]="Numpad 8",    [97]="Numpad 9",
    [98]="Numpad 0",     [99]="Numpad .",

    [101]="Menu",
}

-- ============================================================================
-- combo() — manifest builder
-- ============================================================================

--- Pack a scancode + zero or more modifier constants into CCM's keybind integer.
--- Returns nil on bad input — nil/omit means "unbound" throughout the manifest API.
--- @param scancode number  Scancode constant from M.KEY (e.g. k.F9, k.KeyH)
--- @param ... number  Modifier constants (k.LCTRL, k.RSHIFT, k.LALT, ...).
---                    k.CTRL / k.SHIFT / k.ALT alias the left-side modifier.
--- @return number|nil  Packed keybind value, or nil if scancode is invalid
function M.combo(scancode, ...)
    if type(scancode) ~= "number" or scancode < 0 then return nil end
    local v = scancode
    for i = 1, select("#", ...) do
        local m = select(i, ...)
        if type(m) == "number" then v = v + m end
    end
    return v
end

-- ============================================================================
-- Unpack
-- ============================================================================

--- Decompose a packed value into { scancode, lctrl, rctrl, lshift, rshift, lalt, ralt, unbound }.
function M.unpack(packed)
    if type(packed) ~= "number" or packed < 0 then
        return {
            scancode = -1,
            lctrl = false, rctrl = false,
            lshift = false, rshift = false,
            lalt = false, ralt = false,
            unbound = true,
        }
    end
    return {
        scancode = packed % M.LCTRL,
        lctrl    = math.floor(packed / M.LCTRL)  % 2 == 1,
        rctrl    = math.floor(packed / M.RCTRL)  % 2 == 1,
        lshift   = math.floor(packed / M.LSHIFT) % 2 == 1,
        rshift   = math.floor(packed / M.RSHIFT) % 2 == 1,
        lalt     = math.floor(packed / M.LALT)   % 2 == 1,
        ralt     = math.floor(packed / M.RALT)   % 2 == 1,
        unbound  = false,
    }
end

-- ============================================================================
-- Display
-- ============================================================================

--- Get the UI label for a single scancode.
function M.nameForKey(scancode)
    if type(scancode) ~= "number" or scancode < 0 then return "Unbound" end
    return LABELS[scancode] or ("Key #" .. tostring(scancode))
end

--- Get the UI label for a packed combo (e.g. "L. Ctrl+R. Shift+H").
function M.nameForCombo(packed)
    if type(packed) ~= "number" or packed < 0 then return "Unbound" end
    local c = M.unpack(packed)
    local parts = {}
    if c.lctrl  then parts[#parts + 1] = "L. Ctrl"  end
    if c.rctrl  then parts[#parts + 1] = "R. Ctrl"  end
    if c.lshift then parts[#parts + 1] = "L. Shift" end
    if c.rshift then parts[#parts + 1] = "R. Shift" end
    if c.lalt   then parts[#parts + 1] = "L. Alt"   end
    if c.ralt   then parts[#parts + 1] = "R. Alt"   end
    parts[#parts + 1] = M.nameForKey(c.scancode)
    return table.concat(parts, "+")
end

-- ============================================================================
-- Capture support
-- ============================================================================

local CAPTURE_LIST

--- Ordered list of scancodes the capture poll should test against.
--- Excludes the modifier keys themselves (those are read via Keyboard:keyPressed).
function M.captureCandidates()
    if CAPTURE_LIST then return CAPTURE_LIST end
    CAPTURE_LIST = {}
    for sc in pairs(LABELS) do
        if not MODIFIER_SCANCODES[sc] then
            CAPTURE_LIST[#CAPTURE_LIST + 1] = sc
        end
    end
    table.sort(CAPTURE_LIST)
    return CAPTURE_LIST
end

--- True if this scancode is one of the bare modifier keys (Shift/Ctrl/Alt).
function M.isModifierKey(scancode)
    return MODIFIER_SCANCODES[scancode] == true
end

return M
