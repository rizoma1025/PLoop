--=============================
-- System.IO.Path
--
-- Author : Kurapica
-- Create Date : 2016/01/28
--=============================
_ENV = Module "System.IO.Path" "1.0.0"

namespace "System.IO"

__Final__() __Sealed__() __Abstract__()
class "Path" (function (_ENV)

	__Doc__[[Get the current operation path]]
	__PipeRead__ ("echo %%cd%%", "[^\n]+", OSType.Windows)
	__PipeRead__ ("pwd", "[^\n]+", OSType.MacOS+OSType.Linux)
	function GetCurrentPath(result) return result end

	__Doc__[[Whether the path contains the root path]]
	function IsPathRooted(path) return (path:find("^[\\/]") or path:find("^%a:[\\/]")) and true or false end

	__Doc__[[Get the root of the path]]
	function GetPathRoot(path) return (path:match("^[\\/]") or path:match("^%a:[\\/]")) end

	__Doc__[[Get the directory of the path, if the path is a root, empty string would be returned.]]
	function GetDirectory(path) return (path:sub(1, -2):gsub("[^\\/]*$", "")) end

	__Doc__[[Combine the paths]]
	function CombinePath(...)
		local path
		local dirSep
		for i = 1, select('#', ...) do
			local part = select(i, ...)
			if not path then
				local root = GetPathRoot(part)
				if root then
					path = part
					if #root == 1 then dirSep = root else dirSep = root:sub(-1) end
				end
			else
				local prevSep, nxtSep = path:find("[\\/]$"), part:find("^[[\\/]")
				if prevSep and nxtSep then
					path = path .. part:sub(2)
				elseif prevSep or nxtSep then
					path = path .. part
				else
					path = path .. dirSep .. part
				end
			end
		end
		return path
	end

	__Doc__[[Get the suffix of the path, include the '.']]
	function GetSuffix(path) return path:match("%.[^%.]*$") end

	__Doc__[[Get the file name]]
	function GetFileName(path) return path:match("[^\\/]*$") end

	__Doc__[[Get the file name without the suffix]]
	function GetFileNameWithoutSuffix(path) return (GetFileName(path):gsub("%.[^%.]*$", "")) end
end)