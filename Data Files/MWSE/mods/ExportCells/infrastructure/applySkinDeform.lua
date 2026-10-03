--- FFI equivalent of the unmerged `niTriShape:applySkinDeform()` (applySkinDeform branch).
---
--- Bakes a skinned shape's current pose into a fresh copy of its geometry data, swaps
--- that copy in, and detaches the skin instance. The original data is left untouched,
--- so other shapes sharing it are unaffected.
---
--- Usage:
---   local applySkinDeform = require("ExportCells.infrastructure.applySkinDeform")
---   applySkinDeform(shape) --> true if applied, false if the shape has no data or no skin

local ffi = require("ffi")

local addressOf = mwse.memory.addressOf

local NiSkinInstance_Deform = ffi.cast(
	"void(__thiscall*)(uintptr_t, uintptr_t, size_t, uintptr_t, size_t, uintptr_t, uintptr_t, size_t)",
	0x6FA000
)

local VECTOR3_SIZE = 12

local OBJECT_REFCOUNT = 0x4
local GEOMETRY_SKIN_INSTANCE = 0x9C
local GEOMETRY_DATA_VERTEX_COUNT = 0x8
local GEOMETRY_DATA_VERTEX = 0x1C
local GEOMETRY_DATA_NORMAL = 0x20

local function u32(address)
	return ffi.cast("uint32_t*", address)
end

local function releaseObject(address)
	local refCount = ffi.cast("int32_t*", address + OBJECT_REFCOUNT)
	refCount[0] = refCount[0] - 1
	if refCount[0] == 0 then
		local destructor = ffi.cast("void(__thiscall*)(uintptr_t, int)", u32(u32(address)[0])[0])
		destructor(address, 1)
	end
end

---@param shape niTriShape
---@return boolean applied
local function applySkinDeform(shape)
	local data = shape.data
	local skin = shape.skinInstance
	if not (data and skin) then
		return false
	end

	local copy = data:copy()

	local src = addressOf(data)
	local dst = addressOf(copy)

	local count = ffi.cast("uint16_t*", dst + GEOMETRY_DATA_VERTEX_COUNT)[0]

	NiSkinInstance_Deform(
		addressOf(skin),
		u32(src + GEOMETRY_DATA_VERTEX)[0], VECTOR3_SIZE,
		u32(src + GEOMETRY_DATA_NORMAL)[0], count,
		u32(dst + GEOMETRY_DATA_VERTEX)[0],
		u32(dst + GEOMETRY_DATA_NORMAL)[0], VECTOR3_SIZE
	)

	shape.data = copy

	local shapeAddress = addressOf(shape)
	local skinAddress = u32(shapeAddress + GEOMETRY_SKIN_INSTANCE)[0]
	u32(shapeAddress + GEOMETRY_SKIN_INSTANCE)[0] = 0
	releaseObject(skinAddress)

	return true
end

return applySkinDeform
